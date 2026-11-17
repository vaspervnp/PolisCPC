"""Profiler της παρτίδας αποδοχής (2026-11-17): πού πάει ο χρόνος στα καρέ
μονάδων ΜΕ κύλιση, όπως τα μετράει το m14_game_check (ο bot παίζει).

    python3 tests/profile_game.py [δευτερόλεπτα παρτίδας, 420] [κάθε N καρέ, 6]

Δειγματοληψία του PC κάθε STEP µs σε ένα στα N καρέ μονάδων· τα δείγματα
πάνε στο «με κύλιση» ή «χωρίς», ανάλογα με το αν κινήθηκε η κάμερα.
"""
import bisect
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.argv += ['--quiet']
import m14_game_check as G                      # noqa: E402
import m3_check as M3                           # noqa: E402
import m2_check as M2                           # noqa: E402

STEP = 10
UNTIL = int(sys.argv[1]) if sys.argv[1:2] and sys.argv[1].isdigit() else 420
EVERY = int(sys.argv[2]) if sys.argv[2:3] and sys.argv[2].isdigit() else 6
hits = {True: collections.Counter(), False: collections.Counter()}
frames = {True: [], False: []}
k = [0]


def main():
    c, sym = G.boot()
    labels = sorted((a, n) for n, a in sym.items() if a < 0x4000)
    addrs = [a for a, _ in labels]
    up = sym['UPHASE']
    plain = M3.tick_time

    def prof(c, sym):
        M3.wait_uphase(c, sym, 4)
        M3.wait_uphase(c, sym, 3)
        k[0] += 1
        cam = M2.cam(c, sym)
        if k[0] % EVERY:
            return M3.wait_uphase(c, sym, 4) / 1000.0
        h, n = collections.Counter(), 0
        while c.peek(up) != 4:
            c.run_us(STEP)
            i = bisect.bisect_right(addrs, c.pc) - 1
            h[labels[i][1] if i >= 0 else '?'] += 1
            n += 1
        s = M2.cam(c, sym) != cam
        hits[s].update(h)
        frames[s].append(n * STEP / 1000.0)
        return n * STEP / 1000.0

    M3.tick_time = prof
    bot = G.Bot(c, sym)
    while not bot.ended() and bot.sec() < UNTIL:
        bot.step()
        bot.tick(4)
    M3.tick_time = plain
    for s in (True, False):
        fs = frames[s]
        if not fs:
            continue
        tot = sum(hits[s].values())
        print('\n%s: %d καρέ, μέσος %.1f ms' % ('ΜΕ ΚΥΛΙΣΗ' if s else
                                              'χωρίς κύλιση', len(fs),
                                              sum(fs) / len(fs)))
        for name, n in hits[s].most_common(30):
            print('%6.2f ms  %5.1f%%  %s' % (n * STEP / 1000.0 / len(fs),
                                            100.0 * n / tot, name))


if __name__ == '__main__':
    main()
