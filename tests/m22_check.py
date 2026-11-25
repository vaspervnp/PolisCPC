"""M22: οι χωρικοί του αντιπάλου μένουν κοντά στο Κέντρο τους (2026-11-22)
— σε headless CPC 6128.

    python3 tests/m22_check.py

1. ΣΠΟΡΟΙ. Οι πρώτες πηγές του αντιπάλου (ai_seed, game/boot.asm) είναι
   αυτές της κεφαλίδας της πίστας: ανά είδος η πιο κοντινή στο σπίτι του
   (src/make_levels.py, seeds) — όχι πια οι σταθερές του χάρτη του mockup.
2. ΚΟΝΤΑ. Η πίστα G2 από τη δισκέτα (το σπίτι του στο (28, 24): οι παλιές
   σταθερές ήταν 33 πλακίδια μακριά), 5 λεπτά: οι πηγές όσων μαζεύουν
   (J_GO, J_WORK, J_BACK) ως NEAR πλακίδια από το σπίτι (ως το M21: διάμεσος
   24, 82% πάνω από 20).
4. ΓΕΙΤΟΝΕΣ (2026-11-25). Νέο παιχνίδι από τη δισκέτα (PLAY), ο παίκτης
   αδρανής, 280 s: καμία περιπλανώμενη του αντιπάλου (F_WANDER) πιο κοντά
   από FAR στην πόλη του παίκτη (max(|dx|, |dy| / 2) σε συντεταγμένες
   κόσμου, από το κέντρο των χωρικών του· ως τότε 11 από τα 40 s). Μετά τα
   300 s (WZ_OFF = 1) ξανά ελεύθερες.
3. CONTROLS. Στο μενού έναρξης η επιλογή CONTROLS: η σελίδα με τα πλήκτρα
   pixel προς pixel (src/make_menu.py, ctrl_lines), και με SPACE πίσω στο
   μενού — ίδιο pixel προς pixel, με το βέλος στο CONTROLS.
"""
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m1_check as M                            # noqa: E402
import m12_check as M12                         # noqa: E402
import m13_check as M13                         # noqa: E402
import scene as S                               # noqa: E402
import dsk as DK                                # noqa: E402
import make_levels as ML                        # noqa: E402
import make_menu as MN                          # noqa: E402
import cpc as CP                                # noqa: E402

J_SI, J_SJ = 0x7F00, 0x7F80                     # game/gather.asm
U_JOB = 27
NEAR = 16
ok = True


