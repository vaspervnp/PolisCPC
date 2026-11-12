"""Το μενού έναρξης (M12): γραμματοσειρά και κείμενα για τον Z80.

    python3 src/make_menu.py

-> data/menu.asm    η γραμματοσειρά (λατινικά κεφαλαία 5 x 7, ένα byte ανά γραμμή: τα bits
                    4..0 από αριστερά), οι γραμμές του μενού (γραμμή οθόνης,
                    byte, pen ως αριστερό pixel, πλήθος, γλύφοι) και η θέση
                    κάθε επιλογής: PLAY AS <πολιτισμός> (αριστερά / δεξιά:
                    ο πολιτισμός, με τη σειρά των CULTURES του
                    src/make_bank6.py — cult_txt), οι εκστρατείες, το φόρτωμα.
                    Από πίσω η εικόνα του src/make_title.py.

Κάθε γραμμή της γραμματοσειράς ζωγραφίζεται σε ΔΥΟ γραμμές οθόνης (το pixel
του Mode 0 είναι διπλό σε πλάτος: έτσι τα γράμματα έχουν σωστές αναλογίες).
"""
import os

import gfx
import make_bank6 as MB

DATA = os.path.join(gfx.OUT, 'data')

GLYPHS = {   # (M13: αγγλικά — το παιχνίδι δεν έχει πια ελληνικό κείμενο)
    ' ': ['.....'] * 7,
    '>': ['.#...', '..#..', '...#.', '....#', '...#.', '..#..', '.#...'],
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
    'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.####'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    'J': ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'],
    'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
    'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
    'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
    'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'V': ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
    'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
    'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
    'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
    '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
    '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
    '3': ['####.', '....#', '....#', '.###.', '....#', '....#', '####.'],
    '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
    '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
    '6': ['.###.', '#....', '#....', '####.', '#...#', '#...#', '.###.'],
    '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
    '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
    '9': ['.###.', '#...#', '#...#', '.####', '....#', '....#', '.###.'],
    '/': ['....#', '....#', '...#.', '..#..', '.#...', '#....', '#....'],
    '-': ['.....', '.....', '.....', '.###.', '.....', '.....', '.....'],
    '<': ['...#.', '..#..', '.#...', '#....', '.#...', '..#..', '...#.'],
}
ORDER = list(GLYPHS)
NAMES = {'egypt': 'EGYPTIANS', 'greek': 'GREEKS', 'babylon': 'BABYLONIANS',
         'asia': 'ASIANS', 'rome': 'ROMANS', 'persia': 'PERSIANS',
         'phoenicia': 'PHOENICIANS', 'celt': 'CELTS'}
LOAD = 'LOAD GAME'
PLAY = 'PLAY AS '                       # + <πολιτισμός>: αριστερά / δεξιά
# Οι εκστρατείες (M13): (γράμμα των αρχείων LG1.BIN..., κείμενο του μενού)
CAMPAIGNS = [('G', 'GREEK CAMPAIGN'), ('E', 'EGYPTIAN CAMPAIGN')]
PEN_TEXT, PEN_HI = 9, 10                # λευκό, κίτρινο (palette.asm)
CELL = 3                                # bytes ανά γράμμα (6 pixels)
# οι επιλογές (bytes, γραμμές): κάτω από τη σκηνή της εικόνας (make_title)
ITEM_X, ITEM_Y0, ITEM_DY = 12, 122, 15
DEFAULT = 1                             # οι Έλληνες (οι εικόνες της εκκίνησης)
SEL0 = 0                                # η επιλογή με το βέλος στην αρχή
CULT_X = ITEM_X + CELL * len(PLAY)      # το πεδίο του πολιτισμού
CULT_N = 2 + max(len(n) for n in (
    'EGYPTIANS', 'GREEKS', 'BABYLONIANS', 'ASIANS', 'ROMANS', 'PERSIANS',
    'PHOENICIANS', 'CELTS'))


def left_byte(pen):
    """Το pen ως αριστερό pixel ενός byte Mode 0 (το δεξί: >> 1)."""
    import cpcimg
    return cpcimg.mode0_byte(pen, 0)


def cult_field(k):
    """Το πεδίο του πολιτισμού k (σειρά του MB.CULTURES), ως CULT_N γλύφοι."""
    return ('<' + NAMES[MB.CULTURES[k][0]] + '>').ljust(CULT_N)


