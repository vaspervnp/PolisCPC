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

J_SI, J_SJ = 0x7F00, 0x7F80                     # game/gather.asm
U_JOB = 27
NEAR = 16
ok = True


def report(name, good, what):
    global ok
    print('%-8s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    ok &= bool(good)


def main():
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
