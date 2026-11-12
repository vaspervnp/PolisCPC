"""Το μενού έναρξης (M12): γραμματοσειρά και κείμενα για τον Z80.

    python3 src/make_menu.py

-> data/menu.asm    η γραμματοσειρά (5 x 7, ένα byte ανά γραμμή: τα bits
                    4..0 από αριστερά), οι γραμμές του μενού (γραμμή οθόνης,
                    byte, pen ως αριστερό pixel, πλήθος, γλύφοι) και η θέση
                    κάθε επιλογής. Οι επιλογές με τη σειρά των CULTURES του
                    src/make_bank6.py, και τελευταία το φόρτωμα.

Κάθε γραμμή της γραμματοσειράς ζωγραφίζεται σε ΔΥΟ γραμμές οθόνης (το pixel
του Mode 0 είναι διπλό σε πλάτος: έτσι τα γράμματα έχουν σωστές αναλογίες).
"""
import os

import gfx
import make_bank6 as MB

DATA = os.path.join(gfx.OUT, 'data')

GLYPHS = {
    ' ': ['.....'] * 7,
    '>': ['.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'],
    'Α': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'Β': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'Γ': ['#####', '#....', '#....', '#....', '#....', '#....', '#....'],
    'Ε': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'Η': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'Ι': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    'Κ': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
    'Λ': ['..#..', '.#.#.', '.#.#.', '#...#', '#...#', '#...#', '#...#'],
    'Μ': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'Ν': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'Ο': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'Π': ['#####', '#...#', '#...#', '#...#', '#...#', '#...#', '#...#'],
    'Ρ': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'Σ': ['#####', '.#...', '..#..', '...#.', '..#..', '.#...', '#####'],
    'Τ': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'Υ': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
    'Φ': ['..#..', '.###.', '#.#.#', '#.#.#', '.###.', '..#..', '..#..'],
    'Ω': ['.###.', '#...#', '#...#', '#...#', '.#.#.', '.#.#.', '##.##'],
}
NAMES = {'egypt': 'ΑΙΓΥΠΤΙΟΙ', 'greek': 'ΕΛΛΗΝΕΣ', 'babylon': 'ΒΑΒΥΛΩΝΙΟΙ',
         'asia': 'ΑΣΙΑΤΕΣ', 'rome': 'ΡΩΜΑΙΟΙ', 'persia': 'ΠΕΡΣΕΣ',
         'phoenicia': 'ΦΟΙΝΙΚΕΣ', 'celt': 'ΚΕΛΤΕΣ'}
TITLE = 'ΠΟΛΙΣ'
LOAD = 'ΦΟΡΤΩΣΗ'
PEN_TEXT, PEN_HI = 9, 10                # λευκό, κίτρινο (palette.asm)
CELL = 3                                # bytes ανά γράμμα (6 pixels)
ITEM_X, ITEM_Y0, ITEM_DY = 24, 44, 16   # οι επιλογές (bytes, γραμμές)
TITLE_Y = 12
DEFAULT = 1                             # οι Έλληνες (οι εικόνες της εκκίνησης)


def left_byte(pen):
    """Το pen ως αριστερό pixel ενός byte Mode 0 (το δεξί: >> 1)."""
    import cpcimg
    return cpcimg.mode0_byte(pen, 0)


def main():
    order = list(GLYPHS)
    font = []
    for ch in order:
        rows = GLYPHS[ch]
        assert len(rows) == 7 and all(len(r) == 5 for r in rows), ch
        font += [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows]
    items = [NAMES[c] for c, _ in MB.CULTURES] + [LOAD]
    lines = [(TITLE_Y, (80 - CELL * len(TITLE)) // 2, PEN_HI, TITLE)]
    for k, text in enumerate(items):
        pen = PEN_HI if text == LOAD else PEN_TEXT
        lines.append((ITEM_Y0 + k * ITEM_DY, ITEM_X, pen, text))
    out = ['; menu.asm — ΠΑΡΑΓΕΤΑΙ από src/make_menu.py — μην το πειράζεις με '
           'το χέρι.\n\n',
           'MENU_N      equ %d             ; επιλογές: οι πολιτισμοί, το φόρτωμα\n'
           % len(items),
           'MENU_DEF    equ %d\n' % DEFAULT,
           'MENU_X      equ %d             ; το βέλος: byte\n' % (ITEM_X - 2 * CELL),
           'MENU_Y0     equ %d\nMENU_DY     equ %d\n' % (ITEM_Y0, ITEM_DY),
           'MG_BLANK    equ %d\nMG_ARROW    equ %d\n'
           % (order.index(' '), order.index('>')),
           'MENU_PEN    equ #%02X           ; το βέλος: κίτρινο\n'
           % left_byte(PEN_HI),
           'menu_font:  ; %s\n' % ''.join(order)]
    for k in range(0, len(font), 7):
        out.append('        db %s\n' % ','.join('#%02X' % b for b in font[k:k + 7]))
    out.append('menu_lines: ; γραμμή, byte, pen, πλήθος, γλύφοι\n')
    for y, x, pen, text in lines:
        out.append('        db %d, %d, #%02X, %d, %s    ; %s\n'
                   % (y, x, left_byte(pen), len(text),
                      ', '.join(str(order.index(ch)) for ch in text), text))
    out.append('        db 255\n')
    path = os.path.join(DATA, 'menu.asm')
    open(path, 'w').write(''.join(out))
    print('%s: %d γλύφοι, %d γραμμές' % (path, len(order), len(lines)))


if __name__ == '__main__':
    main()
