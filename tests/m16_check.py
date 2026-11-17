"""Οι πύργοι που ρίχνουν (2026-11-17) — σε headless CPC 6128.

    python3 tests/m16_check.py

Ο έτοιμος πύργος (game/bank7.asm, tw_tick) ρίχνει βέλη στον κοντινότερο
εχθρό ως TW_R = 88 (2 |dx| + |dy|: 11 πλακίδια). Ελέγχει:

1. ΧΤΙΣΤΗΚΕ. Ένας χωρικός, W, RETURN: ο πύργος (με σιταποθήκη, το
   προαπαιτούμενο, και πέτρα) χτίζεται.
2. ΚΕΝΤΡΟ. Το σημείο από το οποίο μετράει (tw_px, tw_py) είναι η μέση της
   κάτοψής του, στις συντεταγμένες μονάδας (U_WX, U_WY).
3. ΜΑΚΡΙΑ. Εχθρικός χωρικός 13 πλακίδια μακριά: κανένα βέλος, ζει ανέπαφος.
4. ΒΟΛΗ. Στα 8 πλακίδια: ένα βέλος του πύργου (τοξότης 128 + η θέση του)
   στο ARROWS, και μετά η υγεία του -5..12.
5. ΑΠΑΝΤΗΣΗ. Ο χωρικός που χτυπήθηκε έχει εντολή επίθεσης στον πύργο
   (C7_ORD = 128 + η θέση).
6. ΡΥΘΜΟΣ. Με υγεία 200, ως να πέσει: βολές κάθε TW_P + 4 καρέ περίπου
   (18-40)· ο χωρικός κρατιέται ακίνητος στα 8 πλακίδια.
7. ΟΧΙ ΔΙΚΟΥΣ. Οι δικοί μας χωρικοί δίπλα του: ούτε ένα χτύπημα.
8. ΤΟΥ ΑΝΤΙΠΑΛΟΥ. Ο ίδιος πύργος του αντιπάλου (B_OWN = 1): χτυπάει δικό
   μας χωρικό.
9. ΣΙΔΗΡΟΥ. Στην Εποχή του Σιδήρου, U στον πύργο (Βαλλιστική) και στην
   ακαδημία (Σιδερένια δόρατα, μετά τη Φάλαγγα): η ζημιά των πύργων του
   παίκτη 5 -> 9, του οπλίτη 10 -> 14.
10. ΒΑΛΛΙΣΤΙΚΗ. Οι βολές του πύργου μετά: ζημιά 9-16.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import m8_check as M8                           # noqa: E402
import m9_check as M9                           # noqa: E402
import make_bank6 as MB                         # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import scene as S                               # noqa: E402

C7_HP, C7_ORD = 0x7E00, 0x7F00
U_TEAM, U_LOOK, U_SY = 28, 16, 13
TOWER = (37, 61)                # το κέντρο της κάτοψης (i0 = 36, j0 = 60)
TW_R, TW_DMG = 88, 5


def at(i, j):
    """(U_WX, U_WY) μονάδας που στέκεται στο πλακίδιο (i, j)."""
    return 2 * (i - j) + 190, 4 * (i + j) - 10


def free_slot(c):
    return [k for k in range(S.UNITS)
            if c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM) == 255][0]


def put(c, k, i, j, team):
    """Ο χωρικός k ακίνητος στο (i, j), της ομάδας team."""
    x, y = at(i, j)
    a = S.UNIT_TAB + k * S.U_SIZE
    M8.enemy(c, k, x, y)
    M8.put16(c, a + 4, x)                       # κανένα βήμα
    c.poke(a + 11, c.peek(a + 11) & ~S.F_MOVE & 255)
    c.poke(a + 8, 0)
    c.poke(a + U_TEAM, team)
    c.poke(a + U_SY, 255)
    c.poke(a + U_LOOK, 255)
    c.poke(0x3F00 + k, 0)
    S.c7_write(c, C7_HP + k, [25])
    S.c7_write(c, C7_ORD + k, [255])


def hp(c, k):
    return S.c7_read(c, C7_HP + k)[0]


def tower_arrows(c, sym, slot):
    b = c.read_ram(S.ARROWS, 4 * 8)
    return [(b[k + 4], b[k + 5]) for k in range(0, 32, 8)
            if b[k + 4] != 255 and b[k + 5] == 128 + slot]


def main():
    g = M4.Game(False)
    c, sym = g.c, g.sym
    g.tick(3)
    for u in S.units(c):                        # οι στρατιώτες της πόλης: όχι
        if u['team'] == 0 and u['set'] in (1, 2):   # στη μάχη
            a = S.UNIT_TAB + u['idx'] * S.U_SIZE + 11
            c.poke(a, c.peek(a) | S.F_WANDER)
    free = [k for k in range(M7.BLD_MAX) if c.peek(M7.BLD_SLOTS[k]) == 255]
    M7.fake_bld(c, sym, free[0], 'granary')     # το προαπαιτούμενο
    c.poke(sym['HUD_VAL'] + 6, 300 & 255)       # πέτρα
    c.poke(sym['HUD_VAL'] + 7, 300 >> 8)

    v = M6.VILLAGERS[0]
    M6.click_unit(g, v)
    M7.press(g, 'w')
    g.move_cursor(*M6.tile_cursor(g, *TOWER))
    M7.press(g, CPCMOD.KEY_RETURN, 1)
    tw = [b for b in M7.blds(c) if b['type'] == 'tower']
    for t in range(3000):
        g.tick(1)
        tw = [b for b in M7.blds(c) if b['type'] == 'tower']
        if tw and tw[0]['st'] == 1:
            break
    g.report('χτίστηκε', tw and tw[0]['st'] == 1,
             'W, RETURN: πύργος %s σε %d καρέ' % (tw, t + 1))
    if not (tw and tw[0]['st'] == 1):
        print('\nM16: ΑΠΟΤΥΧΙΑ')
        sys.exit(1)
    slot = tw[0]['slot']
    i0, j0 = tw[0]['i0'], tw[0]['j0']
    for k in M6.VILLAGERS:                      # οι χωρικοί μακριά (7.)
        put(c, k, i0 + 2, j0 - 3 - k // 3, 0)
    g.tick(40)
    px = c.read_ram(sym['TW_PX'], 2)           # (κύριος κώδικας)
    py = c.read_ram(sym['TW_PY'], 2)
    px, py = px[0] | px[1] << 8, py[0] | py[1] << 8
    cx, cy = 2 * (i0 - j0) + 190, 4 * (i0 + j0 + 1) - 10
    g.report('κέντρο', (px, py) == (cx, cy),
             'tw_px, tw_py = %d, %d· η μέση της κάτοψης %d, %d'
             % (px, py, cx, cy))

    ci, cj = i0 + 0.5, j0 + 0.5
    e = free_slot(c)
    put(c, e, int(ci + 13.5), int(cj + 0.5) - 0, 1)
    g.tick(100)
    g.report('μακριά', hp(c, e) == 25 and not tower_arrows(c, sym, slot),
             'εχθρός 13 πλακίδια μακριά: υγεία %d' % hp(c, e))

    put(c, e, i0 + 9, j0 + 1, 1)
    seen = None
    for t in range(80):
        g.tick(1)
        seen = seen or tower_arrows(c, sym, slot)
        if hp(c, e) != 25:
            break
    d = 25 - hp(c, e)
    g.report('βολή', seen and seen[0][0] == e and TW_DMG <= d <= TW_DMG + 7,
             'εχθρός 8 πλακίδια μακριά: βέλος %s, σε %d καρέ ζημιά %d'
             % (seen, t + 1, d))
    o = S.c7_read(c, C7_ORD + e)[0]
    g.report('απάντηση', o == 128 + slot,
             'ο χωρικός που χτυπήθηκε: εντολή %d (ο πύργος: %d)'
             % (o, 128 + slot))

    hits = [t]
    S.c7_write(c, C7_HP + e, [200])             # (για να μετρηθούν πολλές)
    last = hp(c, e)
    x, y = at(i0 + 9, j0 + 1)
    a = S.UNIT_TAB + e * S.U_SIZE
    for t2 in range(400):
        for o, w in ((0, x), (2, y), (4, x), (6, y)):   # ακίνητος εκεί
            M8.put16(c, a + o, w)
        c.poke(a + 11, c.peek(a + 11) & ~S.F_MOVE & 255)
        S.c7_write(c, C7_ORD + e, [255])
        g.tick(1)
        if c.peek(S.UNIT_TAB + e * S.U_SIZE + U_TEAM) != 1 or hp(c, e) == 0:
            break
        if hp(c, e) != last:
            hits.append(t + 1 + t2)
            last = hp(c, e)
    gaps = [b - a for a, b in zip(hits, hits[1:])]
    g.report('ρυθμός', len(gaps) >= 4 and all(18 <= x <= 40 for x in gaps),
             'χτυπήματα στα καρέ %s (διαστήματα %s)' % (hits, gaps))
    own = [hp(c, k) for k in M6.VILLAGERS]
    g.report('όχι δικούς', own == [25] * len(M6.VILLAGERS),
             'οι δικοί μας χωρικοί δίπλα του: υγεία %s' % own)

    c.poke(M7.BLD_SLOTS[slot] + 1, 1)           # του αντιπάλου
    p = M6.VILLAGERS[1]
    put(c, p, i0 + 7, j0 + 1, 0)
    for k in M6.VILLAGERS:                      # οι άλλοι πολύ μακριά
        if k != p:
            put(c, k, i0 + 20, j0 + 3 * (k // 3), 0)
    for t in range(120):
        g.tick(1)
        if hp(c, p) != 25:
            break
    g.report('αντιπάλου', hp(c, p) < 25 and all(
        hp(c, k) == 25 for k in M6.VILLAGERS if k != p),
             'πύργος του αντιπάλου, δικός μας χωρικός 6 πλακίδια: υγεία %d '
             'σε %d καρέ (οι άλλοι, μακριά: %s)'
             % (hp(c, p), t + 1, [hp(c, k) for k in M6.VILLAGERS if k != p]))

    # ---------------------------------- Εποχή του Σιδήρου: δύο τεχνολογίες
    c.poke(M7.BLD_SLOTS[slot] + 1, 0)           # ξανά του παίκτη
    c.poke(sym['HUD_VAL'] + 10, 4)              # Σιδήρου
    M9.set_res(c, sym, 3000)
    rd = S.c7_read(c, sym['RES_DONE'], 2)
    S.c7_write(c, sym['RES_DONE'], [rd[0], rd[1] | 0x10])   # η Φάλαγγα (12)
    acad = [k for k in range(M7.BLD_MAX) if c.peek(M7.BLD_SLOTS[k]) == 255][0]
    M7.fake_bld(c, sym, acad, 'academy')
    hit0 = S.c7_read(c, sym['TW_HIT'])[0]
    st0 = S.c7_read(c, sym['STATS'] + 17)[0]
    for b in (slot, acad):
        c.poke(sym['SEL_BLD'], b)
        M7.press(g, 'u')
    for t in range(1500):
        g.tick(1)
        if c.peek(sym['RES_N']) == 0:
            break
    hit1 = S.c7_read(c, sym['TW_HIT'])[0]
    st1 = S.c7_read(c, sym['STATS'] + 17)[0]
    rd = S.c7_read(c, sym['RES_DONE'], 2)
    g.report('σιδήρου', (hit0, hit1, st0, st1) == (TW_DMG, TW_DMG + 4, 10, 14)
             and rd[1] & 0xC0 == 0xC0,
             'U στον πύργο και στην ακαδημία: σε %d καρέ ζημιά πύργου %d -> '
             '%d, οπλίτη %d -> %d' % (t + 1, hit0, hit1, st0, st1))
    e2 = free_slot(c)
    put(c, e2, i0 + 7, j0 + 1, 1)
    S.c7_write(c, C7_HP + e2, [200])
    x, y = at(i0 + 7, j0 + 1)
    a = S.UNIT_TAB + e2 * S.U_SIZE
    ds = []
    for t in range(600):
        for o, w in ((0, x), (2, y), (4, x), (6, y)):
            M8.put16(c, a + o, w)
        c.poke(a + 11, c.peek(a + 11) & ~S.F_MOVE & 255)
        S.c7_write(c, C7_ORD + e2, [255])
        h = hp(c, e2)
        g.tick(1)
        if hp(c, e2) != h:
            ds.append(h - hp(c, e2))
        if len(ds) >= 8:
            break
    g.report('βαλλιστική', ds and all(TW_DMG + 4 <= d <= TW_DMG + 11
                                      for d in ds),
             'μετά τη Βαλλιστική: ζημιές %s (%d-%d)'
             % (ds, TW_DMG + 4, TW_DMG + 11))

    print('\nM16 (πύργοι): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
