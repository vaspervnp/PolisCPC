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


def res_mask():
    """Οι τύποι κτιρίων με τουλάχιστον μία τεχνολογία (game/bank7.asm, TECH
    BTY_...): για το RESEARCH (M22)."""
    import re
    src = open(os.path.join(gfx.OUT, 'game', 'bank7.asm')).read()
    types = {t[0]: i for i, t in enumerate(MB.TYPES)}
    m = 0
    for name in re.findall(r'^\s*TECH BTY_([A-Z_]+),', src, re.M):
        m |= 1 << types[name.lower()]
    assert m, 'TECH'
    return m


# (M22) Τα εικονίδια των κουμπιών, μόνο οι γραμμές τους με σχέδιο, και ο
# πίνακάς τους (ui_ic_tab: dw γραμμές, db η πρώτη | η τράπεζα x 16, db
# πόσες· το hb_draw τα αντιγράφει με το rst 8 από την τράπεζα του πίνακα).
# (2026-11-25) Με το γράμμα του πλήκτρου τους (mockup.btn_icon: 548 bytes,
# ήταν 488), σε ό,τι κενό υπάρχει — κάθε εικονίδιο σε ένα κομμάτι:
#   C5 #7380 (το αχρησιμοποίητο βέλος SPR_ARROW), C5 #7A40 (μετά τα 1.600
#   bytes των περιγραμμάτων OCC_E, ως τις σελίδες τους στο #7B00), C6 #5F48
#   (μετά το μεγαλύτερο αρχείο εποχής, ως την ομίχλη), και κομμάτια της
#   σελίδας του HUD: UI_M (το set_palette της εκκίνησης, game/boot.asm),
#   UI_K, UI_L. Ο πίνακας στο UI_P.
IC_BANK = [('ic_c5a.bin', 0x7380, 5, 128, ['eject', 'age_up']),
           ('ic_c5b.bin', 0x7A40, 5, 0x7B00 - 0x7A40,
            ['save', 'cancel', 'research']),
           ('ic_c6.bin', 0x5F48, 6, 0x5F80 - 0x5F48, ['pause'])]
IC_HUD = [('ui_m.asm', 61, ['build']), ('ui_k.asm', 61, ['idle']),
          ('ui_l.asm', 65, ['patrol'])]


def icons(head, mockup, cpcimg):
    keys = [k for k, _ in mockup.BUTTONS]
    rows = {}
    for k, art in enumerate(keys):
        ic = mockup.btn_icon(k)
        bg = gfx.PEN[mockup.BTN_PEN]
        px = [[bg if p is None else p for p in r] for r in ic]
        used = [y for y, r in enumerate(ic) if any(p is not None for p in r)]
        y0, y1 = used[0], used[-1] + 1
        rows[art] = (y0, y1 - y0, bytes(
            cpcimg.mode0_byte(px[y][2 * x], px[y][2 * x + 1])
            for y in range(y0, y1) for x in range(4)))
    where = {}
    for name, at, bank, cap, arts in IC_BANK:
        blob = b''
        for art in arts:
            where[art] = ('#%04X' % (at + len(blob)), bank)
            blob += rows[art][2]
        assert len(blob) <= cap, '%s: %d > %d' % (name, len(blob), cap)
        with open(os.path.join(DATA, name), 'wb') as f:
            f.write(blob + bytes(cap - len(blob)))
        print(os.path.join(DATA, name), len(blob), 'από', cap)
    for name, cap, arts in IC_HUD:
        out = [head]
        size = 0
        for art in arts:
            y0, n, data = rows[art]
            lab = 'ui_ic_%d' % keys.index(art)
            where[art] = (lab, 0)
            out.append('%s:  ; %s, γραμμές %d-%d\n' % (lab, art, y0, y0 + n - 1))
            for k in range(0, len(data), 4):
                out.append('        db %s\n' % ', '.join(
                    '#%02X' % x for x in data[k:k + 4]))
            size += len(data)
        assert size <= cap, '%s: %d > %d' % (name, size, cap)
        print(write(name, ''.join(out)))
    assert set(where) == set(keys), where
    tab = [head, '; ο πίνακας των εικονιδίων (UI_P): η πρώτη γραμμή | η '
           'τράπεζα x 16 (0: C0)\n', 'ui_ic_tab:\n']
    for k, art in enumerate(keys):
        y0, n, _ = rows[art]
        adr, bank = where[art]
        tab.append('        dw %s\n        db %d | %d << 4, %d   ; %s (%s)\n'
                   % (adr, y0, bank, n, art, mockup.BUTTON_KEYS[k]))
    print(write('ui_p.asm', ''.join(tab)))
    print(write('ui_j.asm', head + '; (2026-11-25: τα εικονίδια αλλού)\n'))


def end_icon(name):
    """(M22) Εικονίδιο του παλιού πάνελ των εντολών (terrain.COMMANDS): οι
    γραμμές του, με το διάφανο = το φόντο του HUD."""
    import mockup
    T = mockup.T
    bg = gfx.PEN[mockup.HUD_BG]
    art = [a for n, _, a, _ in T.COMMANDS if n == name][0]
    return [[bg if p is None else p for p in r] for r in T.hud(art)]


