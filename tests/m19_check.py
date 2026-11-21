"""Ποιος νικάει ποιον, και ο αντίπαλος με ιππικό και οπλίτες (2026-11-17) —
σε headless CPC 6128.

    python3 tests/m19_check.py [--shots]

Ο οπλίτης κάνει διπλή ζημιά στο ιππικό, το ιππικό στους τοξότες, οι τοξότες
στους οπλίτες (ctr_t, sq_dmg του game/bank7.asm). Ο αντίπαλος χτίζει μετά
τον στρατώνα, από τα AI_T2 s, έναν στάβλο, και μια ακαδημία όταν η εικόνα
της είναι στη μνήμη (ο παίκτης στην Εποχή του Χαλκού)· εκπαιδεύει και από
τα τρία. Ελέγχει:

1. ΖΗΜΙΑ. Ένας του παίκτη απέναντι σε έναν εχθρό, για τα τέσσερα ζεύγη:
   το μεγαλύτερο χτύπημα σε 12 χτυπήματα. Με διπλή ζημιά πάνω από τη
   ζημιά του σετ (η τυχαία 30-98% της πλήρους), ως τη διπλή· χωρίς (ο
   σπαθοφόρος στο ιππικό) ως τη ζημιά του σετ.
2. ΣΤΑΒΛΟΣ. Ο αντίπαλος (με άφθονους πόρους) χτίζει στάβλο μετά τα AI_T2
   s. Ξεκινά με 8 στρατιώτες, πάνω από το πρώτο κύμα (6), άρα εκπαιδεύει
   αφού αυτό φύγει: τότε βγάζει ιππικό.
3. ΑΚΑΔΗΜΙΑ. Ο παίκτης στην Εποχή του Χαλκού: ο αντίπαλος χτίζει
   ακαδημία, και βγάζει οπλίτες.
4. ΚΥΜΑ. Το δεύτερο κύμα του έχει και ιππικό ή οπλίτες.
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
import m10_check as M10                         # noqa: E402
import scene as S                               # noqa: E402
import ui_menu as UM                            # noqa: E402

C7_HP = 0x7E00
C7_ORD = 0x7F00
U_LOOK = 16
DMG = {1: 8, 2: 6, 4: 10, 5: 9}
PAIRS = [(4, 5, True), (5, 2, True), (2, 4, True), (1, 5, False)]


def free_slots(c, n):
    return [i for i in range(128)
            if c.peek(S.UNIT_TAB + i * S.U_SIZE + 28) == 255][:n]


def duel(g, a_set, t_set, row=0):
    """Ο a_set του παίκτη χτυπάει τον t_set του αντιπάλου: τα χτυπήματα. Κάθε
    ζεύγος σε δική του σειρά της οθόνης (row): όσοι φεύγουν (ομάδα 255)
    αφήνουν πιασμένη τη θέση τους."""
    c, sym = g.c, g.sym
    a, t = free_slots(c, 2)
    cx, cy = M4.M2.cam(c, sym)
    gap = 40 if a_set == 2 else 10
    for k, st in ((a, a_set), (t, t_set)):
        M8.enemy(c, k, cx + 30 + (gap if k == t else 0), cy + 30 + 26 * row)
        c.poke(S.UNIT_TAB + k * S.U_SIZE + 8, st)
        c.poke(S.UNIT_TAB + k * S.U_SIZE + U_LOOK, 255)
        c.poke(S.SQ_N + k, 0)
        S.c7_write(c, C7_HP + k, [200])
    c.poke(S.UNIT_TAB + a * S.U_SIZE + 28, 0)
    hits = []
    for _ in range(3000):
        g.tick(1)
        h = S.c7_read(c, C7_HP + t)[0]
        if h != 200:
            hits.append(200 - h)
            S.c7_write(c, C7_HP + t, [200])
        S.c7_write(c, C7_HP + a, [200])
        if len(hits) >= 12:
            break
    for k in (a, t):                            # να φύγουν
        c.poke(S.UNIT_TAB + k * S.U_SIZE + 28, 255)
    g.tick(2)
    return hits


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)
    for u in S.units(c):                        # οι άλλοι δεν μαχιούνται
        if u['team'] == 0:
            a = S.UNIT_TAB + u['idx'] * S.U_SIZE + 11
            c.poke(a, c.peek(a) | S.F_WANDER)
    names = {1: 'σπαθοφόρος', 2: 'τοξότης', 4: 'οπλίτης', 5: 'ιππικό'}
    for row, (a_set, t_set, dbl) in enumerate(PAIRS):
        hits = duel(g, a_set, t_set, row)
        top = max(hits) if hits else 0
        d = DMG[a_set]
        good = len(hits) >= 8 and (d < top <= 2 * d if dbl else top <= d)
        g.report('ζημιά', good,
                 '%s -> %s: %d χτυπήματα, το μεγαλύτερο %d (%s)'
                 % (names[a_set], names[t_set], len(hits), top,
                    'διπλή: %d-%d' % (d + 1, 2 * d) if dbl else 'ως %d' % d))

    # ------------------------------------------- ο αντίπαλος
    ok1 = g.ok
    g = M4.Game(False, ai=True)
    c, sym = g.c, g.sym
    ai_val = sym['AI_VAL']

    def rich():
        for k in range(8):
            c.poke(ai_val + k, (0xD0, 0x07)[k & 1])

    def kinds(team_set):
        return [u for u in M10.team1(c) if u['set'] == team_set]

    def has(t):
        return [b for b in M7.blds(c, 1) if b['type'] == t]

    lv = sym['LV_SEC']

    def second(n=1, cool=True):
        for _ in range(n):
            rich()
            if cool:                            # το κύμα όταν το θέλουμε
                S.c7_write(c, sym['AI_COOL'], [0xE7, 0x03])
            g.tick(25)                          # (g.tick: και η δισκέτα)

    def waving():
        return [u for u in M10.team1(c)
                if S.c7_read(c, C7_ORD + u['idx'])[0] != 255 and
                u['set'] in (1, 2, 4, 5)]

    c.insert_disc(os.path.join(M4.M.BUILD, 'polis.dsk'))   # (το AGE3.BIN)
    M9.set_res(c, sym, 3000)                    # ο παίκτης στον Χαλκό
    tc = [b['slot'] for b in M7.blds(c) if b['type'] == 'town_center'][0]
    c.poke(sym['SEL_BLD'], tc)
    UM.research(c)
    for s in range(200):
        second()
        if M6.hud_vals(c, sym)[5] == 3:
            break
    age = M6.hud_vals(c, sym)[5]

    built = {}
    for s in range(400):
        sec = S.c7_read(c, lv, 2)
        if has('barracks') and sec[0] | sec[1] << 8 < 240:
            S.c7_write(c, lv, [240, 0])         # γρήγορα ως τα AI_T2 s
            S.c7_write(c, sym['AI_FT'], [240, 0])
        second()
        for t in ('stable', 'academy'):
            if t not in built and [b for b in has(t) if b['st']]:
                built[t] = s
        if len(built) == 2:
            break

    S.c7_write(c, sym['AI_COOL'], [0, 0])       # το πρώτο κύμα: από τους
    for s in range(120):                        # αρχικούς της πίστας
        second(cool=False)
        if waving():
            break
    first = sorted(u['set'] for u in waving())
    for u in waving():                          # (φεύγουν από τον αγώνα)
        c.poke(S.UNIT_TAB + u['idx'] * S.U_SIZE + 28, 255)
    cav = hop = None
    for s in range(400):
        second()
        if cav is None and kinds(5):
            cav = s
        if hop is None and kinds(4):
            hop = s
        if cav is not None and hop is not None:
            break
    g.report('στάβλος', 'stable' in built and cav is not None,
             'ο στάβλος του έτοιμος σε %s s· μετά το πρώτο κύμα (σετ %s), '
             'το πρώτο ιππικό σε %s s' % (built.get('stable'), first, cav))
    g.report('ακαδημία', age == 3 and 'academy' in built and hop is not None,
             'ο παίκτης στη Χαλκού (εποχή %d): η ακαδημία του έτοιμη σε %s s, '
             'ο πρώτος οπλίτης σε %s s' % (age, built.get('academy'), hop))

    S.c7_write(c, sym['AI_COOL'], [0, 0])
    for s in range(240):
        second(cool=False)
        if len(waving()) >= 3:
            break
    wave = sorted(u['set'] for u in waving())
    g.report('κύμα', any(k in (4, 5) for k in wave),
             'τα σετ του δεύτερου κύματος: %s' % wave)

    ok = ok1 and g.ok
    print('\nM19 (ποιος νικάει ποιον, ο αντίπαλος με ιππικό): %s'
          % ('OK' if ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
