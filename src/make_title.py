"""Η οθόνη του μενού (M13): εικόνα ολόκληρης οθόνης για τη δισκέτα.

    python3 src/make_title.py

-> data/title.bin     η μνήμη της οθόνης (16.384 bytes, Mode 0, η διάταξη
                      του CPC: γραμμή y στο #C000 + (y & 7) * #800 +
                      (y >> 3) * 80). Το build.sh τη βάζει συμπιεσμένη στη
                      δισκέτα (TITLE.BIN), και το μενού (game/menu.asm) τη
                      φορτώνει πριν ζωγραφίσει τις επιλογές από πάνω.
-> data/title.asm     TITLE_Z: το μέγεθός της συμπιεσμένη (το μενού την
                      περνάει στο #B000 για να την αποσυμπιέσει στην οθόνη)
-> preview/title.png

Από πάνω προς τα κάτω: το λογότυπο POLIS (η γραμματοσειρά του μενού σε
τριπλό μέγεθος, χρυσό με σκιά), μια σκηνή από την πόλη των Ελλήνων του
src/mockup.py — με τα ίδια τα γραφικά του παιχνιδιού — σε πλαίσιο, ο
χώρος των επιλογών (μαύρος: τις γράφει ο Z80), και τα credits.
"""
import os

import gfx
import make_menu as MN
import mockup

DATA = os.path.join(gfx.OUT, 'data')
W, H = 160, 200
LOGO = 'POLIS'
LOGO_Y, LOGO_S = 4, 3                   # η γραμμή, η κλίμακα (pixels)
SCENE_Y0, SCENE_Y1 = 52, 116            # η σκηνή: οι γραμμές της
SCENE_AT = (33, 61)                     # το πλακίδιο στο κέντρο της
CREDITS = 'REVIVE8BIT - 2026 - VASPER'
CREDITS_Y = 185
P = gfx.PEN
# το λογότυπο από πάνω προς τα κάτω: χρυσό, πορτοκαλί
LOGO_PENS = [P['y'], P['y'], P['y'], P['y'], P['D'], P['D'], P['D']]
SHADOW = P['d']
FRAME = P['o']


def text(img, s, x, y, pen):
    """Η γραμματοσειρά του μενού (όπως το mn_glyph): x σε bytes."""
    for k, ch in enumerate(s):
        for r, row in enumerate(MN.GLYPHS[ch]):
            for i, b in enumerate(row):
                if b == '#':
                    for dy in (0, 1):
                        img[y + 2 * r + dy][2 * (x + MN.CELL * k) + i] = pen


def logo(img):
    s, gap = LOGO_S, 3
    w = len(LOGO) * 5 * s + (len(LOGO) - 1) * gap
    x0 = (W - w) // 2
    for layer in ('shadow', 'face'):
        for k, ch in enumerate(LOGO):
            for r, row in enumerate(MN.GLYPHS[ch]):
                for i, b in enumerate(row):
                    if b != '#':
                        continue
                    for dy in range(2 * s):
                        for dx in range(s):
                            x = x0 + k * (5 * s + gap) + i * s + dx
                            y = LOGO_Y + r * 2 * s + dy
                            if layer == 'shadow':
                                img[y + 2][x + 1] = SHADOW
                            else:
                                img[y][x] = LOGO_PENS[r]


def scene(img):
    grd, res = mockup.make_map()
    world = mockup.render_world(grd, res)
    cx, cy = mockup.world_xy(*SCENE_AT)
    x0 = cx + 4 - W // 2
    y0 = cy - (SCENE_Y1 - SCENE_Y0) // 2 - 8
    for y in range(SCENE_Y0, SCENE_Y1):
        for x in range(W):
            img[y][x] = world[y0 + y - SCENE_Y0][x0 + x] or 0
    for x in range(W):
        img[SCENE_Y0 - 2][x] = FRAME
        img[SCENE_Y1 + 1][x] = FRAME


def image():
    """Η οθόνη ως [y][x] pens."""
    img = [[0] * W for _ in range(H)]
    logo(img)
    scene(img)
    text(img, CREDITS, (80 - MN.CELL * len(CREDITS)) // 2, CREDITS_Y,
         P['i'])
    return img


def screen_bytes(img):
    import cpcimg
    out = bytearray(16384)
    for y in range(H):
        a = (y & 7) * 0x800 + (y >> 3) * 80
        for b in range(80):
            out[a + b] = cpcimg.mode0_byte(img[y][2 * b], img[y][2 * b + 1])
    return bytes(out)


def main():
    import dsk
    img = image()
    raw = screen_bytes(img)
    open(os.path.join(DATA, 'title.bin'), 'wb').write(raw)
    z = len(dsk.zx0(raw))
    assert z <= 0xBF00 - 0xB000, 'TITLE.BIN: %d bytes συμπιεσμένο' % z
    with open(os.path.join(DATA, 'title.asm'), 'w') as f:
        f.write('; title.asm — ΠΑΡΑΓΕΤΑΙ από src/make_title.py\n'
                'TITLE_Z     equ %d            ; το TITLE.BIN συμπιεσμένο\n'
                % z)
    import preview
    path = os.path.join(gfx.OUT, 'preview', 'title.png')
    preview.contact_sheet(path, [('', img)], zoom=3, cols=1, title='',
                          grid=False)
    print('data/title.bin (%d bytes συμπιεσμένο), data/title.asm, %s'
          % (z, path))


if __name__ == '__main__':
    main()
