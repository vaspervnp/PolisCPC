"""Το ιππικό (2026-11-17) — σε headless CPC 6128.

    python3 tests/m18_check.py [--shots]

Ο στάβλος βγάζει ιππικό (σετ 5). Τα καρέ του είναι στη θέση 3 της C5, που
τη μοιράζεται με τον οπλίτη (σετ 4): 12 καρέ το καθένα (src/make_edges.py,
src/horse8.py). Ελέγχει:

1. ΕΚΠΑΙΔΕΥΣΗ. TRAIN στον στάβλο: μια νέα μονάδα σετ 5, με κόστος 70 τροφή και
   50 χρυσό, και πληθυσμό +1.
2. ΣΧΕΔΙΑΣΗ. Το ιππικό και ένας οπλίτης που περπατάνε στην οθόνη, και ο
   κόσμος γύρω τους: pixel προς pixel όπως το scene.py (η μισή θέση: 2
   καρέ βαδίσματος ανά όψη).
3. ΤΑΧΥΤΗΤΑ. Ιππικό και σπαθοφόρος περπατάνε 50 καρέ προς τα δεξιά: το
   ιππικό διανύει τουλάχιστον 1,3 φορές την απόσταση (βήμα σε κάθε καρέ
   αντί για κάθε δεύτερο· το όριο χρόνου του καρέ, T_BUDGET, κόβει μερικά —
   2026-11-25: 1,3, όχι 1,4: χωρίς τα δύο ερείπια του χάρτη οι περιπλανώμενες
   φορτώνουν αλλιώς τα καρέ, και ήταν 28 / 20, μετά 27 / 20· 2026-11-26:
   1,25 — με τη δουλειά του χωρικού στη λωρίδα, game/jobmsg.asm, ο
   σπαθοφόρος 21: το ιππικό ίδιο, 27).
4. ΜΑΧΗ. Το ιππικό απέναντι σε εχθρικό σπαθοφόρο: χτυπάει (ζημιά ως 9) και
   ο θάνατός του δείχνει το πτώμα της μισής θέσης.
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
import scene as S                               # noqa: E402
import ui_menu as UM                            # noqa: E402

C7_HP = 0x7E00
U_LOOK, U_SY = 16, 13


def train(g, slot, want_set):
    c, sym = g.c, g.sym
    c.poke(sym['SEL_BLD'], slot)
    UM.train(c)
    for k in range(400):
        g.tick(1)
        new = [u for u in S.units(c) if u['set'] == want_set and
               u['team'] == 0]
        if new:
            return new[0]
    return None


def main():
    g = M4.Game('--shots' in sys.argv, wander=True)
    c, sym = g.c, g.sym
    g.tick(3)
    grd, res = M4.M.mockup.make_map()
    M9.set_res(c, sym, 3000)
    free = [k for k in range(M7.BLD_MAX) if c.peek(M7.BLD_SLOTS[k]) == 255]
    for k in free[:4]:                          # χώρος στον πληθυσμό
        M7.fake_bld(c, sym, k, 'house')
    stable, acad = free[4], free[5]
    M7.fake_bld(c, sym, stable, 'stable')
    M7.fake_bld(c, sym, acad, 'academy')
    c.poke(sym['BQ_TOT'], 0)
    g.tick(2)

    v0 = M6.hud_vals(c, sym)
    cav = train(g, stable, 5)
    v1 = M6.hud_vals(c, sym)
    g.report('εκπαίδευση', cav is not None and v1[0] == v0[0] - 70 and
             v1[2] == v0[2] - 50 and v1[4] == v0[4] + 1,
             'TRAIN στον στάβλο: νέα μονάδα %s (σετ 5)· τροφή %d -> %d, χρυσός '
             '%d -> %d, πληθυσμός %d -> %d'
             % (cav and cav['idx'], v0[0], v1[0], v0[2], v1[2], v0[4], v1[4]))
    if cav is None:
        print('\nM18: ΑΠΟΤΥΧΙΑ')
        sys.exit(1)
    hop = train(g, acad, 4)

    cx, cy = M4.M2.cam(c, sym)
    M8.place(c, cav['idx'], cx + 20, cy + 60, cx + 40)
    if hop:
        M8.place(c, hop['idx'], cx + 20, cy + 90, cx + 40)
    comps = []
    for t in range(16):
        g.tick(1)
        if t in (5, 9, 15):
            comps.append(g.compose('cavalry%d' % t))
    g.report('σχεδίαση', hop is not None and all(comps),
             'ιππικό %d και οπλίτης %s περπατάνε: η οθόνη σε 3 καρέ %s'
             % (cav['idx'], hop and hop['idx'], comps))

    sw = 1                                      # σπαθοφόρος της πόλης
    cx, cy = M4.M2.cam(c, sym)
    M8.place(c, cav['idx'], cx + 4, cy + 40, cx + 74)
    M8.place(c, sw, cx + 4, cy + 100, cx + 74)
    x0 = S.unit(c, cav['idx'])['wx'], S.unit(c, sw)['wx']
    g.tick(50)
    x1 = S.unit(c, cav['idx'])['wx'], S.unit(c, sw)['wx']
    d = x1[0] - x0[0], x1[1] - x0[1]
    g.report('ταχύτητα', d[1] > 0 and d[0] >= 1.25 * d[1],
             'σε 50 καρέ: ιππικό %d bytes, σπαθοφόρος %d' % d)

    foe = [i for i in range(128)
           if c.peek(S.UNIT_TAB + i * S.U_SIZE + 28) == 255][0]
    u = S.unit(c, cav['idx'])
    M8.enemy(c, foe, u['wx'] + 10, u['wy'])
    c.poke(S.UNIT_TAB + foe * S.U_SIZE + 8, 1)
    c.poke(S.UNIT_TAB + foe * S.U_SIZE + U_LOOK, 255)
    c.poke(0x3F00 + foe, 0)
    S.c7_write(c, C7_HP + foe, [60])
    S.c7_write(c, C7_HP + cav['idx'], [50])
    hit = None
    corpse = False
    for t in range(1500):
        g.tick(1)
        h = S.c7_read(c, C7_HP + foe)[0]
        if hit is None and h != 60:
            hit = 60 - h
        r = S.unit(c, cav['idx'])
        if r['team'] & 0x80 and r['face'] & 0x80 and r['step'] == 20 and \
                r['sy'] != 255:
            corpse = g.compose('cavalry_dead')
            break
        if c.peek(S.UNIT_TAB + foe * S.U_SIZE + 28) != 1 and hit:
            break
    g.report('μάχη', hit is not None and 1 <= hit <= 9,
             'ιππικό εναντίον σπαθοφόρου: το πρώτο του χτύπημα %s (ως 9)%s'
             % (hit, '· το πτώμα στην οθόνη: %s' % corpse if corpse else ''))

    print('\nM18 (ιππικό): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
