"""Στατιστικός profiler: δειγματοληψία του PC του Z80 στον headless emulator.

    python3 tests/profile.py [cam_x cam_y]

Ζητάει μία πλήρη σχεδίαση του παραθύρου και κάθε 7 µs γράφει πού είναι ο
PC. Τα δείγματα αντιστοιχίζονται στο πλησιέστερο σύμβολο από κάτω (τοπικές
ετικέτες συμπεριλαμβάνονται), οπότε φαίνεται και ποιος βρόχος τρώει.
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
from cpc import CPC                             # noqa: E402

STEP = 7


def main():
    sym = M.symbols()
    cx, cy = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 \
        else (98, 303)
    labels = sorted((a, n) for n, a in sym.items() if a < 0x4000)
    c = CPC()
    c.run_frames(5)
    c.quickload(os.path.join(M.BUILD, 'polis.sna'))
    M.wait_phase(c, sym, 2)
    c.poke(sym['PHASE'], 0)
    for k, v in ((sym['CAM_X'], cx), (sym['CAM_Y'], cy & 0xFFFF)):
        c.poke(k, v & 0xFF)
        c.poke(k + 1, v >> 8)
    c.poke(sym['REDRAW'], 1)
    M.wait_phase(c, sym, 1)
    hits = collections.Counter()
    n = 0
    while c.peek(sym['PHASE']) != 2:
        c.run_us(STEP)
        pc = c.pc
        name = '?'
        for a, nm in labels:
            if a > pc:
                break
            name = nm
        hits[name] += 1
        n += 1
    print('%.1f ms, %d δείγματα' % (n * STEP / 1000.0, n))
    for name, k in hits.most_common(25):
        print('%6.1f ms  %5.1f%%  %s' % (k * STEP / 1000.0, 100.0 * k / n, name))


if __name__ == '__main__':
    main()
