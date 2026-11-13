"""Το tutorial: ο Ηρόδοτος εξηγεί το επόμενο βήμα, σε παράθυρο στη μέση της
οθόνης.

    python3 src/make_tutor.py

-> data/tutor.asm     τα δεδομένα του game/tutor.asm: το πορτρέτο (Mode 0,
                      ωμά bytes), η γραμματοσειρά (του μενού και . , ! '),
                      τα κείμενα των βημάτων (TUT_ROWS γραμμές x TUT_COLS
                      γλύφοι), οι διαστάσεις του παραθύρου
-> preview/tutor.png  το παράθυρο κάθε βήματος (στην περιοχή του χάρτη,
                      160 x 144), όπως το ζωγραφίζει ο Z80

Το παράθυρο: πλαίσιο χρυσό, γέμισμα μπλε (το pen του HUD), αριστερά το
πορτρέτο, πάνω ο τίτλος HERODOTUS, δεξιά το κείμενο, κάτω δεξιά RETURN.
Τα βήματα και πότε τελειώνει το καθένα: STEPS (ο έλεγχος είναι στο
game/tutor.asm, tut_goals, με την ίδια σειρά).
"""
import os

import gfx
import make_menu as MN

DATA = os.path.join(gfx.OUT, 'data')
P = gfx.PEN

# ---------------------------------------------------------------- παράθυρο
# (bytes, γραμμές της περιοχής του χάρτη: 80 x 144)
WIN_X, WIN_Y, WIN_W, WIN_H = 6, 16, 68, 120
BG, FRAME, TITLE_PEN, TEXT_PEN, HINT_PEN = P['K'], P['y'], P['y'], P['I'], P['i']
POR_W, POR_H = 10, 36                   # bytes (20 pixels), γραμμές
POR_X, POR_Y = WIN_X + 3, WIN_Y + 22
TEXT_X = POR_X + POR_W + 3              # byte
TEXT_Y0, LINE_DY = WIN_Y + 22, 15
TUT_COLS = (WIN_X + WIN_W - 2 - TEXT_X) // MN.CELL
TUT_ROWS = 5
TITLE = 'HERODOTUS'
HINT = 'RETURN'
TITLE_Y = WIN_Y + 4
HINT_Y = WIN_Y + WIN_H - 19

# Τα βήματα: (κείμενο, πότε τελειώνει — το όνομα του ελέγχου στο tutor.asm)
STEPS = [
    ("WELCOME! I AM HERODOTUS. I WILL SHOW YOU HOW TO BUILD A POLIS.",
     'g_now'),
    ("MOVE THE CURSOR WITH Q A O P. PUT IT ON A VILLAGER AND PRESS SPACE.",
     'g_sel'),
    ("NOW PUT THE CURSOR ON THE BERRY BUSH AND PRESS RETURN.",
     'g_gather'),
    ("GOOD! SELECT A VILLAGER, PRESS H, THEN RETURN TO BUILD A HOUSE.",
     'g_house'),
    ("CLICK THE TOWN CENTER WITH SPACE AND PRESS T FOR A VILLAGER.",
     'g_train'),
    ("SELECT A VILLAGER AND PRESS B FOR BARRACKS. THEY TRAIN SOLDIERS.",
     'g_barr'),
    ("WHEN THEY ARE BUILT, CLICK THE BARRACKS AND PRESS T.",
     'g_sword'),
    ("THE ENEMY LIVES TO THE NORTH EAST. SEND YOUR ARMY WITH RETURN!",
     'g_now'),
]

# ---------------------------------------------------------------- γραμματοσειρά
EXTRA = {
    '.': ['.....', '.....', '.....', '.....', '.....', '.##..', '.##..'],
    ',': ['.....', '.....', '.....', '.....', '.##..', '..#..', '.#...'],
    '!': ['..#..', '..#..', '..#..', '..#..', '..#..', '.....', '..#..'],
    "'": ['..#..', '..#..', '.#...', '.....', '.....', '.....', '.....'],
}
GLYPHS = dict(MN.GLYPHS, **EXTRA)
ORDER = list(GLYPHS)


def wrap(text):
    lines, cur = [], ''
    for w in text.split():
        t = (cur + ' ' + w).strip()
        if len(t) <= TUT_COLS:
            cur = t
        else:
            lines.append(cur)
            cur = w
    lines.append(cur)
    assert len(lines) <= TUT_ROWS, (text, lines)
    return lines + [''] * (TUT_ROWS - len(lines))


