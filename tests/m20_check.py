"""M20: τα μενού στη μέση και τα κουμπιά του HUD (2026-11-21) — σε headless
CPC 6128.

    python3 tests/m20_check.py [--shots]

Ως το M19 κάθε πράξη ήταν ένα γράμμα (H B T U X V ESC...). Από το M20 μόνο
Q A O P / βελάκια, SPACE και RETURN: οι πράξεις σε μενού που ανοίγει στη
μέση του χάρτη (game/ui.asm) και σε 8 κουμπιά του HUD (game/ui_hud*.asm).
Με τα πλήκτρα του παίκτη ελέγχει:

1. RETURN ΣΕ ΧΩΡΙΚΟ. Επιλεγμένος χωρικός, RETURN πάνω του: το μενού BUILD
   (γραμμές BUILD, στο τέλος CLOSE). Τα βελάκια κάτω / πάνω μετακινούν τον
   δείκτη. HOUSE: τοποθέτηση (bmode = σπίτι)· το SPACE την ακυρώνει.
2. RETURN ΣΕ ΣΤΡΑΤΙΩΤΗ. Μία ομάδα επιλεγμένη, RETURN πάνω της: το μενού
   της ομάδας, με SPLIT SQUAD.
3. SPACE ΣΤΟ ΚΕΝΤΡΟ ΠΟΛΗΣ. Το μενού του (TRAIN και οι τεχνολογίες του)·
   TRAIN: η ουρά του + 1.
4. ΤΑ ΓΡΑΜΜΑΤΑ. H B T U X V ESC δεν κάνουν πια τίποτα: κανένα μενού,
   καμία τοποθέτηση, καμία ουρά, καμία αποθήκευση.
5. ΚΟΥΜΠΙΑ. Ο κέρσορας κάτω από τον χάρτη μπαίνει στα κουμπιά· σε κάθε
   κουμπί η ετικέτα του στην κορυφή του χάρτη (στη μέση, τίποτα άλλο στη
   λωρίδα) και το φόντο του φωτισμένο· φεύγοντας, το πλαίσιο ξανά ακριβώς
   όπως ήταν.
6. ΠΡΑΞΕΙΣ. IDLE VILLAGER: ένας αδρανής χωρικός επιλεγμένος, η κάμερα
   πάνω του, και το επόμενο πάτημα άλλος. NEXT AGE: το μενού του Κέντρου
   Πόλης. TRAIN: η ουρά του + 1. BUILD: το μενού BUILD. CANCEL: η
   τοποθέτηση ακυρώνεται. SPLIT SQUAD: μία ομάδα παραπάνω. (Το SAVE GAME
   το ελέγχει το M12.)
7. ΠΙΣΩ. Q από την πάνω σειρά: πίσω στον χάρτη, και η οθόνη ξανά το φόντο
   με τις μονάδες (η λωρίδα της ετικέτας από τον καθρέφτη).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import scene as S                               # noqa: E402
import ui_menu as UM                            # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import mockup                                   # noqa: E402

TC = (31, 59)                                   # tests/m14_check.py


def btn_adr(k):
    """Η αρχή του πλαισίου του κουμπιού k στη σελίδα του HUD (όπως το
    src/make_ui.py, ui_btn)."""
    x, y = mockup.btn_xy(k)
    y -= mockup.MAP_H
    return 0x4000 + (y & 7) * 0x800 + (y >> 3) * 80 + x // 2 - 1


def btn_bytes(c, k):
    a, out = btn_adr(k), b''
    for _ in range(17):
        out += c.read_ram(a, 6)
        a += 0x800
        if a >= 0x8000:
            a += 80 - 0x4000
    return out


_HUD = []


def btn_expect(k, shown):
    """(M22) Τα bytes του πλαισίου k: όπως στο HUD του σχεδίου (φανερό,
    χωρίς φωτισμό), ή το φόντο του HUD (κρυμμένο)."""
    import cpcimg
    if not shown:
        return bytes([0xC0] * 6 * 17)
    if not _HUD:
        _HUD.append(mockup.hud_background(numbers=False))
    img = _HUD[0]
    ox, oy = mockup.btn_xy(k)
    return bytes(cpcimg.mode0_byte(img[y][2 * bx], img[y][2 * bx + 1])
                 for y in range(oy, oy + 17)
                 for bx in range(ox // 2 - 1, ox // 2 + 5))


def vis(c):
    return UM.rb(c, UM.U['HB_VIS'])


def frames_ok(c):
    """Κάθε πλαίσιο όπως λέει το hb_vis (κανένα φωτισμένο)."""
    v = vis(c)
    return all(btn_bytes(c, k) == btn_expect(k, v >> k & 1) for k in range(8))


def tc_queue(c):
    return [b for b in M7.blds(c) if b['type'] == 'town_center'][0]['qn']


def squads(c):
    return sum(1 for u in S.units(c) if u['team'] == 0 and u['set'] not in
               (0, 3, 255) and u['wx'] != 0xFFFF)


def label_ok(c, sym, k):
    """Η λωρίδα της ετικέτας: μελάνι μόνο μέσα στα κελιά του κειμένου
    (κεντραρισμένο), και στο πρώτο και στο τελευταίο κελί. (Μια μονάδα που
    περνάει από τη λωρίδα ζωγραφίζεται από πάνω της: έξω από τα κελιά
    μετράει μόνο το pen των γραμμάτων.)"""
    rows = M4.M2.decode_scrolled(c, sym)[:8]
    bg = rows[7][0]
    n = len(mockup.BUTTONS[k][1])
    x0 = (80 - 3 * n) // 2 * 2
    x1 = x0 + 6 * n
    ink = {rows[y][x] for y in range(7) for x in range(x0, x1)} - {bg}
    outside = len(ink) == 1 and all(
        rows[y][x] not in ink for y in range(8) for x in range(160)
        if not x0 <= x < x1)
    first = any(rows[y][x] != bg for y in range(7) for x in range(x0, x0 + 6))
    last = any(rows[y][x] != bg for y in range(7) for x in range(x1 - 6, x1))
    return outside and first and last


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)

    # ------------------------------------------------ 1. RETURN σε χωρικό
    sel = M6.click_unit(g, 0)
    M7.press(g, CPCMOD.KEY_RETURN, 1)
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_BUILD
    rs = UM.rows(c) if ok else []
    i0 = UM.rb(c, UM.U['UM_I'])
    UM.tap(c, CPCMOD.KEY_DOWN)
    i1 = UM.rb(c, UM.U['UM_I'])
    UM.tap(c, CPCMOD.KEY_UP)
    i2 = UM.rb(c, UM.U['UM_I'])
    if g.shots:
        c.screenshot(os.path.join(M4.M.BUILD, 'm20_build.png'), aspect=True)
    import make_bank6 as MB
    house = [t[0] for t in MB.TYPES].index('house')
    UM.choose(c, UM.MA_BUILD, house)
    bm = c.peek(sym['BMODE'])
    UM.cancel(c)
    g.report('RETURN', ok and sel == {0} and rs[-1][0] == UM.MA_CLOSE and
             any(a == UM.MA_BUILD for a, _, _ in rs) and
             (i0, i1, i2) == (0, 1, 0) and bm == house and
             c.peek(sym['BMODE']) == 255,
             'RETURN στον χωρικό: μενού BUILD, %d γραμμές %s· βελάκια %s· '
             'HOUSE -> bmode %d, SPACE -> %d'
             % (len(rs), [a for a, _, _ in rs], (i0, i1, i2), bm,
                c.peek(sym['BMODE'])))

    # ------------------------------------------------ 2. RETURN σε στρατιώτη
    sold = [k for k, u in enumerate(S.units(c)) if u['team'] == 0 and
            u['set'] == 1 and u['sy'] < 130]
    M6.click_unit(g, sold[0])
    M7.press(g, CPCMOD.KEY_RETURN, 1)
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_SQUAD
    rs = UM.rows(c) if ok else []
    UM.close(c)
    g.report('ομάδα', ok and [a for a, _, _ in rs] == [UM.MA_SPLIT,
                                                      UM.MA_CLOSE],
             'RETURN στην ομάδα %d: μενού %s' % (sold[0],
                                                [a for a, _, _ in rs]))

    # ------------------------------------------------ 3. SPACE στο Κέντρο
    q0 = tc_queue(c)
    g.move_cursor(*M6.tile_cursor(g, *TC))
    M7.press(g, ' ')
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_BLD
    rs = UM.rows(c) if ok else []
    UM.choose(c, UM.MA_TRAIN)
    q1 = tc_queue(c)
    g.report('Κέντρο', ok and rs[0][0] == UM.MA_TRAIN and q1 == q0 + 1,
             'SPACE στο Κέντρο Πόλης: μενού %s· TRAIN: ουρά %d -> %d'
             % ([a for a, _, _ in rs], q0, q1))

    # ------------------------------------------------ 4. τα γράμματα
    M6.click_unit(g, 0)
    for k in list('hbtuxv') + [CPCMOD.KEY_ESC]:
        M7.press(g, k)
    dead = (not UM.is_open(c) and c.peek(sym['BMODE']) == 255 and
            tc_queue(c) == q1 and c.peek(sym['SAVE_REQ']) == 0)
    g.report('γράμματα', dead, 'H B T U X V ESC: κανένα μενού, bmode %d, '
             'ουρά %d, save_req %d' % (c.peek(sym['BMODE']), tc_queue(c),
                                       c.peek(sym['SAVE_REQ'])))

    # ------------------------------------------------ 5. κουμπιά
    # (M22) με χωρικό επιλεγμένο φαίνονται μόνο BUILD, NEXT AGE, IDLE
    # VILLAGER, SAVE GAME (0x71), τα άλλα είναι φόντο· ο κέρσορας περνάει
    # μόνο από τα φανερά: P (κανένα δεξιά), A, P, P, P (το CANCEL κρυμμένο),
    # O, Q (πάνω από το IDLE το TRAIN είναι κρυμμένο: το BUILD)
    g.tick(4)
    v0, f0 = vis(c), frames_ok(c)
    before = [btn_bytes(c, k) for k in range(8)]
    entered = UM.hud_enter(c)
    seen, lit, labels = [UM.rb(c, UM.U['HB_I'])], [], []
    for key in 'pappppoq':
        UM.tap(c, key)
        g.tick(2)
        i = UM.rb(c, UM.U['HB_I'])
        seen.append(i)
        lit.append(btn_bytes(c, i) != before[i] and
                   all(btn_bytes(c, j) == before[j] for j in range(8)
                       if j != i))
        labels.append(label_ok(c, sym, i))
        if g.shots and key == 'a':
            c.screenshot(os.path.join(M4.M.BUILD, 'm20_hud.png'),
                         aspect=True)
    g.report('κουμπιά', entered and v0 == 0x71 and f0 and
             seen == [0, 0, 4, 5, 6, 6, 6, 5, 0] and all(lit) and all(labels),
             'χωρικός: φανερά #%02X, τα πλαίσια σωστά %s· A: στα κουμπιά %s· '
             'P A P P P P O Q: %s· φωτισμένο μόνο το τρέχον %s· ετικέτα %s'
             % (v0, f0, entered, seen, all(lit), labels))

    # ------------------------------------------------ 6. πράξεις
    out = []
    UM.hud_button(c, UM.HB_IDLE, leave=False)
    g.tick(4)
    v1 = S.units(c)
    s1 = [k for k, u in enumerate(v1) if u['fl'] & S.F_SEL]
    cam1 = M4.M2.cam(c, sym)
    u = v1[s1[0]] if len(s1) == 1 else None
    near = u is not None and abs(u['wx'] - cam1[0] - 40) <= 4 and \
        abs(u['wy'] - cam1[1] - 64) <= 10
    UM.hud_button(c, UM.HB_IDLE, leave=False)
    g.tick(4)
    s2 = [k for k, u in enumerate(S.units(c)) if u['fl'] & S.F_SEL]
    out.append(('IDLE', len(s1) == 1 and u['set'] == 0 and near and
                len(s2) == 1 and s2 != s1, '%s -> %s, κάμερα %s' %
                (s1, s2, cam1)))

    UM.hud_button(c, UM.HB_AGE, leave=False)
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_BLD
    tc = [b for b in M7.blds(c) if b['type'] == 'town_center'][0]['slot']
    rs = UM.rows(c) if ok else []
    UM.close(c)
    g.tick(2)
    seen_vis = [('Κέντρο', vis(c), 0x77)]   # (M22) + TRAIN, RESEARCH (και ο
    #                                         χωρικός του IDLE: BUILD)
    out.append(('NEXT AGE', ok and c.peek(sym['SEL_BLD']) == tc and
                any(a == UM.MA_TECH for a, _, _ in rs),
                'μενού του Κέντρου (θέση %d): %s' %
                (c.peek(sym['SEL_BLD']), [a for a, _, _ in rs])))

    q0 = tc_queue(c)
    UM.hud_button(c, UM.HB_TRAIN, leave=False)
    g.tick(2)
    out.append(('TRAIN', tc_queue(c) == q0 + 1, 'ουρά %d -> %d'
                % (q0, tc_queue(c))))

    UM.hud_button(c, UM.HB_RESEARCH, leave=False)
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_BLD
    UM.close(c)
    out.append(('RESEARCH', ok, 'το μενού του επιλεγμένου κτιρίου'))

    UM.hud_leave(c)
    M6.click_unit(g, 0)
    UM.hud_button(c, UM.HB_BUILD, leave=False)
    ok = UM.wait_open(c) and UM.rb(c, UM.U['UM_KIND']) == UM.MK_BUILD
    UM.choose(c, UM.MA_BUILD, house)
    bm = c.peek(sym['BMODE'])
    g.tick(2)
    seen_vis.append(('τοποθέτηση', vis(c), 0xF1))   # + CANCEL
    UM.hud_button(c, UM.HB_CANCEL, leave=False)
    g.tick(2)
    seen_vis.append(('CANCEL', vis(c), 0x71))
    out.append(('BUILD', ok and bm == house, 'μενού BUILD, HOUSE -> %d' % bm))
    out.append(('CANCEL', c.peek(sym['BMODE']) == 255,
                'bmode %d' % c.peek(sym['BMODE'])))

    UM.hud_leave(c)
    n0 = squads(c)
    sold = [k for k, u in enumerate(S.units(c)) if u['team'] == 0 and
            u['set'] == 1 and u['sy'] < 130]
    c.poke(0x3F00 + sold[0], 3)         # SQ_N: μια ομάδα των 4 (M15)
    M6.click_unit(g, sold[0])
    g.tick(2)
    seen_vis.append(('ομάδα', vis(c), 0x78))       # SPLIT SQUAD
    UM.hud_button(c, UM.HB_SPLIT, leave=False)
    g.tick(4)
    out.append(('SPLIT', squads(c) == n0 + 1, 'ομάδες %d -> %d'
                % (n0, squads(c))))
    out.append(('νόημα', all(v == w for _, v, w in seen_vis),
                '(M22) τα φανερά: %s' % ', '.join(
                    '%s #%02X (#%02X)' % x for x in seen_vis)))
    for name, good, what in out:
        g.report(name, good, what)

    # ------------------------------------------------ 7. πίσω
    for k in range(8):                  # στην πάνω σειρά, και Q
        if UM.rb(c, UM.U['HB_I']) < 4:
            break
        UM.tap(c, 'q')
    UM.hud_leave(c)
    g.tick(6)
    back = not UM.rb(c, UM.U['HB_ON'])
    same = frames_ok(c)
    comp = g.compose('m20_back')
    g.report('πίσω', back and same and comp,
             'Q: στον χάρτη %s· τα πλαίσια όπως λέει το hb_vis (#%02X), κανένα '
             'φωτισμένο %s· η οθόνη = φόντο + μονάδες %s'
             % (back, vis(c), same, comp))

    print('M20 (τα μενού και τα κουμπιά): %s' % ('OK' if g.ok else
                                                  'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
