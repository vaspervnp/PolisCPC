"""M14: το tutorial — σε headless CPC 6128, από τη δισκέτα.

    python3 tests/m14_check.py [--shots]

RUN"POLIS, TUTORIAL (game/tutor.asm, src/make_tutor.py):

1. ΠΑΡΑΘΥΡΟ. Σε κάθε βήμα το παράθυρο του Ηροδότου στη μέση του χάρτη
   είναι pixel προς pixel το make_tutor.window (πλαίσιο, πορτρέτο, τίτλος,
   το κείμενο του βήματος, RETURN).
2. ΠΑΓΩΜΑ. Όσο είναι ανοιχτό, το παιχνίδι περιμένει: 100 καρέ μετά, όλες
   οι μονάδες στην ίδια θέση. Το RETURN το κλείνει, και ο χάρτης
   ξαναζωγραφίζεται (η οθόνη = ο κόσμος).
3. ΒΗΜΑΤΑ. Κάθε βήμα ανοίγει μόνο με την πράξη του, με πλήκτρα:
   επιλογή χωρικού, μούρα, σπίτι (H), χωρικός από το Κέντρο Πόλης (T),
   στρατώνας (B), σπαθοφόρος (T στον στρατώνα). Πριν την πράξη, 150 καρέ
   χωρίς παράθυρο.
4. ΤΕΛΟΣ. Μετά το τελευταίο, tut_on = 0, και ο αντίπαλος με το πρώτο κύμα
   στα 900 s (C7: ai_cool).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import scene as S                               # noqa: E402
import make_tutor as MT                         # noqa: E402
import cpc as CP                                # noqa: E402
from cpc import CPC                             # noqa: E402

BERRIES = (37, 52)
HOUSE = (27, 63)
TC = (31, 59)
BARRACKS = (35, 67)
OK = True


def report(name, good, what):
    global OK
    print('%-10s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    OK &= bool(good)


def tut(c, sym):
    return c.peek(sym['TUT_ON']), c.peek(sym['TUT_WIN']), \
        c.peek(sym['TUT_STEP'])


def wait_window(c, sym, limit=6000):
    """Ως το ανοιχτό παράθυρο (ζωγραφισμένο: λίγα καρέ μετά)."""
    for f in range(limit):
        c.run_frames(1)
        if c.peek(sym['TUT_WIN']) == 1 and c.peek(sym['PHASE']) == 6:
            c.run_frames(25)
            return f
    return None


def window_diff(c, sym, step):
    rows = M2.decode_scrolled(c, sym)
    exp = MT.window([[0] * 160 for _ in range(144)], step)
    bad = [(x, y) for y in range(MT.WIN_Y, MT.WIN_Y + MT.WIN_H)
           for x in range(2 * MT.WIN_X, 2 * (MT.WIN_X + MT.WIN_W))
           if rows[y][x] != exp[y][x]]
    return len(bad)


def close(c, sym):
    c.key_down(CP.KEY_RETURN)
    c.run_frames(6)
    c.key_up(CP.KEY_RETURN)
    for f in range(200):
        c.run_frames(1)
        if c.peek(sym['TUT_WIN']) == 0 and c.peek(sym['PHASE']) == 6:
            break
    c.run_frames(4)


def check(c, sym, step, shots, f):
    bad = window_diff(c, sym, step)
    on, win, st = tut(c, sym)
    report('ΒΗΜΑ %d' % step, f is not None and bad == 0 and st == step and
           win == 1, 'το παράθυρο σε %s καρέ: %d pixels διαφέρουν· «%s»'
           % (f, bad, ' '.join(MT.wrap(MT.STEPS[step][0])).strip()))
    if shots:
        path = os.path.join(M.BUILD, 'm14_step%d.png' % step)
        c.screenshot(path, aspect=True)
        print('   ', path)


def quiet(c, sym, step):
    """Πριν την πράξη: κανένα παράθυρο."""
    for _ in range(150):
        c.run_frames(1)
        if c.peek(sym['TUT_WIN']):
            report('ΑΝΑΜΟΝΗ %d' % step, False, 'παράθυρο χωρίς την πράξη')
            return


def main():
    shots = '--shots' in sys.argv
    sym = M.symbols()
    c = CPC()
    c.run_frames(150)
    c.insert_disc(os.path.join(M.BUILD, 'polis.dsk'))
    c.type_text('RUN"POLIS\n')
    M.wait_menu(c)
    import make_menu as MN
    for k in [CP.KEY_DOWN] * MN.items().index(MN.TUTORIAL) + [CP.KEY_RETURN]:
        c.key_down(k)
        c.run_frames(4)
        c.key_up(k)
        c.run_frames(4)
    g = M4.Game.__new__(M4.Game)        # τα βοηθητικά του M4 στο ίδιο CPC
    g.c, g.sym, g.shots, g.times, g.scrolled, g.ok = c, sym, False, [], [], \
        True

    def tick(n=1):                      # με το παράθυρο ανοιχτό δεν
        for _ in range(n):              # υπάρχουν καρέ μονάδων: καρέ οθόνης
            if c.peek(sym['TUT_WIN']):
                c.run_frames(2)
                continue
            try:
                M3.tick_time(c, sym)
            except RuntimeError:        # άνοιξε στη μέση της αναμονής
                pass
    g.tick = tick

    # ---- 0: ο χαιρετισμός· το πάγωμα
    f = wait_window(c, sym)
    check(c, sym, 0, shots, f)
    cool = S.c7_read(c, sym['AI_COOL'], 2)
    pos = [(u['wx'], u['wy']) for u in S.units(c)]
    c.run_frames(100)
    same = pos == [(u['wx'], u['wy']) for u in S.units(c)]
    report('ΠΑΓΩΜΑ', same and tut(c, sym)[1] == 1,
           '100 καρέ με το παράθυρο ανοιχτό: οι μονάδες στη θέση τους %s'
           % same)
    close(c, sym)
    # ---- 1: επιλογή χωρικού
    f = wait_window(c, sym)
    check(c, sym, 1, shots, f)
    close(c, sym)
    cx, cy = M2.cam(c, sym)
    world = M.game_world(blds=[('town_center', 30, 58),
                               ('town_center', 58, 27)], seen=S.fog_seen(c))
    g.tick(3)
    same = M2.diff(M2.decode_scrolled(c, sym),
                   S.expected(c, sym, M.reference(world, cx, cy)),
                   'm14_closed', c, shots)
    report('ΚΛΕΙΣΙΜΟ', same and tut(c, sym)[1] == 0,
           'RETURN: το παράθυρο κλειστό, η οθόνη = ο κόσμος %s' % same)
    quiet(c, sym, 1)
    M6.click_unit(g, 0)
    # ---- 2: τα μούρα
    f = wait_window(c, sym)
    check(c, sym, 2, shots, f)
    close(c, sym)
    quiet(c, sym, 2)
    M6.command(g, BERRIES)
    # ---- 3: σπίτι
    f = wait_window(c, sym)
    check(c, sym, 3, shots, f)
    close(c, sym)
    quiet(c, sym, 3)
    M6.click_unit(g, 3)
    M7.press(g, 'h')
    g.move_cursor(*M6.tile_cursor(g, *HOUSE))
    M7.press(g, CP.KEY_RETURN, 1)
    # ---- 4: χωρικός από το Κέντρο Πόλης
    f = wait_window(c, sym)
    check(c, sym, 4, shots, f)
    close(c, sym)
    quiet(c, sym, 4)
    g.move_cursor(*M6.tile_cursor(g, *TC))
    M7.press(g, ' ')
    M7.press(g, 't')
    # ---- 5: στρατώνας
    f = wait_window(c, sym)
    check(c, sym, 5, shots, f)
    close(c, sym)
    quiet(c, sym, 5)
    M6.click_unit(g, 6)
    M7.press(g, 'b')
    g.move_cursor(*M6.tile_cursor(g, *BARRACKS))
    M7.press(g, CP.KEY_RETURN, 1)
    # ---- 6: σπαθοφόρος
    f = wait_window(c, sym)
    check(c, sym, 6, shots, f)
    close(c, sym)
    quiet(c, sym, 6)
    for k in range(4000):                       # ο στρατώνας έτοιμος
        g.tick(1)
        b = [b for b in M7.blds(c) if b['type'] == 'barracks']
        if b and b[0]['st'] == 1:
            break
    g.move_cursor(*M6.tile_cursor(g, *BARRACKS))
    M7.press(g, ' ')
    M7.press(g, 't')
    # ---- 7: ο εχθρός· το τέλος
    f = wait_window(c, sym)
    check(c, sym, 7, shots, f)
    close(c, sym)
    on, win, st = tut(c, sym)
    report('ΤΕΛΟΣ', (on, win) == (0, 0) and cool == bytes([900 & 255,
                                                           900 >> 8]),
           'tut_on %d, tut_win %d· το πρώτο κύμα του αντιπάλου στα %d s'
           % (on, win, cool[0] | cool[1] << 8))
    print('\nM14: %s' % ('OK' if OK else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if OK else 1)


if __name__ == '__main__':
    main()
