"""Στατιστικός profiler: δειγματοληψία του PC του Z80 στον headless emulator.

    python3 tests/profile.py [cam_x cam_y]     # πλήρης σχεδίαση παραθύρου
    python3 tests/profile.py units             # 20 καρέ μονάδων (M3)

Κάθε 7 µs γράφει πού είναι ο PC. Τα δείγματα αντιστοιχίζονται στο πλησιέστερο σύμβολο από κάτω (τοπικές
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


def sample(c, sym, labels, hits, until):
    n = 0
    while not until():
        c.run_us(STEP)
        pc = c.pc
        name = '?'
        for a, nm in labels:
            if a > pc:
                break
            name = nm
        hits[name] += 1
        n += 1
    return n


def report(hits, n, runs=1):
    print('%.1f ms ανά εκτέλεση, %d δείγματα' % (n * STEP / 1000.0 / runs, n))
    for name, k in hits.most_common(25):
        print('%6.2f ms  %5.1f%%  %s'
              % (k * STEP / 1000.0 / runs, 100.0 * k / n, name))


def main():
    sym = M.symbols()
    labels = sorted((a, n) for n, a in sym.items() if a < 0x4000)
    c = CPC()
    c.run_frames(5)
    c.quickload(os.path.join(M.BUILD, 'polis.sna'))
    M.wait_phase(c, sym, 6)
    if sys.argv[1:2] == ['units']:
        hits, n = collections.Counter(), 0
        for _ in range(20):
            while c.peek(sym['UPHASE']) != 4:
                c.run_us(50)
            while c.peek(sym['UPHASE']) != 3:
                c.run_us(20)
            n += sample(c, sym, labels, hits,
                        lambda: c.peek(sym['UPHASE']) == 4)
        report(hits, n, 20)
        return
    cx, cy = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 \
        else (98, 303)
    c.poke(sym['PHASE'], 0)
    for k, v in ((sym['CAM_X'], cx), (sym['CAM_Y'], cy & 0xFFFF)):
        c.poke(k, v & 0xFF)
        c.poke(k + 1, v >> 8)
    c.poke(sym['REDRAW'], 1)
    M.wait_phase(c, sym, 1)
    hits = collections.Counter()
    n = sample(c, sym, labels, hits, lambda: c.peek(sym['PHASE']) == 2)
    report(hits, n)


if __name__ == '__main__':
    main()