def items(cult=DEFAULT):
    """Οι επιλογές με τη σειρά: παιχνίδι, οι εκστρατείες, το φόρτωμα."""
    return [PLAY + cult_field(cult).rstrip()] + [t for _, t in CAMPAIGNS] + \
        [LOAD]


def lines(cult=DEFAULT):
    """(γραμμή, byte, pen, κείμενο) όπως τα ζωγραφίζει το μενού."""
    out = [(ITEM_Y0, ITEM_X, PEN_TEXT, PLAY.rstrip()),
           (ITEM_Y0, CULT_X, PEN_HI, cult_field(cult))]
    for k, (_, t) in enumerate(CAMPAIGNS):
        out.append((ITEM_Y0 + (k + 1) * ITEM_DY, ITEM_X, PEN_TEXT, t))
    out.append((ITEM_Y0 + (len(CAMPAIGNS) + 1) * ITEM_DY, ITEM_X, PEN_TEXT,
                LOAD))
    return out


def encode_lines(lines):
    """[(γραμμή, byte, pen, κείμενο)] -> bytes όπως το menu_lines (και το
    κείμενο των πιστών, M13): γραμμή, byte, pen ως αριστερό pixel, πλήθος,
    γλύφοι, ... 255."""
    out = bytearray()
    for y, x, pen, text in lines:
        out += bytes([y, x, left_byte(pen), len(text)])
        out += bytes(ORDER.index(ch) for ch in text)
    return bytes(out + b'\xff')


def main():
    order = ORDER
    font = []
    for ch in order:
        rows = GLYPHS[ch]
        assert len(rows) == 7 and all(len(r) == 5 for r in rows), ch
        font += [int(r.replace('#', '1').replace('.', '0'), 2) for r in rows]
    its = items()
    static = [l for l in lines() if l[1] != CULT_X]
    assert CULT_X + CELL * CULT_N <= 80
    out = ['; menu.asm — ΠΑΡΑΓΕΤΑΙ από src/make_menu.py — μην το πειράζεις με '
           'το χέρι.\n\n',
           'MENU_N      equ %d             ; επιλογές: παιχνίδι, οι '
           'εκστρατείες, το φόρτωμα\n' % len(its),
           'MENU_CULT   equ %d             ; πολιτισμοί\n' % len(MB.CULTURES),
           'MENU_CAMP   equ %d\n' % len(CAMPAIGNS),
           'MENU_DEF    equ %d             ; ο πολιτισμός στην αρχή\n' % DEFAULT,
           'MENU_SEL0   equ %d\n' % SEL0,
           'MENU_X      equ %d             ; το βέλος: byte\n' % (ITEM_X - 2 * CELL),
           'CULT_LEN    equ %d             ; μια εγγραφή του cult_txt\n'
           % (4 + CULT_N + 1),
           'camp_let:   db "%s"           ; τα γράμματα των εκστρατειών\n'
           % ''.join(l for l, _ in CAMPAIGNS),
           'MG_BLANK    equ %d\nMG_ARROW    equ %d\n'
           % (order.index(' '), order.index('>')),
           'MENU_PEN    equ #%02X           ; το βέλος: κίτρινο\n'
           % left_byte(PEN_HI),
           'menu_font:  ; %s\n' % ''.join(order)]
    for k in range(0, len(font), 7):
        out.append('        db %s\n' % ','.join('#%02X' % b for b in font[k:k + 7]))
    out.append('menu_lines: ; γραμμή, byte, pen, πλήθος, γλύφοι\n')
    for y, x, pen, text in static:
        out.append('        db %d, %d, #%02X, %d, %s    ; %s\n'
                   % (y, x, left_byte(pen), len(text),
                      ', '.join(str(order.index(ch)) for ch in text), text))
    out.append('        db 255\n')
    out.append('cult_txt:   ; το πεδίο του πολιτισμού, ένα menu_lines ανά '
               'πολιτισμό\n')
    for k in range(len(MB.CULTURES)):
        out.append('        db %s    ; %s\n'
                   % (', '.join(str(b) for b in encode_lines(
                       [(ITEM_Y0, CULT_X, PEN_HI, cult_field(k))])),
                      cult_field(k)))
    out.append('menu_iy:    db %s     ; η γραμμή κάθε επιλογής\n'
               % ', '.join(str(ITEM_Y0 + k * ITEM_DY) for k in range(len(its))))
    path = os.path.join(DATA, 'menu.asm')
    open(path, 'w').write(''.join(out))
    print('%s: %d γλύφοι, %d γραμμές' % (path, len(order), len(static)))


if __name__ == '__main__':
    main()