def report(name, good, what):
    global ok
    print('%-8s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    ok &= bool(good)


def arrow(img, k, pen):
    """Το βέλος του μενού στην επιλογή k (pen 0: σβηστό)."""
    y = MN.ITEM_Y0 + k * MN.ITEM_DY
    for r, row in enumerate(MN.GLYPHS['>']):
        for dy in (0, 1):
            for i, b in enumerate(row + '.'):
                img[y + 2 * r + dy][2 * (MN.ITEM_X - 2 * MN.CELL) + i] = \
                    pen if b == '#' else 0


def controls():
    c = M12.boot(os.path.join(M.BUILD, 'polis.dsk'), [])
    c.run_frames(30)
    k = MN.items().index(MN.CONTROLS)
    for _ in range(k - MN.SEL0):
        c.tap_key(CP.KEY_DOWN)
        c.run_frames(6)
    c.tap_key(CP.KEY_RETURN)
    c.run_frames(40)
    exp = M13.text_image(MN.ctrl_lines())
    got = M12.screen_pens(c)
    bad = sum(1 for y in range(200) for x in range(160) if exp[y][x] != got[y][x])
    c.tap_key(' ')
    c.run_frames(150)
    exp2 = M12.menu_image()
    arrow(exp2, MN.SEL0, 0)
    arrow(exp2, k, MN.PEN_HI)
    got2 = M12.screen_pens(c)
    bad2 = sum(1 for y in range(200) for x in range(160)
               if exp2[y][x] != got2[y][x])
    report('CONTROLS', bad == 0 and bad2 == 0,
           'η σελίδα: %d pixels διαφέρουν· SPACE: το μενού, με το βέλος στο '
           'CONTROLS: %d' % (bad, bad2))


FAR = 24


def neighbours():
    sym = M.symbols()
    c = M12.boot(os.path.join(M.BUILD, 'polis.dsk'), [])
    c.tap_key(CP.KEY_RETURN)
    M.wait_phase(c, sym, 6, limit_ms=10000)
    mine = [u for u in S.units(c) if u['team'] == 0 and u['wx'] != 0xFFFF]
    hx = sum(u['wx'] for u in mine) / len(mine)
    hy = sum(u['wy'] for u in mine) / len(mine)
    near, n = 999, 0
    for _ in range(56):                         # 56 x 5 s
        c.run_frames(250)
        for u in S.units(c):
            if u['team'] == 1 and u['fl'] & S.F_WANDER and u['wx'] != 0xFFFF:
                n += 1
                near = min(near, max(abs(u['wx'] - hx), abs(u['wy'] - hy) / 2))
    wz_off = 0xADE5                             # WZ_OFF (fog.asm, equ)
    off0 = c.peek(wz_off)
    for _ in range(12):
        c.run_frames(250)
    off1 = c.peek(wz_off)
    report('ΓΕΙΤΟΝΕΣ', n > 1000 and near >= FAR and off0 == 0 and off1 == 1,
           '280 s, %d δείγματα: η πιο κοντινή περιπλανώμενη %d από την πόλη '
           '(όριο %d)· WZ_OFF %d, μετά από 60 s ακόμα %d'
           % (n, near, FAR, off0, off1))


def main():
    controls()
    neighbours()
    sym = M.symbols()
    path = os.path.join(M.BUILD, 'm22_g2.dsk')
    shutil.copy(os.path.join(M.BUILD, 'polis.dsk'), path)
    d = DK.Dsk(path)
    blk = [b for e in sorted(d.files()['PROG    BIN']) for b in e[2]][0]
    data = bytearray(d.read_block(blk))
    data[0:2] = bytes([2, 1])                   # η πρόοδος: G2
    d.write_block(blk, data)
    d.save()

    c = M12.boot(path, [])
    M13.campaign(c, sym, 'G', False)
    M13.wait_brief(c, 'G', 2)
    M13.start_level(c, sym, 'G', 2, False)

    lv = [x for x in ML.LEVELS if x[0] == 'G' and x[1] == 2][0]
    grd, res, hdr = ML.build(lv)
    home = (lv[4][0] + 2, lv[4][1] + 2)
    want = ML.seeds(res, home)
    got = c.read_ram(sym['AI_SEED'], 8)
    got = [(got[2 * k], got[2 * k + 1]) for k in range(4)]
    report('ΣΠΟΡΟΙ', got == want, 'ai_seed %s (η κεφαλίδα: %s, το σπίτι %s)'
           % (got, want, home))

    dist = []
    for _ in range(60):                         # 60 x 5 s
        c.run_frames(250)
        si, sj = c.read_ram(J_SI, 128), c.read_ram(J_SJ, 128)
        for k, u in enumerate(S.units(c)):
            job = c.read_ram(S.UNIT_TAB + k * S.U_SIZE + U_JOB, 1)[0]
            if u['team'] == 1 and u['set'] in (0, 3) and job in (1, 2, 3):
                dist.append(max(abs(si[k] - home[0]), abs(sj[k] - home[1])))
    dist.sort()
    n = len(dist)
    report('ΚΟΝΤΑ', n > 100 and dist[-1] <= NEAR,
           '5 λεπτά, %d δείγματα: απόσταση της πηγής από το σπίτι διάμεσος %s, '
           'μέγιστη %s (όριο %d)' % (n, dist[n // 2] if n else '-',
                                     dist[-1] if n else '-', NEAR))
    print('M22 (οι χωρικοί του αντιπάλου): %s' % ('OK' if ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
