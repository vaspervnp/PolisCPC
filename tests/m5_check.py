"""M5: εύρεση δρόμου και κάδοι γειτονιάς — σε headless CPC 6128.

    python3 tests/m5_check.py [--shots]

1. ΓΥΡΩ ΑΠΟ ΤΟ ΔΑΣΟΣ. Μια μονάδα της πόλης επιλέγεται με κλικ, η κάμερα
   κατεβαίνει με τα βελάκια, και η εντολή (RETURN) τη στέλνει πέρα από τη
   λωρίδα δάσους νοτιοδυτικά της πόλης. Ο ευθύς δρόμος περνάει από εμπόδια
   (ελέγχεται εδώ, στον χάρτη της Python). Η μονάδα πρέπει να ΦΤΑΣΕΙ
   ακριβώς στον στόχο, χωρίς να πατήσει ποτέ σε εμπόδιο (ελέγχεται σε κάθε
   καρέ, με τον κανόνα του src/make_map.py).
2. FLOW FIELD. Το BFS του χονδρού πλέγματος μετριέται (δείγματα του PC μέσα
   στο field_*): ο χρόνος του αθροιστικά < 40 ms, ένα καρέ των 25 Hz — και
   μοιράζεται σε καρέ ώστε κανένα καρέ να μη ξεπεράσει τα 40 ms.
   Ο χρόνος: κάθε καρέ ΧΩΡΙΣ κύλιση < 40 ms. Τα καρέ κύλισης τυπώνονται
   ως μέτρηση (το όριο της κύλισης με μονάδες είναι του M2).
3. ΣΤΟΧΕΥΣΗ. Με 128 μονάδες, το find_nearest για όλες (bench_req): < 300 µs
   ανά μονάδα. Το αποτέλεσμα: για κάθε μονάδα, η απόσταση του εχθρού που
   βρήκε ο Z80 = η ελάχιστη που βρίσκει η Python στους ίδιους 9 κάδους.
4. ΚΑΔΟΙ. Κάθε μονάδα είναι ακριβώς μία φορά στις λίστες, στον κάδο της
   θέσης της.
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import profile as P                             # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import make_map as MM                           # noqa: E402

BKT = (0x4E90, 0x5690)          # οι κεφαλές των κάδων ανά ομάδα, 14 x 14
U_BKT, U_TEAM, U_TGT = 26, 28, 30
PN = 0x6700                     # η επόμενη στον κάδο, ανά δείκτη μονάδας


class Nav:
    def __init__(self):
        grd, res = M4.M.mockup.make_map()
        self.blob = MM.encode(grd, res)

    def blocked(self, i, j):
        if not (0 <= i < 96 and 0 <= j < 96):
            return True
        return bool(MM.blocked_byte(self.blob[j * 96 + i]))


def feet_tile(fx, fy):
    return (2 * fx + fy - 383) >> 3, (fy - 2 * fx + 383) >> 3


def unit_tile(u):
    return feet_tile(u['wx'] + 2, u['wy'] + 14)


def bucket_of(u):
    i, j = unit_tile(u)
    i, j = min(max(i, 0), 95), min(max(j, 0), 95)
    return 15 + 14 * (j >> 3) + (i >> 3)


def line_blocked(nav, a, b):
    """Ο ευθύς δρόμος (τα πόδια, σε 64 σημεία) περνάει από εμπόδιο;"""
    (x0, y0), (x1, y1) = a, b
    for k in range(65):
        fx = x0 + (x1 - x0) * k // 64 + 2
        fy = y0 + (y1 - y0) * k // 64 + 14
        if nav.blocked(*feet_tile(fx, fy)):
            return True
    return False


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    nav = Nav()

    # ------------------------------------------------- 4. κάδοι (αρχή)
    def check_buckets(when):
        seen = collections.Counter()
        bad = []
        for team in (0, 1):
            heads = c.read_ram(BKT[team], 196)
            for b in range(196):
                k, n = heads[b], 0
                while k != 255 and n < 200:
                    seen[k] += 1
                    u = S.unit(c, k)
                    t = c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM)
                    if bucket_of(u) != b or t != team:
                        bad.append((k, b, bucket_of(u), t))
                    k = c.peek(PN + k)
                    n += 1
        good = not bad and all(seen[k] == 1 for k in range(S.UNITS))
        g.report('κάδοι', good, '%s: %d μονάδες, η καθεμία μία φορά, στον '
                 'κάδο της θέσης της%s' % (when, len(seen),
                                           '' if not bad else ' %s' % bad[:3]))
    check_buckets('αρχή')

    # ------------------------------------------------- 1. γύρω από το δάσος
    u7 = S.unit(c, 7)                   # SX 56, SY 59
    g.move_cursor(58, 64)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(2)
    sel = {u['idx'] for u in S.units(c) if u['fl'] & S.F_SEL}
    g.report('κλικ', sel == {7}, 'επιλεγμένη %s' % sorted(sel))
    c.key_down(CPCMOD.KEY_DOWN)         # η κάμερα 10 σειρές κάτω
    for _ in range(40):
        g.tick(1)
        if M4.M2.cam(c, sym)[1] >= 383:
            break
    c.key_up(CPCMOD.KEY_DOWN)
    g.tick(2)
    g.move_cursor(4, 118)
    cam = M4.M2.cam(c, sym)
    labels = sorted((a, n) for n, a in sym.items() if a < 0x4000)
    hits = collections.Counter()
    c.key_down(CPCMOD.KEY_RETURN)
    while c.peek(sym['NPHASE']) != 1:
        c.run_us(20)
    P.sample(c, sym, labels, hits, lambda: c.peek(sym['NPHASE']) == 2)
    c.key_up(CPCMOD.KEY_RETURN)
    bfs = sum(v for k, v in hits.items() if k.startswith('FIELD_')) \
        * P.STEP / 1000.0
    g.report('BFS', bfs < 40, 'flow field: %.1f ms αθροιστικά (ένα καρέ: 40)'
             % bfs)
    g.tick(1)
    u = S.unit(c, 7)
    start, target = (u['wx'], u['wy']), (u['tx'], u['ty'])
    ti = feet_tile(target[0] + 2, target[1] + 14)
    g.report('στόχος', not nav.blocked(*ti) and line_blocked(nav, start,
                                                             target),
             'από %s σε %s (κάμερα %s): ελεύθερος, ο ευθύς δρόμος κόβεται '
             'από εμπόδια' % (start, target, cam))
    trail, on_block = [start], []
    for k in range(900):
        g.tick(1)
        u = S.unit(c, 7)
        p = (u['wx'], u['wy'])
        if p != trail[-1]:
            trail.append(p)
            if nav.blocked(*unit_tile(u)):
                on_block.append(p)
        if not u['fl'] & S.F_MOVE:
            break
    arrived = trail[-1] == target and not u['fl'] & S.F_MOVE
    g.report('έφτασε', arrived, 'σε %d καρέ, %d βήματα, τελευταία θέση %s'
             % (k + 1, len(trail) - 1, trail[-1]))
    g.report('εμπόδια', not on_block, 'δεν πάτησε ποτέ σε εμπόδιο%s'
             % ('' if not on_block else ': %s' % on_block[:3]))
    check_buckets('μετά')

    # ------------------------------------------------- 3. στόχευση
    M3.wait_uphase(c, sym, 4)
    c.poke(sym['BENCH_REQ'], 1)
    while c.peek(sym['BPHASE']) != 1:
        c.run_us(10)
    t = 0
    while c.peek(sym['BPHASE']) != 2:
        c.run_us(10)
        t += 10
    per = t / 128.0
    g.report('στόχευση', per < 300, '%.0f µs ανά μονάδα (όριο 300), 128 '
             'μονάδες' % per)
    us = S.units(c)
    tab = [c.read_ram(S.UNIT_TAB + k * S.U_SIZE, S.U_SIZE) for k in range(128)]
    def dist8(u, v):
        """Η απόσταση όπως τη βγάζει ο Z80: low bytes, 8 bits, None αν > 255."""
        dx = (v['wx'] - u['wx']) & 255
        dx = 256 - dx if dx >= 128 else dx
        d = 2 * dx
        if d > 255:
            return None
        dy = (v['wy'] - u['wy']) & 255
        dy = 256 - dy if dy >= 128 else dy
        d += dy
        return d if d <= 255 else None

    wrong, found = [], 0
    for k, u in enumerate(us):
        b = bucket_of(u)
        best = None
        for v in us:
            if tab[v['idx']][U_TEAM] == tab[k][U_TEAM]:
                continue
            if bucket_of(v) - b in (-15, -14, -13, -1, 0, 1, 13, 14, 15):
                d = dist8(u, v)
                if d is not None and d < 255:
                    best = d if best is None else min(best, d)
        got = tab[k][U_TGT]
        if got == 255:
            ok = best is None
        else:
            ok = best == dist8(u, us[got])
            found += 1
        if not ok:
            wrong.append(k)
    g.report('εχθρός', not wrong, '%d βρήκαν εχθρό στους 9 κάδους, όλες στην '
             'ελάχιστη απόσταση%s' % (found, '' if not wrong
                                      else ' — λάθος: %s' % wrong[:5]))

    still = [t for t, m in zip(g.times, g.scrolled) if not m]
    moved = [t for t, m in zip(g.times, g.scrolled) if m]
    g.report('χρόνος', max(still) < 40, 'καρέ χωρίς κύλιση: μέσος %.1f ms, '
             'μέγιστος %.1f ms (όριο 40), %d καρέ'
             % (sum(still) / len(still), max(still), len(still)))
    print('χρόνος   %-9s καρέ με κύλιση (μέτρηση, βλ. M2): μέσος %.1f ms, '
          'μέγιστος %.1f ms, %d καρέ'
          % ('<40' if max(moved) < 40 else 'ΠΑΝΩ', sum(moved) / len(moved),
             max(moved), len(moved)))
    if g.shots:
        c.screenshot(os.path.join(M4.M.BUILD, 'm5_forest.png'), aspect=True)
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
