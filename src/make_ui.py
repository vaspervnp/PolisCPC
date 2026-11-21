"""Τα μενού του παιχνιδιού (M20, 2026-11-21): γραμματοσειρά και κείμενα για
τον Z80 (game/ui.asm).

    python3 src/make_ui.py

-> data/ui_a.asm, ui_b.asm, ui_c.asm   σε τρία κομμάτια (τρεις ελεύθερες
                 περιοχές της σελίδας του HUD): η γραμματοσειρά 5 x 7 του μενού (ένα byte ανά γραμμή, τα
                 bits 4..0 από αριστερά: η ίδια του src/make_menu.py), και τα
                 κείμενα: πλήθος, γλύφοι — τα ονόματα των κτιρίων (με τη σειρά
                 των τύπων του src/make_bank6.py), των μονάδων (ανά σετ), των
                 τεχνολογιών (με τη σειρά του techs, game/bank7.asm), και οι
                 λέξεις των μενού.

Στο μενού κάθε γραμμή της γραμματοσειράς είναι ΜΙΑ γραμμή οθόνης (στο
μενού έναρξης και στο tutorial, δύο): μία σειρά του μενού ανά 8 γραμμές.
"""
import os

import gfx
import make_bank6 as MB
import make_menu as MN

DATA = os.path.join(gfx.OUT, 'data')

UI_COLS = 24                    # γλύφοι σε μια σειρά του μενού

EXTRA = {
    '-': ['.....', '.....', '.....', '.###.', '.....', '.....', '.....'],
    '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
}
GLYPHS = dict(MN.GLYPHS, **EXTRA)
ORDER = [ch for ch in GLYPHS if ch in ' >-+' or ch.isalnum()]

# με τη σειρά των τύπων (make_bank6.TYPES)
BUILDINGS = {
    'town_center': 'TOWN CENTER', 'house': 'HOUSE', 'barracks': 'BARRACKS',
    'granary': 'GRANARY', 'storage_pit': 'STORAGE PIT', 'market': 'MARKET',
    'archery': 'ARCHERY RANGE', 'stable': 'STABLE', 'farm': 'FARM',
    'tower': 'TOWER', 'temple': 'TEMPLE', 'gov_center': 'GOVERNMENT CENTER',
    'academy': 'ACADEMY',
}
# ανά σετ (game/units.asm): 3 = ο χωρικός με φορτίο
UNITS = ['VILLAGER', 'SWORDSMAN', 'ARCHER', 'VILLAGER', 'HOPLITE', 'CAVALRY']
# με τη σειρά του techs (game/bank7.asm)
TECHS = ['BRONZE AGE', 'DOMESTICATION', 'WOODWORKING', 'GOLD MINING',
         'STONE MINING', 'TOOLWORKING', 'LEATHER ARMOUR', 'METALLURGY',
         'SCALE ARMOUR', 'ARCHERY', 'COMPOSITE BOW', 'MEDICINE', 'PHALANX',
         'IRON AGE', 'IRON SPEARS', 'BALLISTICS']
WORDS = [('ui_w_build', 'BUILD'), ('ui_w_close', 'CLOSE'),
         ('ui_w_train', 'TRAIN'), ('ui_w_split', 'SPLIT SQUAD'),
         ('ui_w_busy', 'RESEARCHING')]
COST = 'FWGS'                   # τροφή, ξύλο, χρυσό, πέτρα


def enc(s):
    assert len(s) <= UI_COLS, s
    return [ORDER.index(ch) for ch in s]


def db_str(label, s):
    g = enc(s)
    return '%s db %d%s  ; %s\n' % (label + ':' if label else '       ',
                                    len(g), ''.join(', %d' % k for k in g), s)


def write(name, text):
    path = os.path.join(DATA, name)
    with open(path, 'w') as f:
        f.write(text)
    return path