# ---------------------------------------------------------------- πορτρέτο

# '.' = το φόντο του παραθύρου· τα άλλα γράμματα: gfx.PEN
PORTRAIT = [
    '....................',
    '.......iIIIIIi......',
    '.....gIIIIIIIIIg....',
    '....ngIIIIIIIIIgn...',
    '...gnIIIIIIIIIIIng..',
    '...gngngngngngngng..',
    '...IISSSSSSSSSSsII..',
    '...ISSSSSSSSSSSSsI..',
    '...ISiiiSSSSiiiSsI..',
    '...ISSSSSSSSSSSSsI..',
    '...ISIdSSSSSIdSSsI..',
    '...ISSSSSSDSSSSSsI..',
    '..IISSSSSSDSSSSSsII.',
    '..IIsSSSSSDDSSSsiII.',
    '..IIIsSSSSSSSSsIIII.',
    '..IIIiIIiiiiIIiIIII.',
    '..IIIIIIdddddIIIIII.',
    '..IIiIIIIIIIIIIiIII.',
    '...IIIIiIIIIiIIIII..',
    '...IIiIIIIIIIIiIII..',
    '....IIIIIiIIIIIII...',
    '....IIiIIIIIIIiII...',
    '.....IIIIiIIIIII....',
    '......IIIIIIIII.....',
    '.....SSIIiIIISS.....',
    '...SSSSSIIIISSSSS...',
    '..SSSSSSSSSSSSSSSSS.',
    '.SSySSSoSSSSSSoSSSSS',
    '.SSrrSSoSSSSSSoSSSSS',
    'SSSSrrSoSSSSSSoSSSSS',
    'SSSSSrroSSSSSSoSSSSS',
    'SSSSSSrrSSSSSSoSSSSS',
    'SSSSSSSrrSSSSSoSSSSS',
    'SSSSSSSorrSSSSoSSSSS',
    'SSSSSSSoSrrSSSoSSSSS',
    'SSSSSSSoSSrrSSoSSSSS',
]


def portrait():
    """Ο Ηρόδοτος: ηλικιωμένος, γένια και μαλλιά λευκά, στεφάνι δάφνης,
    λινός χιτώνας με κόκκινο ιμάτιο. 20 x 36 pixels Mode 0 (pens)."""
    assert len(PORTRAIT) == POR_H
    assert all(len(r) == 2 * POR_W for r in PORTRAIT)
    return [[BG if ch == '.' else P[ch] for ch in r] for r in PORTRAIT]


def portrait_bytes():
    import cpcimg
    img = portrait()
    return [cpcimg.mode0_byte(r[2 * b], r[2 * b + 1])
            for r in img for b in range(POR_W)]


# ---------------------------------------------------------------- εικόνα

def text_px(img, s, xb, y, pen):
    """Όπως το tut_text: x σε bytes, οι γραμμές του γλύφου διπλές."""
    for k, ch in enumerate(s):
        for r, row in enumerate(GLYPHS[ch]):
            for i, b in enumerate(row):
                if b == '#':
                    for dy in (0, 1):
                        img[y + 2 * r + dy][2 * (xb + MN.CELL * k) + i] = pen


def window(img, step):
    """Το παράθυρο του βήματος step πάνω στην εικόνα [y][x] (160 x 144)."""
    x0, x1 = 2 * WIN_X, 2 * (WIN_X + WIN_W)
    for y in range(WIN_Y, WIN_Y + WIN_H):
        for x in range(x0, x1):
            edge = y in (WIN_Y, WIN_Y + WIN_H - 1) or x in (x0, x1 - 1)
            img[y][x] = FRAME if edge else BG
    por = portrait()
    for y in range(POR_H):
        for x in range(2 * POR_W):
            img[POR_Y + y][2 * POR_X + x] = por[y][x]
    text_px(img, TITLE, TEXT_X, TITLE_Y, TITLE_PEN)
    for r, line in enumerate(wrap(STEPS[step][0])):
        text_px(img, line, TEXT_X, TEXT_Y0 + r * LINE_DY, TEXT_PEN)
    text_px(img, HINT, WIN_X + WIN_W - 2 - MN.CELL * len(HINT), HINT_Y,
            HINT_PEN)
    return img


