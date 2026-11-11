"""Η αναμενόμενη οθόνη με τις μονάδες, από τους πίνακες του Z80 (M3/M4).

Ο Z80 κρατάει τη σειρά σχεδίασης στο ORDER (δείκτες εγγραφών των 32 bytes)
και τη θέση οθόνης κάθε μονάδας στην εγγραφή της. Εδώ η ίδια εικόνα
συντίθεται στην Python, ανεξάρτητα: το φόντο του mockup, και από πάνω, με
τη σειρά του ORDER, το καρέ κάθε μονάδας όπως το ορίζουν σετ, όψη και
βήμα (οι όψεις W καθρεφτισμένες εδώ), οι αγκύλες των επιλεγμένων, η γωνία
του κουτιού και ο κέρσορας.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import gfx                                      # noqa: E402

UNITS, U_SIZE = 128, 32
UNIT_TAB = 0xAE00
ORDER = 0xA680
ACT_TAB = 0xA600
ANCHOR_REC = UNIT_TAB + UNITS * U_SIZE
CURSOR_REC = ANCHOR_REC + U_SIZE
SETS = ['villager_m', 'swordsman', 'archer']
F_MOVE, F_SEL, F_WANDER, F_FIXED = 1, 2, 4, 16
FACES = 'SENW'


def frames(name):
    blob = open(os.path.join(M.ROOT, 'data', name + '.bin'), 'rb').read()
    return [gfx.decode_masked(blob[k:k + 128], 8, 16)
            for k in range(0, len(blob), 128)]


SPRITES = [frames(n) for n in SETS]
CURSOR, MARK, ANCHOR = frames('cursor')[:3]


def rec(c, addr):
    b = c.read_ram(addr, U_SIZE)
    w = lambda o: b[o] | b[o + 1] << 8                     # noqa: E731
    return dict(addr=addr, wx=w(0), wy=w(2), tx=w(4), ty=w(6), set=b[8],
                step=b[9], face=b[10], fl=b[11], sx=b[12], sy=b[13],
                drawn=b[14], idx=b[22])


def unit(c, i):
    return rec(c, UNIT_TAB + i * U_SIZE)


def units(c):
    return [unit(c, i) for i in range(UNITS)]


def sprite_of(u):
    if u['addr'] == CURSOR_REC:
        return CURSOR
    if u['addr'] == ANCHOR_REC:
        return ANCHOR
    anim = (u['step'] >> 1) & 3
    s = SPRITES[u['set']]
    face = FACES[u['face']]
    if face == 'W':
        return gfx.mirror(s[4 + anim])
    return s[{'S': 0, 'E': 4, 'N': 8}[face] + anim]


def order(c, sym):
    n = c.peek(sym['ORD_TOT'])
    o = c.read_ram(ORDER, 2 * n)
    return [rec(c, o[k] | o[k + 1] << 8) for k in range(0, 2 * n, 2)]


def stamp(img, spr, x, y):
    for j in range(16):
        for i in range(8):
            p = spr[j][i]
            if p is not None:
                img[y + j][x * 2 + i] = p


def expected(c, sym, ref):
    img = [list(r) for r in ref]
    for u in order(c, sym):
        stamp(img, sprite_of(u), u['sx'], u['sy'])
        if u['fl'] & F_SEL:
            stamp(img, MARK, u['sx'], u['sy'])
    return img
