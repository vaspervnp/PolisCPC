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
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import scene as S                               # noqa: E402

U_TEAM, U_BKT, U_FIELD, U_JOB = 28, 26, 24, 27
NT = 0x6780
TEAM_FREE = 255
ARROWS, PR_N = 0xA5E0, 4                        # τα βέλη (game/bank7.asm)
PLAYER = (1, 2, 4, 5, 7, 8)
NEUTRAL = (0, 3, 6, 9, 10, 11)
# ελεύθερες θέσεις με το σωστό σετ (i mod 3: 1 σπαθοφόρος, 2 τοξότης)
ENEMY = (116, 118, 119, 121, 122, 124)
LIMIT = 3000                                    # καρέ (25 Hz): 2 λεπτά


def put16(c, a, v):
    c.poke(a, v & 255)
    c.poke(a + 1, (v >> 8) & 255)


def rec(c, k):
    return c.read_ram(S.UNIT_TAB + k * S.U_SIZE, S.U_SIZE)


def setup(c, sym):
    M3.wait_uphase(c, sym, 4)
    for k in NEUTRAL:
        c.poke(NT + k, 1)
        if k in (10, 11):                       # στρατιώτες: να μη μαχηθούν
            a = S.UNIT_TAB + k * S.U_SIZE
            c.poke(a + 11, c.peek(a + 11) | S.F_WANDER)
    for n, k in enumerate(ENEMY):
        a = S.UNIT_TAB + k * S.U_SIZE
        x, y = 172 + (n % 2) * 8, 334 + (n // 2) * 26
        put16(c, a + 0, x)
        put16(c, a + 2, y)
        put16(c, a + 4, x - 6)                  # ένα βήμα δυτικά: κάδος
        put16(c, a + 6, y)
        c.poke(a + U_TEAM, 1)
        c.poke(a + U_FIELD, 0)
        c.poke(a + U_JOB, 0)
        c.poke(a + 10, 3)                       # όψη W
        c.poke(a + 11, (c.peek(a + 11) & 0x80) | S.F_MOVE)
        c.poke(NT + k, 0)
        c.poke(S.ACT_TAB + k, 1)


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)
    sets = {k: rec(c, k)[8] for k in PLAYER + ENEMY}
    setup(c, sym)
    pop0 = M6.hud_vals(c, sym)[4]

    attacks = {0: set(), 1: set()}
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
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