def main():
    import cpcimg
    rows = []
    for ch in ORDER:
        r = GLYPHS[ch]
        assert len(r) == 7 and all(len(x) == 5 for x in r), ch
        rows += [int(x.replace('#', '1').replace('.', '0'), 2) for x in r]
    # τα 4 bytes ανά pen: (φόντο|φόντο, φόντο|pen, pen|φόντο, pen|pen) —
    # το byte ενός ζεύγους pixels του γλύφου (tut_glyph)
    pairs = {}
    for name, pen in (('TITLE', TITLE_PEN), ('TEXT', TEXT_PEN),
                      ('HINT', HINT_PEN)):
        pairs[name] = [cpcimg.mode0_byte(a, b) for a, b in
                       ((BG, BG), (BG, pen), (pen, BG), (pen, pen))]
    enc = lambda s: ', '.join(str(ORDER.index(ch)) for ch in s)  # noqa: E731
    out = ['; tutor.asm — ΠΑΡΑΓΕΤΑΙ από src/make_tutor.py — μην το '
           'πειράζεις με το χέρι.\n\n',
           'TW_X        equ %d\nTW_Y        equ %d\nTW_W        equ %d\n'
           'TW_H        equ %d\n' % (WIN_X, WIN_Y, WIN_W, WIN_H),
           'TW_BG       equ #%02X           ; το γέμισμα\n'
           % cpcimg.mode0_byte(BG, BG),
           'TW_FRAME    equ #%02X           ; το πλαίσιο\n'
           % cpcimg.mode0_byte(FRAME, FRAME),
           'TW_FRAME_L  equ #%02X           ; πλαίσιο | γέμισμα\n'
           % cpcimg.mode0_byte(FRAME, BG),
           'TW_FRAME_R  equ #%02X           ; γέμισμα | πλαίσιο\n'
           % cpcimg.mode0_byte(BG, FRAME),
           'TP_X        equ %d\nTP_Y        equ %d\nTP_W        equ %d\n'
           'TP_H        equ %d\n' % (POR_X, POR_Y, POR_W, POR_H),
           'TT_X        equ %d\nTT_Y0       equ %d\nTT_DY       equ %d\n'
           % (TEXT_X, TEXT_Y0, LINE_DY),
           'TUT_COLS    equ %d\nTUT_ROWS    equ %d\nTUT_STEPS   equ %d\n'
           % (TUT_COLS, TUT_ROWS, len(STEPS)),
           'TT_TITLE_Y  equ %d\nTT_HINT_X   equ %d\nTT_HINT_Y   equ %d\n'
           % (TITLE_Y, WIN_X + WIN_W - 2 - MN.CELL * len(HINT), HINT_Y),
           'TG_SPACE    equ %d\n' % ORDER.index(' ')]
    for name, b in pairs.items():
        out.append('tp_%s:%s db %s\n' % (name.lower(), ' ' * (8 - len(name)),
                                          ', '.join('#%02X' % x for x in b)))
    out.append('tut_title:  db %d, %s    ; %s\n' % (len(TITLE), enc(TITLE),
                                                    TITLE))
    out.append('tut_hint:   db %d, %s    ; %s\n' % (len(HINT), enc(HINT), HINT))
    out.append('tut_goals:  dw %s\n' % ', '.join(g for _, g in STEPS))
    out.append('tut_texts:  ; TUT_ROWS x TUT_COLS ανά βήμα\n')
    for text, _ in STEPS:
        for line in wrap(text):
            out.append('        db %s    ; %s\n'
                       % (enc(line.ljust(TUT_COLS)), line))
    out.append('tut_font:   ; %s\n' % ''.join(ORDER))
    for k in range(0, len(rows), 7):
        out.append('        db %s\n' % ','.join('#%02X' % b
                                              for b in rows[k:k + 7]))
    pb = portrait_bytes()
    out.append('tut_por:    ; %d x %d\n' % (POR_W, POR_H))
    for k in range(0, len(pb), POR_W):
        out.append('        db %s\n' % ','.join('#%02X' % b
                                              for b in pb[k:k + POR_W]))
    path = os.path.join(DATA, 'tutor.asm')
    open(path, 'w').write(''.join(out))

    shots = []
    import preview
    for k in range(len(STEPS)):
        img = [[0] * 160 for _ in range(144)]
        window(img, k)
        shots.append(('%d' % k, img))
    prev = os.path.join(gfx.OUT, 'preview', 'tutor.png')
    preview.contact_sheet(prev, shots, zoom=3, cols=4, title='', grid=False)
    print('%s: %d βήματα, %d γλύφοι, πορτρέτο %d bytes; %s'
          % (path, len(STEPS), len(ORDER), len(pb), prev))


if __name__ == '__main__':
    main()