def end_bytes(name):
    """Το εικονίδιο σε bytes Mode 0, 4 x 16 (όπως στην κάρτα του HUD)."""
    import cpcimg
    return bytes(cpcimg.mode0_byte(r[2 * x], r[2 * x + 1])
                 for r in end_icon(name) for x in range(4))


SKULL_PEN = 9


def end_icons():
    """(M22) Η κάρτα του HUD στο τέλος της παρτίδας (main.asm, hud_end): η
    σημαία της νίκης (4 x 16 bytes, όλα τα χρώματα) στο τέλος του UI.BIN —
    το ui_load (init.asm) τη γράφει στο END_IC της C6· η νεκροκεφαλή της
    ήττας (ένα χρώμα, SKULL_PEN: 1 bit ανά pixel, 16 bytes) στο hb_skull
    (data/ui_skull.asm, στο κομμάτι του ήχου). Ως το M19 ήταν εικονίδια του
    πάνελ των 16 εντολών, που το M20 το κατάργησε."""
    import mockup
    flag = end_bytes('rally')
    with open(os.path.join(DATA, 'ui_end.bin'), 'wb') as f:
        f.write(flag)
    bg = gfx.PEN[mockup.HUD_BG]
    rows = end_icon('delete')
    assert {p for r in rows for p in r} <= {bg, SKULL_PEN}, 'νεκροκεφαλή'
    bits = [sum(128 >> x for x in range(8) if r[x] == SKULL_PEN)
            for r in rows]
    print(write('ui_skull.asm', '; ΠΑΡΑΓΕΤΑΙ από src/make_ui.py (M22): η '
                'νεκροκεφαλή της ήττας, 1 bit ανά pixel (pen %d)\nhb_skull:'
                '   db %s\n' % (SKULL_PEN, ', '.join('#%02X' % b
                                                     for b in bits))))


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
    xy = [mockup.btn_xy(k) for k in range(mockup.SLOTS)]
    b.append('\nUB_N        equ %d\nUB_W        equ 6              ; bytes\n'
             'UB_H        equ 17\n' % len(xy))
    def hud_adr(x, y):              # η σελίδα του HUD: διάταξη CRTC, αρχή 0
        y -= mockup.MAP_H
        return 0x4000 + (y & 7) * 0x800 + (y >> 3) * 80 + x // 2 - 1
    b.append('ui_btn:     dw %s\n' % ', '.join(
        '#%04X' % hud_adr(x, y) for x, y in xy))
    lbls = [lbl for _, lbl in mockup.BUTTONS] + [mockup.CONTINUE]
    b.append('ui_blbl:    dw %s\n' % ', '.join(
        'ul_%d' % k for k in range(len(lbls))))
    for k, lbl in enumerate(lbls):         # (το γράμμα του πλήκτρου: bit 7)
        g = list(enc(lbl))
        for i in mockup.key_index(lbl, min(k, 8)):
            g[i] |= 0x80
        b.append('ul_%d: db %d%s  ; %s\n' % (k, len(g), ''.join(
            ', %d' % x for x in g), lbl))
    # Ο φωτισμός αλλάζει pen ΤΟ ΦΟΝΤΟ <-> ΤΟ ΦΩΤΙΣΜΕΝΟ, pixel προς pixel
    # (game/ui_hud_b.asm): αν το φωτισμένο pen υπήρχε σε εικονίδιο, το σβήσιμο
    # θα το έκανε φόντο.
    for art, _ in mockup.BUTTONS:
        icon = mockup.T.hud(mockup.HUD_ART[art])
        assert all(px != gfx.PEN[mockup.BTN_HI] for row in icon for px in row), \
            'BTN_HI στο εικονίδιο ' + art
    v = [head, '; τα pens των κουμπιών και ποια κτίρια έχουν έρευνες (M22: ο\n'
         '; κύριος κώδικας, hb_tick — και στο snapshot)\n']
    for name, pen in (('UB_PEN', mockup.BTN_PEN), ('UB_HI', mockup.BTN_HI),
                      ('UB_BG', mockup.HUD_BG)):
        q = gfx.PEN[pen]
        v.append('%s_L    equ #%02X\n%s_R    equ #%02X\n'
                 % (name, cpcimg.mode0_byte(q, 0) & 0xAA,
                    name, cpcimg.mode0_byte(0, q) & 0x55))
    v.append('UB_RES      equ #%04X           ; bit = τύπος κτιρίου με έρευνες\n'
             % res_mask())
    q = SKULL_PEN
    v.append('UB_SK_L     equ #%02X\nUB_SK_R     equ #%02X  ; η νεκροκεφαλή (hud_end)\n'
             % (cpcimg.mode0_byte(q, 0) & 0xAA, cpcimg.mode0_byte(0, q) & 0x55))
    icons(head, mockup, cpcimg)
    end_icons()
    c = [head, '; οι τεχνολογίες, με τη σειρά του techs\n',
         'ui_tech:    dw %s\n' % ', '.join('ut_%d' % k
                                         for k in range(len(TECHS)))]
    for k, s_ in enumerate(TECHS):
        c.append(db_str('ut_%d' % k, s_))
    for name, part in (('ui_a.asm', a), ('ui_b.asm', b), ('ui_c.asm', c),
                       ('ui_vis.asm', v)):
        print(write(name, ''.join(part)))
    stale = os.path.join(DATA, 'ui.asm')
    if os.path.exists(stale):
        os.remove(stale)


if __name__ == '__main__':
    main()
