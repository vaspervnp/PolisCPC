"""Ο κέρσορας, το σημάδι επιλογής και η γωνία του κουτιού επιλογής (M4).

    python3 src/make_cursor.py      -> data/cursor.bin (3 x 128 bytes)

Τρία sprites 8x16 με μάσκα, ίδια μορφή με τις μονάδες — ίδιο blit16:

    0  ο κέρσορας: βέλος, το «σημείο» του είναι το πάνω-αριστερό pixel
    1  το σημάδι επιλογής: αγκύλες στα πόδια, ζωγραφίζεται ΠΑΝΩ από τη
       μονάδα στο ίδιο ορθογώνιο (άρα δεν αλλάζει το σβήσιμο)
    2  η γωνία όπου άρχισε το κουτί επιλογής
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gfx                                      # noqa: E402

ROOT = os.path.dirname(HERE)

CURSOR = '''
K-------
KK------
KIK-----
KIIK----
KIIIK---
KIIIIK--
KIIIIIK-
KIIKKKK-
KIK-K---
KK--KK--
K----K--
-----KK-
------K-
'''

MARK = '''
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
II----II
I------I
'''

ANCHOR = '''
IIII----
I-------
I-------
I-------
'''


def sprite(art):
    img = gfx.blank(8, 16, None)
    return gfx.stamp(img, gfx.parse_art(art))


def main():
    sprites = [sprite(a) for a in (CURSOR, MARK, ANCHOR)]
    blob = b''.join(gfx.encode_masked(s) for s in sprites)
    assert len(blob) == 3 * 128
    for k, s in enumerate(sprites):
        assert gfx.decode_masked(blob[k * 128:(k + 1) * 128], 8, 16) == s
    path = os.path.join(ROOT, 'data', 'cursor.bin')
    with open(path, 'wb') as f:
        f.write(blob)
    print(path, len(blob), 'bytes')


if __name__ == '__main__':
    main()
