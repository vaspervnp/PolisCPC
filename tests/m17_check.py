"""Ο αντίπαλος περιμένει (2026-11-17) — σε headless CPC 6128.

    python3 tests/m17_check.py

Στον ελεύθερο αγώνα το πρώτο κύμα φεύγει μετά από 300 + v + v/8 + v/32 s
(5-10 λεπτά, game/init.asm· το v από το R και το int_t όταν τελειώνει το
μενού). Ως τότε ο αντίπαλος χτίζει και εκπαιδεύει κανονικά. Αν όμως τον
χτυπήσει ο παίκτης, δεν περιμένει άλλο (ai_prov, game/bank7.asm). Ελέγχει:

1. ΑΝΑΜΟΝΗ. Το ai_cool στην αρχή είναι 300-593 s.
2. ΗΣΥΧΙΑ. Για 240 s με αδρανή παίκτη: κανένα κύμα (ai_wave 6, καμία
   εντολή επίθεσης σε στρατιώτη του)· η πόλη του μεγαλώνει (χωρικοί και
   κτίρια) και ο στρατός του φτάνει για κύμα (6: τόσους εκπαιδεύει, M14).
3. ΠΡΟΚΛΗΣΗ. Ένας χωρικός του δίπλα στους στρατιώτες της πόλης: τον
   χτυπούν, και το ai_cool μηδενίζεται.
4. ΚΥΜΑ. Λίγο μετά φεύγει το πρώτο κύμα (ai_wave 8).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m7_check as M7                           # noqa: E402
import m8_check as M8                           # noqa: E402
import m10_check as M10                         # noqa: E402
import scene as S                               # noqa: E402

C7_ORD = 0x7F00


def cool(c, sym):
    b = S.c7_read(c, sym['AI_COOL'], 2)
    return b[0] | b[1] << 8


def people(c, sets):
    return sum(c.peek(S.SQ_N + u['idx']) + 1 for u in M10.team1(c)
               if u['set'] in sets)


def waving(c):
    orders = S.c7_read(c, C7_ORD, 128)
    return [u['idx'] for u in M10.team1(c)
            if u['set'] in (1, 2, 4) and orders[u['idx']] != 255]


def main():
    g = M4.Game(False, ai=True)
    c, sym = g.c, g.sym
    c0 = cool(c, sym)
    g.report('αναμονή', 300 <= c0 <= 593,
             'το πρώτο κύμα σε %d s (%d:%02d)' % (c0, c0 // 60, c0 % 60))

    town0 = people(c, (0, 3)), len(M7.blds(c, 1))
    for s in range(240):
        c.run_frames(50)
        if waving(c) or S.c7_read(c, sym['AI_WAVE'])[0] != 6:
            break
    town1 = people(c, (0, 3)), len(M7.blds(c, 1))
    army = people(c, (1, 2, 4))
    g.report('ησυχία', not waving(c) and
             S.c7_read(c, sym['AI_WAVE'])[0] == 6 and town1[0] > town0[0] and
             town1[1] > town0[1] and army >= 6,
             'σε %d s: κανένα κύμα (σε επίθεση %s)· χωρικοί, κτίρια %s -> %s, '
             'στρατός %d· αναμονή ακόμα %d s'
             % (s + 1, waving(c), town0, town1, army, cool(c, sym)))

    vil = [u for u in M10.team1(c) if u['set'] == 0][0]
    me = [u for u in S.units(c) if u['team'] == 0 and u['set'] == 1][0]
    M8.place(c, vil['idx'], me['wx'] + 8, me['wy'], me['wx'] + 8)
    for t in range(400):
        c.run_frames(2)
        if cool(c, sym) == 0:
            break
    g.report('πρόκληση', cool(c, sym) == 0,
             'ο χωρικός του %d δίπλα στον στρατιώτη %d: αναμονή %d σε %d '
             'καρέ' % (vil['idx'], me['idx'], cool(c, sym), 2 * (t + 1)))
    for s2 in range(180):
        c.run_frames(50)
        if S.c7_read(c, sym['AI_WAVE'])[0] != 6:
            break
    g.report('κύμα', S.c7_read(c, sym['AI_WAVE'])[0] == 8,
             'το πρώτο κύμα σε %d s μετά την πρόκληση (σε επίθεση %s)'
             % (s2 + 1, waving(c)))

    print('\nM17 (ο αντίπαλος περιμένει): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
