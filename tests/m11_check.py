"""M11: ομίχλη και μίνι χάρτης — σε headless CPC 6128.

    python3 tests/m11_check.py [--shots]

Με την ομίχλη (fog_on = 1), χωρίς τον αντίπαλο να σκέφτεται:

1. ΑΡΧΗ. Ο εξερευνημένος χάρτης είναι ΑΚΡΙΒΩΣ τα τετράγωνα ±FOG_R γύρω από
   τα 9 σημεία του Κέντρου Πόλης και γύρω από κάθε μονάδα του παίκτη· το
   Κέντρο του αντιπάλου ανεξερεύνητο.
2. ΟΘΟΝΗ. Pixel προς pixel = ο κόσμος του mockup όπου το ανεξερεύνητο είναι
   μαύρο (χωρίς έδαφος, πόρο ή κτίριο), με τις μονάδες του ORDER.
3. ΚΡΥΦΕΣ. Καμία μονάδα που δεν είναι του παίκτη, με τα πόδια σε
   ανεξερεύνητο πλακίδιο, δεν ζωγραφίζεται (U_SY = 255, όχι στο ORDER).
4. ΜΙΝΙ ΧΑΡΤΗΣ. Τα pixels του ρόμβου στη σελίδα του HUD = το μοντέλο:
   χρώμα εδάφους/δέντρου στο εξερευνημένο, μαύρο στο ανεξερεύνητο, και το
   πλαίσιο της κάμερας.
5. ΑΠΟΚΑΛΥΨΗ. Ένας στρατιώτης στέλνεται στην ομίχλη: όσο περπατάει ο
   χάρτης μόνο μεγαλώνει, και όταν φτάσει το ±FOG_R γύρω του είναι
   εξερευνημένο· η οθόνη (μόλις αδειάσει το FD_TAB) = ο νέος κόσμος.
6. ΔΕΝ ΞΕΧΝΙΕΤΑΙ. Γυρίζει πίσω: τίποτα από όσα είδε δεν ξανακρύβεται.
7. ΚΥΛΙΣΗ. Η κάμερα κυλάει προς τα νέα πλακίδια και πίσω: η οθόνη = ο
   κόσμος με την ομίχλη (λωρίδες, στήλες).
8. ΜΙΝΙ ΧΑΡΤΗΣ ξανά, με τα νέα πλακίδια και την κάμερα αλλού.
9. ΧΡΟΝΟΣ — μέτρηση: το χειρότερο καρέ μονάδων όσο αποκαλύπτεται.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m5_check as M5                           # noqa: E402
import m6_check as M6                           # noqa: E402
import scene as S                               # noqa: E402

FOG_R = 4
TC = (30, 58)
AI_TC = (58, 27)
MAP, MAPW = 0x8000, 96
FD_TAB, FD_N = 0xAD60, 26
HUD_PAGE, VIEW_H = 0x4000, 144
TARGET = (48, 58)               # στην ομίχλη, ανατολικά της πόλης (στην οθόνη)
SOLDIER = 2


def mm_consts():
    """Οι σταθερές και οι πίνακες του data/minimap.asm."""
    d = {}
    for line in open(os.path.join(HERE, '..', 'data', 'minimap.asm')):
        line = line.split(';')[0]
        if ' equ ' in line:
            k, v = line.split(' equ ')
            d[k.strip()] = int(v)
        elif ' db ' in line:
            k, v = line.split(' db ')
            d[k.strip().rstrip(':')] = [int(x.strip().replace('#', '0x'), 0) for x in v.split(',')]
    return d


MMC = mm_consts()
MM_X, MM_Y, MM_N = MMC['MM_X'], MMC['MM_Y'], MMC['MM_N']


def square(i, j, seen):
    for jj in range(max(0, j - FOG_R), min(MAPW, j + FOG_R + 1)):
        for ii in range(max(0, i - FOG_R), min(MAPW, i + FOG_R + 1)):
            seen[jj][ii] = True


def clamp(v):
    return max(0, min(MAPW - 1, v))


def initial_fog(c):
    seen = [[False] * MAPW for _ in range(MAPW)]
    for d in range(TC[0] - 2, TC[0] + 7, 4):
        for e in range(TC[1] - 2, TC[1] + 7, 4):
            square(d, e, seen)
    for u in S.units(c):
        if u['team'] == 0:
            i, j = M5.unit_tile(u)
            square(clamp(i), clamp(j), seen)
    return seen


def count(seen):
    return sum(map(sum, seen))


def subset(a, b):
    return all(b[j][i] for j in range(MAPW) for i in range(MAPW) if a[j][i])


def mm_model(c, sym, seen):
    """Ο ρόμβος όπως τον γράφουν το mm_line και το mm_rect: [my][k]."""
    blob = c.read_ram(MAP, MAPW * MAPW)
    F = MMC['mm_f']
    rows = []
    for my in range(MM_N + 1):
        row = []
        for k in range(MM_N):
            u, v = my - 9 + k, my + 10 - k
            if not (0 <= u < MM_N and 0 <= v < MM_N):
                row.append(MMC['MM_BG'])
                continue
            i, j = F[u], F[v]
            if not seen[j][i]:
                row.append(0)
                continue
            b = blob[j * MAPW + i]
            pen = MMC['mm_res'][b & 15]
            row.append(MMC['mm_ter'][b >> 4] if pen == 255 else pen)
        rows.append(row)
    cx, cy = M2.cam(c, sym)
    kx = lambda x: MM_X - 20 + (5 * (x - 192) + 48 + 20 * 96) // 96  # noqa
    ky = lambda y: MM_Y + (5 * y + 96) // 192                        # noqa
    x0, x1, y0, y1 = kx(cx), kx(cx + 80), ky(cy), ky(cy + VIEW_H)
    for my in range(MM_N + 1):
        y = MM_Y + my
        if y in (y0, y1):
            xs = range(x0, x1 + 1)
        elif y0 < y < y1:
            xs = (x0, x1)
        else:
            continue
        for x in xs:
            k = x - (MM_X - MM_N // 2)
            if 0 <= k < MM_N:
                rows[my][k] = MMC['MM_FRAME']
    return rows


def pen_of(b, right):
    if right:
        b <<= 1
    return (b >> 7 & 1) | (b >> 3 & 1) << 1 | (b >> 5 & 1) << 2 | \
        (b >> 1 & 1) << 3


def mm_screen(c):
    rows = []
    for my in range(MM_N + 1):
        y = MM_Y + my - VIEW_H
        base = HUD_PAGE + (y & 7) * 0x800 + (y >> 3) * 80
        row = []
        for k in range(MM_N):
            x = MM_X - MM_N // 2 + k
            row.append(pen_of(c.peek(base + (x >> 1)), x & 1))
        rows.append(row)
    return rows


def fd_empty(c):
    b = c.read_ram(FD_TAB, FD_N * 6)
    return all(b[k] == 255 and b[k + 1] == 255 for k in range(0, FD_N * 6, 6))


def settle(g, n=200):
    """Ώσπου να αδειάσει το FD_TAB (οι στήλες των νέων πλακιδίων)."""
    for _ in range(n):
        if fd_empty(g.c):
            return True
        g.tick(1)
    return fd_empty(g.c)


def hidden_ok(c, seen):
    """(πλήθος κρυμμένων στην ομίχλη, πλήθος λαθών)."""
    n = bad = 0
    for u in S.units(c):
        if u['team'] == 0 or u['team'] & 0x80:
            continue
        i, j = M5.unit_tile(u)
        if 0 <= i < MAPW and 0 <= j < MAPW and seen[j][i]:
            continue
        n += 1
        if u['sy'] != 255:
            bad += 1
    return n, bad


def compose(g, name):
    g.world = M.game_world(seen=S.fog_seen(g.c))
    return g.compose(name)


def mm_check(g, name, what):
    g.tick(MM_N + 3)                    # μία γραμμή ανά καρέ μονάδων
    seen = S.fog_seen(g.c)
    exp, got = mm_model(g.c, g.sym, seen), mm_screen(g.c)
    bad = sum(1 for a, b in zip(exp, got) for p, q in zip(a, b) if p != q)
    g.report(name, bad == 0, '%s: %d / %d pixels διαφέρουν'
             % (what, bad, (MM_N + 1) * MM_N))
    if bad:
        for a, b in zip(exp, got):
            print('   ', ''.join('%x' % p for p in a), ''.join('%x' % q for q in b))


def main():
    g = M4.Game('--shots' in sys.argv, fog=True)
    c, sym = g.c, g.sym
    g.tick(3)

    # ------------------------------------------------------------ 1. αρχή
    seen = S.fog_seen(c)
    exp = initial_fog(c)
    g.report('ΑΡΧΗ', seen == exp and not seen[AI_TC[1]][AI_TC[0]],
             '%d πλακίδια εξερευνημένα (μοντέλο %d), του αντιπάλου %s'
             % (count(seen), count(exp),
                'κρυφό' if not seen[AI_TC[1]][AI_TC[0]] else 'ΦΑΝΕΡΟ'))

    # ------------------------------------------------------------ 2. οθόνη
    g.report('ΟΘΟΝΗ', compose(g, 'm11_start'), 'αρχή, με την ομίχλη')

    # ------------------------------------------------------------ 3. κρυφές
    n, bad = hidden_ok(c, seen)
    g.report('ΚΡΥΦΕΣ', bad == 0, '%d ξένες μονάδες στην ομίχλη, %d φαίνονται'
             % (n, bad))

    # ------------------------------------------------------- 4. μίνι χάρτης
    mm_check(g, 'ΜΙΝΙ', 'αρχή')

    # ------------------------------------------------------- 5. αποκάλυψη
    seen0 = S.fog_seen(c)
    g.times = []
    M6.click_unit(g, SOLDIER)
    M6.command(g, TARGET)
    grows, prev, arrived, last = True, seen0, False, None
    for _ in range(400):
        g.tick(1)
        now = S.fog_seen(c)
        grows &= subset(prev, now)
        prev = now
        u = S.unit(c, SOLDIER)
        pos = (u['wx'], u['wy'])
        if M5.unit_tile(u) == TARGET and pos == last:   # εκεί, και στάθηκε
            arrived = True
            break
        last = pos
    walk_times = list(g.times)
    i, j = M5.unit_tile(S.unit(c, SOLDIER))
    near = [[False] * MAPW for _ in range(MAPW)]
    square(clamp(i), clamp(j), near)
    seen1 = S.fog_seen(c)
    g.report('ΑΠΟΚ', arrived and grows and subset(near, seen1)
             and count(seen1) > count(seen0),
             'έφτασε στο (%d,%d)%s, %d -> %d πλακίδια, ποτέ λιγότερα: %s'
             % (i, j, '' if arrived else ' (ΔΕΝ ΕΦΤΑΣΕ)', count(seen0),
                count(seen1), grows))
    flushed = settle(g)
    g.report('ΟΘΟΝΗ', flushed and compose(g, 'm11_reveal'),
             'μετά την αποκάλυψη (FD_TAB %s)'
             % ('άδειο' if flushed else 'ΓΕΜΑΤΟ'))
    n, bad = hidden_ok(c, S.fog_seen(c))
    g.report('ΚΡΥΦΕΣ', bad == 0, '%d ξένες μονάδες στην ομίχλη, %d φαίνονται'
             % (n, bad))

    # ------------------------------------------------- 6. δεν ξεχνιέται
    M6.command(g, (TC[0] + 6, TC[1] - 1))
    last = None
    for _ in range(400):
        g.tick(1)
        u = S.unit(c, SOLDIER)
        if (u['wx'], u['wy']) == last:
            break
        last = (u['wx'], u['wy'])
    seen2 = S.fog_seen(c)
    g.report('ΜΝΗΜΗ', subset(seen1, seen2),
             'γύρισε πίσω: %d πλακίδια, όσα είδε όλα ακόμα εξερευνημένα'
             % count(seen2))

    # ------------------------------------------------------------ 7. κύλιση
    for keys, n, what in (('RU', 10, 'πάνω-δεξιά'), ('LD', 10, 'πίσω')):
        g.hold([M2.KEYS[k] for k in keys], n)
        g.tick(30)                      # (ό,τι ζωγραφίζεται σε δόσεις)
        cx, cy = M2.cam(c, sym)
        g.report('ΚΥΛΙΣΗ', compose(g, 'm11_scroll_' + keys),
                 '%s, κάμερα (%d,%d)' % (what, cx, cy))
        if keys == 'RU':
            mm_check(g, 'ΜΙΝΙ', 'με τα νέα πλακίδια, κάμερα (%d,%d)'
                     % (cx, cy))

    # ------------------------------------------------------------ 9. χρόνος
    print('ΧΡΟΝΟΣ   μέτρηση   όσο αποκαλύπτει: μέγιστο %.1f ms, μέσο %.1f ms,'
          ' %d καρέ > 40 ms' % (max(walk_times),
                                 sum(walk_times) / len(walk_times),
                                 sum(1 for t in walk_times if t > 40)))
    print('M11', 'OK' if g.ok else 'ΑΠΟΤΥΧΙΑ')
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
