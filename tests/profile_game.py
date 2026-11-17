"""Profiler της παρτίδας αποδοχής (2026-11-17): πού πάει ο χρόνος στα καρέ
μονάδων ΜΕ κύλιση, όπως τα μετράει το m14_game_check (ο bot παίζει). «Με κύλιση»
είναι και τα καρέ που ετοιμάζουν μια λωρίδα (h_pend, v_pend) χωρίς να
κινηθεί ακόμα η κάμερα.

    python3 tests/profile_game.py [δευτερόλεπτα παρτίδας, 420] [κάθε N καρέ, 6]

Και μια τρίτη ομάδα: τα καρέ χωρίς κύλιση πάνω από 40 ms (οι αιχμές), και
για αυτά και ανά ρουτίνα (χωρίς τις τοπικές ετικέτες).

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
import scene as S                               # noqa: E402

STEP = 10
UNTIL = int(sys.argv[1]) if sys.argv[1:2] and sys.argv[1].isdigit() else 420
EVERY = int(sys.argv[2]) if sys.argv[2:3] and sys.argv[2].isdigit() else 6
hits = {True: collections.Counter(), False: collections.Counter(),
        'peak': collections.Counter()}
frames = {True: [], False: [], 'peak': []}
worst = []                      # (ms, οι 6 βαρύτερες ρουτίνες), χωρίς κύλιση
k = [0]


def main():
    global bot
    c, sym = G.boot()
    labels = sorted((a, n) for n, a in sym.items() if a < 0x4000)
    addrs = [a for a, _ in labels]
    # 2026-11-17: ο κώδικας στο #4000-#7FFF (C7: AI, μάχη· C6: HUD) ανά
    # τράπεζα, από το polis.sym. Η τράπεζα που είναι μέσα: όποια έχει τα
    # ίδια bytes στο PC.
    paged = {}
    with open(os.path.join(HERE, '..', 'build', 'polis.sym')) as f:
        for ln in f:
            w = ln.split()
            if len(w) >= 3 and w[2][:1] == 'B' and w[2] != 'B0':
                a = int(w[1][1:], 16)
                if 0x4000 <= a < 0x8000:
                    paged.setdefault(int(w[2][1:]), []).append((a, w[0]))
    for b in paged:
        paged[b].sort()
    pa = {b: [a for a, _ in paged[b]] for b in paged}

    def where(pc):
        if pc < 0x4000 or pc >= 0x8000:
            i = bisect.bisect_right(addrs, pc) - 1
            return labels[i][1] if i >= 0 and pc < 0x4000 else '#%X' % (pc & 0xF000)
        from cpc import _lib
        cpu = bytes(_lib.cpcemu_mem_rd(c._h, pc + k) for k in range(4))
        for b in paged:
            if b == 4:                  # (B4: ο κώδικας της σελίδας του HUD,
                continue                # στη βάση: πιο κάτω)
            r = S.bank_ram(c, b)
            if bytes(r[pc - 0x4000 + k] for k in range(4)) == cpu:
                i = bisect.bisect_right(pa[b], pc) - 1
                if i >= 0:
                    return 'C%d:%s' % (b, paged[b][i][1])
        if bytes(S.bank_ram(c, 7)[pc - 0x4000 + k] for k in range(4)) == cpu:
            return 'C7:(μεταγλωττισμένα sprites)'
        if 4 in paged:
            i = bisect.bisect_right(pa[4], pc) - 1
            if i >= 0:
                return paged[4][i][1]
        return '#4000-#7FFF (βάση)'
    up = sym['UPHASE']
    plain = M3.tick_time

    def prof(c, sym):
        M3.wait_uphase(c, sym, 4)
        M3.wait_uphase(c, sym, 3)
        k[0] += 1
        cam = M2.cam(c, sym)
        pend = c.peek(sym['H_PEND']) | c.peek(sym['V_PEND'])
        if k[0] % EVERY:
            return M3.wait_uphase(c, sym, 4) / 1000.0
        h, n = collections.Counter(), 0
        while c.peek(up) != 4:
            c.run_us(STEP)
            h[where(c.pc)] += 1
            n += 1
        s = M2.cam(c, sym) != cam or \
            (c.peek(sym['H_PEND']) | c.peek(sym['V_PEND'])) > pend
        hits[s].update(h)
        frames[s].append(n * STEP / 1000.0)
        if not s and n * STEP > 40000:
            hits['peak'].update(h)
            frames['peak'].append(n * STEP / 1000.0)
            rt = collections.Counter()
            for name, m in h.items():
                rt[name.split('.')[0]] += m
            worst.append((n * STEP / 1000.0, bot.sec(),
                          [(nm, m * STEP / 1000.0) for nm, m in rt.most_common(6)]))
        return n * STEP / 1000.0

    M3.tick_time = prof
    bot = G.Bot(c, sym)
    while not bot.ended() and bot.sec() < UNTIL:
        bot.step()
        bot.tick(4)
    M3.tick_time = plain
    names = {True: 'ΜΕ ΚΥΛΙΣΗ', False: 'χωρίς κύλιση',
             'peak': 'ΑΙΧΜΕΣ (χωρίς κύλιση, > 40 ms)'}
    for s in (True, False, 'peak'):
        fs = frames[s]
        if not fs:
            continue
        tot = sum(hits[s].values())
        print('\n%s: %d καρέ, μέσος %.1f ms, μέγιστος %.1f'
              % (names[s], len(fs), sum(fs) / len(fs), max(fs)))
        for name, n in hits[s].most_common(30):
            print('%6.2f ms  %5.1f%%  %s' % (n * STEP / 1000.0 / len(fs),
                                            100.0 * n / tot, name))
        if s == 'peak':
            rt = collections.Counter()
            for name, n in hits[s].items():
                rt[name.split('.')[0]] += n
            print('  ανά ρουτίνα:')
            for name, n in rt.most_common(25):
                print('%6.2f ms  %5.1f%%  %s' % (n * STEP / 1000.0 / len(fs),
                                                100.0 * n / tot, name))


def show_worst():
    print('\nτα 12 χειρότερα καρέ χωρίς κύλιση:')
    for ms, sec, top in sorted(worst, reverse=True)[:12]:
        print('%5.1f ms (στα %d s): %s' % (ms, sec, ', '.join(
            '%s %.1f' % t for t in top)))


if __name__ == '__main__':
    main()
    show_worst()
