"""M10: ο αντίπαλος — σε headless CPC 6128.

    python3 tests/m10_check.py [--shots]

ΜΙΑ ΠΑΡΤΙΔΑ ΩΣ ΤΗΝ ΗΤΤΑ. Ο παίκτης δεν αγγίζει τίποτα· το πρώτο κύμα έρχεται
στα WAVE_AT s αντί για 180 (ai_cool, στην C7). Δειγματοληψία ανά δευτερόλεπτο:

1. ΑΡΧΗ. Το Κέντρο Πόλης του αντιπάλου (ομάδα 1) έτοιμο στο (58, 27), οι 12
   μονάδες του (4 χωρικοί, 4 σπαθοφόροι, 4 τοξότες) δίπλα του, όχι
   περιπλανώμενες, και οι πόροι του 200 200 100 200.
2. ΟΙΚΟΝΟΜΙΑ. Οι χωρικοί του μαζεύουν (δουλειές πηγαίνω / μαζεύω / γυρνάω),
   οι πόροι του ανεβαίνουν με τα αδειάσματα (στο Κέντρο ΤΟΥ), και το Κέντρο
   του βγάζει χωρικό.
3. ΚΤΙΣΙΜΟ. Σπίτι και στρατώνας του αντιπάλου, έτοιμα.
4. ΣΤΡΑΤΟΣ. Ο στρατώνας του βγάζει σπαθοφόρο.
5. ΚΥΜΑ. Μετά το ai_cool: κύμα, με ≥ 6 στρατιώτες με εντολή επίθεσης στο
   Κέντρο Πόλης του παίκτη (C7_ORD = 128 + θέση).
6. ΚΑΤΕΔΑΦΙΣΗ. Το Κέντρο Πόλης του παίκτη χτυπιέται (BDMG) και πέφτει: η
   θέση ελεύθερη, η κάτοψη όχι πια κτίριο στον χάρτη.
7. ΗΤΤΑ. Χωρίς μονάδες και Κέντρο: game_end = 2, το παιχνίδι σταματά (καμία
   μονάδα δεν αλλάζει πια), ο πληθυσμός της μπάρας 0, και το περιθώριο
   κόκκινο.
8. ΧΡΟΝΟΣ. Τυπώνεται ως μέτρηση (όπως στο M3 και στο M8): 20 s από το κύμα
   και μετά — και χωριστά τα καρέ όπου σκέφτεται ο αντίπαλος.

Σε νέο παιχνίδι, ΝΙΚΗ: οι μονάδες του αντιπάλου γίνονται ουδέτερες και οι
πόροι του 0 (δεν ξαναχτίζει), και οι 8 στρατιώτες του παίκτη δίπλα στο
Κέντρο του.
9. ΟΧΙ ΔΙΚΟ ΣΟΥ. Κλικ στο Κέντρο του αντιπάλου, T: τίποτα (ούτε ουρά, ούτε
   πληρωμή).
10. ΕΝΤΟΛΗ ΣΕ ΚΤΙΡΙΟ. RETURN πάνω του με τους 8 επιλεγμένους: όλοι το έχουν
    στόχο, το ρίχνουν, η ζημιά του σβήνει, και η οθόνη μετά = ο κόσμος χωρίς
    αυτό, pixel προς pixel.
11. ΝΙΚΗ. game_end = 1, και το περιθώριο πράσινο.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import m8_check as M8                           # noqa: E402
import m9_check as M9                           # noqa: E402
import scene as S                               # noqa: E402
from cpc import KEY_RETURN                      # noqa: E402

C7_ORD = 0x7F00                 # game/bank7.asm (equ: όχι στα σύμβολα)
BDMG = 0x7FC0                   # RES_P + BLD_MAX + 4
MAP, MAPW, BLD_RES = 0x8000, 96, 13
U_JOB, U_TEAM = 27, 28
AI_TC = (58, 27)
WAVE_AT = 40                    # s
LIMIT = 900                     # s (M13: η ήττα ενός αδρανούς παίκτη είναι
                                # χαοτική — 318 s στο M12, 688 s στο M13)
SOLDIERS = (1, 2, 4, 5, 7, 8, 10, 11)   # της πόλης: σπαθοφόροι και τοξότες
SELLIST = 0xA840


def word(c, a):
    return c.peek(a) | c.peek(a + 1) << 8


def ai_val(c, sym):
    return [word(c, sym['AI_VAL'] + 2 * k) for k in range(4)]


def team1(c):
    """Οι ζωντανές του αντιπάλου (όχι οι ουδέτερες που περιπλανιούνται)."""
    return [u for u in S.units(c) if u['team'] == 1 and
            not u['fl'] & S.F_WANDER]


def foot_free(c, i0, j0, n):
    return all(c.peek(MAP + j * MAPW + i) & 15 != BLD_RES
               for i in range(i0, i0 + n) for j in range(j0, j0 + n))


def border(c):
    return c.image(full_framebuffer=True).getpixel((4, 4))


def defeat(shots):
    g = M4.Game(shots, ai=True)
    c, sym = g.c, g.sym
    S.c7_write(c, sym['AI_COOL'], [WAVE_AT, 0])

    # ------------------------------------------------------ 1. αρχή
    etc = M7.blds(c, 1)
    t1 = team1(c)
    sets = sorted(u['set'] for u in t1)
    g.report('αρχή', len(etc) == 1 and etc[0]['type'] == 'town_center' and
             (etc[0]['i0'], etc[0]['j0']) == AI_TC and etc[0]['st'] == 1 and
             sets == [0] * 4 + [1] * 4 + [2] * 4 and
             ai_val(c, sym) == [200, 200, 100, 200],
             'το Κέντρο του αντιπάλου %s, οι μονάδες του (σετ) %s, πόροι %s'
             % ([(b['type'], b['i0'], b['j0'], b['st']) for b in etc], sets,
                ai_val(c, sym)))
    ptc = M7.blds(c, 0)[0]
    assert ptc['type'] == 'town_center'

    seen = {}
    prev_t1 = {u['idx']: u['set'] for u in team1(c)}
    jobs = set()
    prev = ai_val(c, sym)
    ups = 0
    times, think = [], []
    for s in range(1, LIMIT + 1):
        c.run_frames(50)
        t1 = team1(c)
        for u in t1:
            if u['set'] in (0, 3):
                jobs.add(c.peek(u['addr'] + U_JOB))
            if u['idx'] not in prev_t1:         # νέα (σε θέση που ήταν
                seen.setdefault('trained%d' % u['set'], s)  # ελεύθερη)
        prev_t1 = {u['idx']: u['set'] for u in t1}
        v = ai_val(c, sym)
        ups += sum(1 for a, b in zip(prev, v) if b > a)
        prev = v
        for b in M7.blds(c, 1):
            if b['st'] == 1:
                seen.setdefault(b['type'], s)
        orders = S.c7_read(c, C7_ORD, 128)
        n_ord = sum(1 for u in t1 if orders[u['idx']] == 128 + ptc['slot'])
        if n_ord >= 6:
            seen.setdefault('wave', (s, n_ord))
        dmg = S.c7_read(c, BDMG + 2 * ptc['slot'], 2)
        if dmg[0] | dmg[1]:
            seen.setdefault('dmg', s)
        if 'gone' not in seen and c.peek(M7.BLD_SLOTS[ptc['slot']]) == 255:
            seen['gone'] = (s, foot_free(c, ptc['i0'], ptc['j0'], 4))
        if 'wave' in seen and not times:        # 20 s μέτρηση από το κύμα
            for _ in range(25 * 20):
                M3.wait_uphase(c, sym, 4)
                M3.wait_uphase(c, sym, 3)
                st = S.c7_read(c, sym['AI_T'])[0]
                ms = M3.wait_uphase(c, sym, 4) / 1000.0
                times.append(ms)
                if st in (0, 1, 2, 3, 4, 5):    # (τα καρέ με σκέψη: 1-7)
                    think.append(ms)
        if c.peek(sym['GAME_END']):
            break
    end = c.peek(sym['GAME_END'])

    g.report('οικονομία', {1, 2, 3} <= jobs and ups >= 3 and
             'trained0' in seen,
             'οι χωρικοί του σε δουλειές %s, οι πόροι του ανέβηκαν %d φορές, '
             'νέος χωρικός από το Κέντρο του στα %s s'
             % (sorted(jobs), ups, seen.get('trained0')))
    g.report('κτίσιμο', 'house' in seen and 'barracks' in seen,
             'σπίτι έτοιμο στα %s s, στρατώνας στα %s s'
             % (seen.get('house'), seen.get('barracks')))
    g.report('στρατός', 'trained1' in seen,
             'σπαθοφόρος από τον στρατώνα του στα %s s' % seen.get('trained1'))
    g.report('κύμα', 'wave' in seen and seen['wave'][0] >= WAVE_AT,
             '(στα, με εντολή στο Κέντρο του παίκτη) %s' % (seen.get('wave'),))
    g.report('κατεδάφιση', 'dmg' in seen and 'gone' in seen and
             seen['gone'][1],
             'πρώτη ζημιά στα %s s, το Κέντρο του παίκτη έπεσε (στα, κάτοψη '
             'ελεύθερη) %s' % (seen.get('dmg'), seen.get('gone')))
    before = c.read_ram(S.UNIT_TAB, S.UNITS * S.U_SIZE)
    c.run_frames(150)
    frozen = c.read_ram(S.UNIT_TAB, S.UNITS * S.U_SIZE) == before
    alive0 = [u for u in S.units(c) if u['team'] == 0]
    r, gg, b = border(c)
    g.report('ήττα', end == 2 and c.peek(sym['PAUSED']) == 1 and frozen and
             not alive0 and word(c, sym['HUD_VAL'] + 8) == 0 and
             r > 150 and gg < 100,
             'game_end %d στα %d s, σταματημένο %s, του παίκτη ζωντανές %d, '
             'πληθυσμός %d, περιθώριο %s' % (end, s, frozen, len(alive0),
                                            word(c, sym['HUD_VAL'] + 8),
                                            (r, gg, b)))
    if shots:
        path = os.path.join(M4.M.BUILD, 'm10_defeat.png')
        c.screenshot(path, full_framebuffer=True)
        print('   ', path)
    if times:
        print('χρόνος   μέτρηση   20 s από το κύμα: μέσος %.1f ms, μέγιστος %.1f '
              'ms, %d από %d καρέ > 40· τα καρέ της σκέψης: μέσος %.1f, '
              'μέγιστος %.1f' % (sum(times) / len(times), max(times),
                                 sum(1 for t in times if t > 40), len(times),
                                 sum(think) / len(think), max(think)))
    return g.ok


def victory(shots):
    g = M4.Game(shots, ai=True)
    c, sym = g.c, g.sym
    for k in range(4):                          # ο αντίπαλος χωρίς πόρους
        c.poke(sym['AI_VAL'] + 2 * k, 0)
        c.poke(sym['AI_VAL'] + 2 * k + 1, 0)
    for u in team1(c):                          # και οι μονάδες του ουδέτερες
        c.poke(u['addr'] + 11, u['fl'] | S.F_WANDER)
        c.poke(M8.NT + u['idx'], 1)
    etc = M7.blds(c, 1)[0]
    # οι 8 στρατιώτες της πόλης ανατολικά του Κέντρου του, και η κάμερα εκεί
    for n, k in enumerate(SOLDIERS):
        i, j = 63 + 2 * (n // 4), 26 + 2 * (n % 4)
        x, y = 2 * (i - j) + 190, 4 * (i + j) - 10
        M8.place(c, k, x, y, x + 2)
    M4.M.render_at(c, sym, 216, 271)    # (cam_y ≡ 7 mod 8, όπως στο παιχνίδι)
    g.tick(30)

    # ------------------------------------------------------ 9. όχι δικό σου
    hud0 = [word(c, sym['HUD_VAL'] + 2 * k) for k in range(4)]
    sel = M9.click_bld(g, (59, 28))
    M7.press(g, 't')
    g.tick(5)
    q = M7.blds(c, 1)[0]['qn']
    hud1 = [word(c, sym['HUD_VAL'] + 2 * k) for k in range(4)]
    g.report('όχι δικό', sel == etc['slot'] and q == 0 and hud1 == hud0,
             'κλικ: επιλεγμένο το %d (του αντιπάλου: %d), T: ουρά %d, μπάρα '
             '%s -> %s' % (sel, etc['slot'], q, hud0, hud1))

    # ------------------------------------------------------ 10. εντολή σε κτίριο
    for n, k in enumerate(SOLDIERS):            # η επιλογή (το κουτί το
        a = S.UNIT_TAB + k * S.U_SIZE           # ελέγχει το M4)
        c.poke(SELLIST + 2 * n, a & 255)
        c.poke(SELLIST + 2 * n + 1, a >> 8)
        c.poke(a + 11, c.peek(a + 11) | S.F_SEL)
    c.poke(sym['SEL_N'], len(SOLDIERS))
    g.move_cursor(*M6.tile_cursor(g, 59, 28))
    M7.press(g, KEY_RETURN, 1)
    orders = S.c7_read(c, C7_ORD, 128)
    ordered = [k for k in SOLDIERS if orders[k] == 128 + etc['slot']]
    dmg_max, fell = 0, None
    for f in range(1500):
        g.tick(1)
        d = S.c7_read(c, BDMG + 2 * etc['slot'], 2)
        dmg_max = max(dmg_max, d[0] | d[1] << 8)
        if c.peek(M7.BLD_SLOTS[etc['slot']]) == 255:
            fell = f
            break
    for f in range(400):                        # η επανασχεδίαση, και το
        if c.peek(sym['GAME_END']):             # τέλος
            break
        g.tick(1)
    d = S.c7_read(c, BDMG + 2 * etc['slot'], 2)
    g.world = M4.M.game_world(blds=[('town_center', 30, 58)])
    same = g.compose('victory')
    g.report('εντολή', ordered == list(SOLDIERS) and fell is not None and
             dmg_max >= 500 and d == b'\0\0' and
             foot_free(c, *AI_TC, 4) and same,
             'RETURN πάνω στο Κέντρο του: εντολή στο κτίριο %s· έπεσε σε %s '
             'καρέ (ζημιά ως %d, μετά %d)· η οθόνη = ο κόσμος χωρίς αυτό'
             % (ordered, fell, dmg_max, d[0] | d[1] << 8))
    end = c.peek(sym['GAME_END'])
    c.run_frames(10)                            # (το καρέ του τέλους ήταν
    r, gg, b = border(c)                        # ακόμα με τη λωρίδα του χρόνου)
    g.report('νίκη', end == 1 and gg > 150 and r < 100,
             'game_end %d, περιθώριο %s' % (end, (r, gg, b)))
    if shots:
        path = os.path.join(M4.M.BUILD, 'm10_victory.png')
        c.screenshot(path, full_framebuffer=True)
        print('   ', path)
    return g.ok


def main():
    shots = '--shots' in sys.argv
    ok = defeat(shots)
    ok &= victory(shots)
    print('\nM10: %s' % ('OK' if ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
