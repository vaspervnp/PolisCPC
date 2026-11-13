"""M8: μάχη — σε headless CPC 6128.

    python3 tests/m8_check.py [--shots]

6 ΕΝΑΝΤΙΟΝ 6. Οι 6 στρατιώτες της πόλης (μονάδες 1, 2, 4, 5, 7, 8: σπαθοφόροι
και τοξότες, ακίνητοι, χωρίς εντολή) και 6 εχθροί (ομάδα 1) που μπαίνουν σε
ελεύθερες θέσεις, ανατολικά της πόλης, περπατώντας προς τα δυτικά. Οι άλλες
6 της πόλης (οι χωρικοί, και οι 10, 11 που περιπλανιούνται) είναι ουδέτερες
(ο πίνακας NT του M8), για να είναι καθαρά 6 εναντίον 6.

1. ΑΥΤΟΜΑΤΗ ΕΠΙΘΕΣΗ. Χωρίς καμία εντολή, και οι δύο πλευρές χτυπάνε (πόζες
   επίθεσης), και οι τοξότες ρίχνουν βέλη.
   Τα βέλη δεν είναι μονάδες: λίστα 4 θέσεων, με XOR πάνω από όλα.
2. ΘΑΝΑΤΟΣ. Όποια πέφτει δείχνει τα καρέ θανάτου, βγαίνει από τον κάδο της,
   και μετά από λίγο η θέση της είναι ελεύθερη (ομάδα 255). Ο πληθυσμός της
   μπάρας πέφτει όσο οι νεκροί του παίκτη.
3. ΝΙΚΗΤΗΣ ΧΩΡΙΣ ΚΟΛΛΗΜΑ. Η μία πλευρά μένει χωρίς ζωντανούς μέσα σε
   ~2 λεπτά παιχνιδιού, και οι νικητές μετά στέκονται (καμία δεν περπατάει
   επ' αόριστον).
4. ΣΥΝΘΕΣΗ. Σε ένα καρέ στη μέση της μάχης, με πόζες και βέλη στην οθόνη, η
   οθόνη είναι pixel προς pixel ο κόσμος με τα καρέ τους (tests/scene.py).
5. ΧΡΟΝΟΣ. Τυπώνεται ως μέτρηση (όπως το σενάριο του M3): στη συμπλοκή,
   δίπλα στο Κέντρο Πόλης, λίγα καρέ περνάνε τα 40 ms.
6. ΧΡΩΜΑ ΟΜΑΔΑΣ. Οι εχθροί είναι κόκκινοι (gfx.TEAMS[1]): η σύνθεση του
   scene.py τους βάφει, και στην οθόνη υπάρχουν τα κόκκινα pens μέσα στα
   ορθογώνιά τους και κανένα μπλε της ομάδας.
7. ΟΨΗ W. Όποια χτύπησε κοιτώντας δυτικά έδειξε το καρέ W της επίθεσης
   (το καρέ 12 του σετ, το 15 καθρεφτισμένο), όχι καρέ βαδίσματος.

Και μετά, σε νέο παιχνίδι:
8. ΕΝΤΟΛΗ ΕΠΙΘΕΣΗΣ. Δύο στρατιώτες της πόλης επιλέγονται (κλικ), και RETURN
   πάνω σε έναν εχθρό ΠΕΡΑ από το οπτικό τους πεδίο: πάνε και τον ρίχνουν.
   Κλικ σε εχθρό δεν τον επιλέγει.
9. Ο ΧΩΡΙΚΟΣ ΑΠΑΝΤΑΕΙ. Ένας εχθρός σπαθοφόρος χτυπάει χωρικό της πόλης (το
   μόνο του στόχο): ο χωρικός αφήνει ό,τι έκανε και χτυπάει κι αυτός.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import scene as S                               # noqa: E402
import gfx                                      # noqa: E402
from cpc import KEY_RETURN                      # noqa: E402

U_TEAM, U_BKT, U_FIELD, U_JOB = 28, 26, 24, 27
NT = 0x6780
TEAM_FREE = 255
ARROWS, PR_N = 0xA5E0, 4                        # τα βέλη (game/bank7.asm)
PLAYER = (1, 2, 4, 5, 7, 8)
NEUTRAL = (0, 3, 6, 9, 10, 11)
# ελεύθερες θέσεις με το σωστό σετ (i mod 3: 1 σπαθοφόρος, 2 τοξότης)
ENEMY = (116, 118, 119, 121, 122, 124)
DEBUG = '--debug' in sys.argv
LIMIT = 3000                                    # καρέ (25 Hz): 2 λεπτά
ATK_W = 12                                      # game/bank7.asm
RED = {S.RED_HI, S.RED_LO}
BLUE = {gfx.TEAM_HI, gfx.TEAM_LO}


def put16(c, a, v):
    c.poke(a, v & 255)
    c.poke(a + 1, (v >> 8) & 255)


def rec(c, k):
    return c.read_ram(S.UNIT_TAB + k * S.U_SIZE, S.U_SIZE)


def place(c, k, x, y, tx):
    """Η μονάδα k στο (x, y) του κόσμου, με ένα βήμα ως το tx (ώστε να μπει
    στον κάδο της θέσης της: find_nearest)."""
    a = S.UNIT_TAB + k * S.U_SIZE
    put16(c, a + 0, x)
    put16(c, a + 2, y)
    put16(c, a + 4, tx)
    put16(c, a + 6, y)
    c.poke(a + U_FIELD, 0)
    c.poke(a + 11, (c.peek(a + 11) & 0x80) | S.F_MOVE |
           (c.peek(a + 11) & S.F_WANDER))
    c.poke(S.ACT_TAB + k, 1)


def enemy(c, k, x, y, face=3):
    """Μια ελεύθερη θέση γίνεται εχθρός (ομάδα 1) στο (x, y) του κόσμου,
    με ένα βήμα δυτικά."""
    a = S.UNIT_TAB + k * S.U_SIZE
    place(c, k, x, y, x - 6)
    c.poke(a + U_TEAM, 1)
    c.poke(a + U_FIELD, 0)
    c.poke(a + U_JOB, 0)
    c.poke(a + 10, face)
    c.poke(a + 11, (c.peek(a + 11) & 0x80) | S.F_MOVE)
    c.poke(NT + k, 0)
    c.poke(S.ACT_TAB + k, 1)


def setup(c, sym):
    M3.wait_uphase(c, sym, 4)
    for k in NEUTRAL:
        c.poke(NT + k, 1)
        if k in (10, 11):                       # στρατιώτες: να μη μαχηθούν
            a = S.UNIT_TAB + k * S.U_SIZE
            c.poke(a + 11, c.peek(a + 11) | S.F_WANDER)
    for n, k in enumerate(ENEMY):
        enemy(c, k, 172 + (n % 2) * 8, 334 + (n // 2) * 26)


def screen_pens(g, u):
    """Τα pens της οθόνης μέσα στο ορθογώνιο της μονάδας u (8 x 16)."""
    scr = M4.M2.decode_scrolled(g.c, g.sym)
    return {scr[u['sy'] + j][2 * u['sx'] + i] for j in range(16)
            for i in range(8) if u['sy'] + j < len(scr)}


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)
    sets = {k: rec(c, k)[8] for k in PLAYER + ENEMY}
    setup(c, sym)
    pop0 = M6.hud_vals(c, sym)[4]

    attacks = {0: set(), 1: set()}
    west, west_bad = set(), set()
    red_ok = None
    arrows, die_frames, bucket_left = 0, {}, {}
    dead_at = {}
    composed = None
    end = None
    for f in range(LIMIT):
        g.tick(1)
        tabs = {k: rec(c, k) for k in range(128)}
        ab = c.read_ram(ARROWS, PR_N * 8)
        if any(ab[k + 4] != 255 for k in range(0, PR_N * 8, 8)):
            arrows += 1
        for k in PLAYER + ENEMY:
            t = tabs[k]
            team, face, step = t[U_TEAM], t[10], t[9]
            if team in (0, 1) and face & 0x80:
                attacks[team].add(k)
                if face & 3 == 3:
                    (west if step == ATK_W else west_bad).add(k)
            if team & 0x80 and team != TEAM_FREE:
                die_frames.setdefault(k, set()).add(step)
                bucket_left.setdefault(k, t[U_BKT] == 255)
                dead_at.setdefault(k, f)
        alive = [[k for k in side if tabs[k][U_TEAM] == s]
                 for s, side in ((0, PLAYER), (1, ENEMY))]
        # μια σύνθεση στη μέση: πόζα ΚΑΙ βέλος στην οθόνη
        if composed is None and S.arrows(c) and any(
                u['sy'] != 255 and (u['face'] & 0x80)
                for u in S.units(c) if u['idx'] in PLAYER + ENEMY):
            composed = (f, g.compose('battle'))
            red_ok = colours(g)
        if not alive[0] or not alive[1]:
            end = (f, alive)
            break

    g.report('επίθεση', attacks[0] and attacks[1] and arrows,
             'χωρίς εντολές: χτύπησαν %d του παίκτη και %d εχθροί· βέλη στον '
             'αέρα σε %d καρέ' % (len(attacks[0]), len(attacks[1]), arrows))
    g.report('νικητής', end is not None,
             'σε %s καρέ: %s' % (end and end[0] + 1, 'καμία πλευρά δεν '
                                 'έπεσε' if end is None else
                                 'νίκησε ο %s με %d ζωντανούς'
                                 % ('παίκτης' if end[1][0] else 'εχθρός',
                                    len(end[1][0] or end[1][1]))))
    if composed:
        g.report('σύνθεση', composed[1], 'καρέ %d της μάχης: πόζες και βέλη '
                 'όπως στο scene.py' % composed[0])
    else:
        g.report('σύνθεση', False, 'καμία πόζα στην οθόνη')

    g.report('χρώμα', red_ok and red_ok[0], 'οι εχθροί κόκκινοι στην οθόνη: '
             '%s' % (red_ok and red_ok[1]))
    g.report('όψη W', west and not west_bad, 'χτύπησαν δυτικά με το καρέ W '
             'της επίθεσης: %s%s' % (sorted(west), '' if not west_bad else
                                     '· ΜΕ ΑΛΛΟ ΚΑΡΕ: %s' % sorted(west_bad)))
    g.tick(150)                                 # τα πτώματα φεύγουν
    tabs = {k: rec(c, k) for k in range(128)}
    dead = sorted(dead_at)
    freed = all(tabs[k][U_TEAM] == TEAM_FREE for k in dead)
    shown = [k for k in dead if die_frames[k] & {18, 19, 20}]
    pdead = [k for k in dead if k in PLAYER]
    pop1 = M6.hud_vals(c, sym)[4]
    g.report('θάνατος', dead and freed and all(bucket_left.values()) and
             pop1 == pop0 - len(pdead) and shown,
             'έπεσαν %s (καρέ θανάτου σε %d)· έξω από τους κάδους, οι θέσεις '
             'ελεύθερες· πληθυσμός %d -> %d'
             % (dead, len(shown), pop0, pop1))
    walking = [k for k in PLAYER + ENEMY if tabs[k][U_TEAM] in (0, 1) and
               tabs[k][11] & S.F_MOVE]
    g.report('στάση', not walking, 'μετά τη μάχη, κανείς νικητής δεν '
             'περπατάει%s' % ('' if not walking else ': %s' % walking))

    still = [t for t, m in zip(g.times, g.scrolled) if not m]
    over = [t for t in still if t >= 40]
    print('%-8s %-9s καρέ χωρίς κύλιση: μέσος %.1f ms, μέγιστος %.1f ms, %d από '
          'τα %d πάνω από 40 (μέτρηση: 20 μονάδες στην οθόνη, ως 11 '
          'ζωγραφίζονται στο ίδιο καρέ)'
          % ('χρόνος', '<40' if not over else 'ΠΑΝΩ', sum(still) / len(still),
             max(still), len(over), len(still)))
    if g.shots:
        c.screenshot(os.path.join(M4.M.BUILD, 'm8_after.png'), aspect=True)
    ok = g.ok
    ok &= orders('--shots' in sys.argv)
    print('\nM8: %s' % ('OK' if ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if ok else 1)


def only_orders():
    sys.exit(0 if orders(False) else 1)


def colours(g):
    """Οι ζωντανοί εχθροί που φαίνονται ολόκληροι, χωρίς άλλη μονάδα πάνω
    τους: κόκκινα pens της ομάδας, κανένα μπλε."""
    us = [u for u in S.units(g.c) if u['sy'] != 255 and u['team'] != 255]
    arr = S.arrows(g.c)
    seen = []
    for u in us:
        if u['team'] != 1 or u['sy'] > 128:
            continue
        if any(v is not u and abs(v['sx'] - u['sx']) < 4 and
               abs(v['sy'] - u['sy']) < 16 for v in us):
            continue
        if any(u['sx'] - 1 <= x < u['sx'] + 4 and u['sy'] - 2 < y < u['sy'] + 16
               for x, y in arr):              # βέλος (XOR) από πάνω
            continue
        pens = screen_pens(g, u)
        seen.append((u['idx'], bool(pens & RED) and not pens & BLUE))
    return (bool(seen) and all(ok for _, ok in seen),
            '%d ελεύθεροι εχθροί, %s' % (len(seen), seen))


def aim(g, u):
    """Ο κέρσορας μέσα στο ορθογώνιο της u (4 x 16), σε θέση που φτάνει: ο
    κέρσορας κινείται ανά 2 bytes και 6 γραμμές (m7_check.cmd_cursor)."""
    x0, y0 = g.cursor()
    x = next(x for x in range(u['sx'], u['sx'] + 4) if x % 2 == x0 % 2)
    y = next(y for y in range(u['sy'] + 2, u['sy'] + 16) if y % 6 == y0 % 6)
    g.move_cursor(x, y)


def click(g, u):
    """SPACE πάνω στη μονάδα u (κλικ)."""
    aim(g, u)
    g.c.key_down(' ')
    g.tick(2)
    g.c.key_up(' ')
    g.tick(2)


def orders(shots):
    g = M4.Game(shots)
    c, sym = g.c, g.sym
    g.tick(3)
    M3.wait_uphase(c, sym, 4)
    for k in range(12):                         # όλοι ουδέτεροι, εκτός από
        c.poke(NT + k, 1)                       # όσους δοκιμάζουμε
        a = S.UNIT_TAB + k * S.U_SIZE
        c.poke(a + 11, c.peek(a + 11) & ~S.F_WANDER & 0xFF)
    sol = next(k for k in PLAYER if rec(c, k)[8] == 1)
    for k in range(12):                         # οι άλλοι στρατιώτες: έξω
        if k != sol and rec(c, k)[8] in (1, 2):  # από τη μάχη
            a = S.UNIT_TAB + k * S.U_SIZE
            c.poke(a + 11, c.peek(a + 11) | S.F_WANDER)
    # ο σπαθοφόρος στην αριστερή άκρη της οθόνης, ο εχθρός (τοξότης) στη
    # δεξιά: 2 |dx| > 120, πέρα από το οπτικό πεδίο. Ένα βήμα ο καθένας
    # (κάδος), και μετά ακίνητοι.
    tgt = ENEMY[0]
    cx, cy = M4.M2.cam(c, sym)
    ey = cy + 60
    place(c, sol, cx + 2, ey, cx + 6)
    enemy(c, tgt, cx + 74, ey)
    g.tick(40)
    u = {v['idx']: v for v in S.units(c)}
    near0 = 2 * abs(u[sol]['wx'] - u[tgt]['wx']) + abs(u[sol]['wy'] -
                                                       u[tgt]['wy'])
    attacked = rec(c, tgt)[U_TEAM] == 1 and not any(
        rec(c, k)[10] & 0x80 for k in list(range(12)) + [tgt])
    soldiers = [sol]
    click(g, u[soldiers[0]])
    sel0 = [v['idx'] for v in S.units(c) if v['fl'] & S.F_SEL]
    click(g, u[tgt])                            # κλικ σε εχθρό: τίποτα
    sel1 = [v['idx'] for v in S.units(c) if v['fl'] & S.F_SEL]
    click(g, u[soldiers[0]])
    aim(g, S.unit(c, tgt))
    g.c.key_down(KEY_RETURN)
    g.tick(1)
    g.c.key_up(KEY_RETURN)
    alive = rec(c, tgt)[U_TEAM] == 1             # ως το RETURN
    dead = None
    if DEBUG:
        print('πριν το RETURN: εχθρός', rec(c, tgt)[28], 'πόσα καρέ', len(g.times))
        for k in (sol, tgt):
            t = rec(c, k)
            print('μετά το RETURN', k, 'team', t[28], 'fl', t[11], 'tgt', t[30],
                  'set', t[8], 'pos', t[0] | t[1] << 8, t[2] | t[3] << 8)
    for f in range(1500):
        g.tick(1)
        if DEBUG and f % 25 == 0:
            t = rec(c, sol)
            print('  ', f, 'στρατιώτης', t[0] | t[1] << 8, t[2] | t[3] << 8,
                  'tx', t[4] | t[5] << 8, t[6] | t[7] << 8, 'fl', t[11],
                  'field', t[24], 'face', t[10], 'tgt', t[30], 'team', t[28],
                  'attackers', [k for k in range(128) if rec(c, k)[30] == sol
                                and rec(c, k)[28] in (0, 1)])
        if rec(c, tgt)[U_TEAM] != 1:
            dead = f
            break
    g.report('εντολή', attacked and alive and near0 > 120 and
             sel0 == [soldiers[0]] and sel1 == [] and dead,
             'ο εχθρός στα %d (πέρα από το οπτικό πεδίο 120: κανείς δεν '
             'χτύπησε)· κλικ σε εχθρό: επιλογή %s· RETURN πάνω του με τον %d: '
             'έπεσε σε %s καρέ' % (near0, sel1, soldiers[0], dead))

    # ο χωρικός 0 και ένας εχθρός σπαθοφόρος δίπλα του
    v = S.unit(c, 0)
    c.poke(NT + 0, 0)
    foe = ENEMY[2]
    enemy(c, foe, v['wx'] + 12, v['wy'])        # ένα βήμα, ως +6
    hit_back = False
    for f in range(800):
        g.tick(1)
        t = rec(c, 0)
        if DEBUG and f % 10 == 0:
            e = rec(c, foe)
            print(f, 'v', t[0] | t[1] << 8, t[2] | t[3] << 8, 'team', t[28],
                  'face', t[10], 'step', t[9], 'fl', t[11], 'job', t[27],
                  'sy', t[13], '| foe', e[0] | e[1] << 8, e[2] | e[3] << 8,
                  e[28], e[10], e[9], 'tgt', e[30], 'set', e[8],
                  'arrows', S.arrows(c), c.read_ram(ARROWS, 32).hex())
        if t[U_TEAM] == 0 and t[10] & 0x80:
            hit_back = True
            break
        if t[U_TEAM] != 0:
            break
    g.report('απάντηση', hit_back, 'ο εχθρός %d χτυπάει τον χωρικό 0: %s'
             % (foe, 'χτύπησε κι αυτός (πόζα επίθεσης) σε %d καρέ' % f
                if hit_back else 'δεν απάντησε'))
    return g.ok


if __name__ == '__main__':
    only_orders() if '--orders' in sys.argv else main()