def main():
    # τρία κομμάτια, για τρεις ελεύθερες περιοχές της σελίδας του HUD
    # (game/main.asm): η γραμματοσειρά, τα κτίρια / οι μονάδες / οι λέξεις,
    # οι τεχνολογίες
    head = '; ΠΑΡΑΓΕΤΑΙ από src/make_ui.py (M20).\n\n'
    a = [head,
         'UG_SPACE    equ %d\n' % ORDER.index(' '),
         'UG_PTR      equ %d\n' % ORDER.index('>'),
         'UG_0        equ %d\n' % ORDER.index('0'),
         ''.join('UG_%s        equ %d\n' % (ch, ORDER.index(ch))
                 for ch in COST),
         '\nui_font:    ; %s\n' % ''.join(ORDER)]
    for ch in ORDER:
        rows = [int(r.replace('#', '1').replace('.', '0'), 2)
                for r in GLYPHS[ch]]
        a.append('        db %s\n' % ','.join('#%02X' % b for b in rows))
    for k in range(10):
        assert ORDER.index(str(k)) == ORDER.index('0') + k
    keys = [t[0] for t in MB.TYPES]
    b = [head, '; τα κτίρια, με τη σειρά των τύπων: δείκτες\n',
         'ui_bld:     dw %s\n' % ', '.join('ub_%d' % k
                                         for k in range(len(keys)))]
    for k, key in enumerate(keys):
        b.append(db_str('ub_%d' % k, BUILDINGS[key]))
    b.append('\n; οι μονάδες, ανά σετ\nui_unit:    dw %s\n'
             % ', '.join('uu_%d' % k for k in range(len(UNITS))))
    for k, s_ in enumerate(UNITS):
        b.append(db_str('uu_%d' % k, s_))
    b.append('\n')
    for label, s_ in WORDS:
        b.append(db_str(label, s_))
    # τα κουμπιά του HUD (mockup.BUTTONS): το πλαίσιο (byte, γραμμή του HUD),
    # η ετικέτα· και τα pens του φόντου τους, κανονικό και φωτισμένο
    import mockup
    import cpcimg
    xy = [mockup.btn_xy(k) for k in range(len(mockup.BUTTONS))]
    b.append('\nUB_N        equ %d\nUB_W        equ 6              ; bytes\n'
             'UB_H        equ 17\n' % len(xy))
    def hud_adr(x, y):              # η σελίδα του HUD: διάταξη CRTC, αρχή 0
        y -= mockup.MAP_H
        return 0x4000 + (y & 7) * 0x800 + (y >> 3) * 80 + x // 2 - 1
    b.append('ui_btn:     dw %s\n' % ', '.join(
        '#%04X' % hud_adr(x, y) for x, y in xy))
    b.append('ui_blbl:    dw %s\n' % ', '.join(
        'ul_%d' % k for k in range(len(xy))))
    for k, (_, lbl) in enumerate(mockup.BUTTONS):
        b.append(db_str('ul_%d' % k, lbl))
    # Ο φωτισμός αλλάζει pen ΤΟ ΦΟΝΤΟ <-> ΤΟ ΦΩΤΙΣΜΕΝΟ, pixel προς pixel
    # (game/ui_hud_b.asm): αν το φωτισμένο pen υπήρχε σε εικονίδιο, το σβήσιμο
    # θα το έκανε φόντο.
    for art, _ in mockup.BUTTONS:
        icon = mockup.T.hud(mockup.HUD_ART[art])
        assert all(px != gfx.PEN[mockup.BTN_HI] for row in icon for px in row), \
            'BTN_HI στο εικονίδιο ' + art
    for name, pen in (('UB_PEN', mockup.BTN_PEN), ('UB_HI', mockup.BTN_HI)):
        q = gfx.PEN[pen]
        b.append('%s_L    equ #%02X\n%s_R    equ #%02X\n'
                 % (name, cpcimg.mode0_byte(q, 0) & 0xAA,
                    name, cpcimg.mode0_byte(0, q) & 0x55))
    c = [head, '; οι τεχνολογίες, με τη σειρά του techs\n',
         'ui_tech:    dw %s\n' % ', '.join('ut_%d' % k
                                         for k in range(len(TECHS)))]
    for k, s_ in enumerate(TECHS):
        c.append(db_str('ut_%d' % k, s_))
    for name, part in (('ui_a.asm', a), ('ui_b.asm', b), ('ui_c.asm', c)):
        print(write(name, ''.join(part)))
    stale = os.path.join(DATA, 'ui.asm')
    if os.path.exists(stale):
        os.remove(stale)


if __name__ == '__main__':
    main()
