"""M6: πόροι και χωρικοί — σε headless CPC 6128.

    python3 tests/m6_check.py [--shots]

Με τα πλήκτρα του παίκτη (Q A O P, SPACE, RETURN, βελάκια), οι 4 χωρικοί
της πόλης (μονάδες 0, 3, 6, 9) στέλνονται σε 3 πηγές: δύο στους θάμνους
μούρων, ένας στα δέντρα, και, αφού κυλήσει λίγο η κάμερα, ένας στον χρυσό.

1. ΑΡΧΗ. Οι 6 αριθμοί της μπάρας του HUD είναι, pixel προς pixel, οι τιμές
   της hud_val (200 200 100 200 12 1) με τα ψηφία του mockup.
2. ΤΑΥΤΟΧΡΟΝΑ. Κάποια στιγμή και οι 4 δουλεύουν (μαζεύουν ή πηγαινοέρχονται)
   σε 3 διαφορετικές πηγές· καθένας αδειάζει φορτίο ≥ 2 φορές.
3. ΟΙ ΑΡΙΘΜΟΙ. Σε ΚΑΘΕ καρέ, η μπάρα = αρχή + ό,τι αδειάστηκε ως τότε, ανά
   είδος (κάθε άδειασμα το βλέπει ο έλεγχος: φορτίο -> 0 στο σημείο
   απόθεσης). Και διατήρηση: ό,τι λείπει από τις πηγές = ό,τι αδειάστηκε +
   ό,τι κουβαλάνε. Στο τέλος η μπάρα στην οθόνη δείχνει τις νέες τιμές.
4. ΕΜΠΟΔΙΑ, ΧΡΟΝΟΣ. Κανένας χωρικός δεν πατάει σε εμπόδιο· κάθε καρέ χωρίς
   κύλιση < 40 ms.
5. ΑΔΕΙΑΣΜΑ. Οι θάμνοι μένουν με 3 μονάδες: όταν τελειώσουν, το πλακίδιο
   γίνεται «θάμνος άδειος» και ξαναζωγραφίζεται ΜΟΝΟ το κομμάτι του (οθόνη
   και καθρέφτης)· η οθόνη είναι ακριβώς το mockup με αυτή την αλλαγή, με
   τις μονάδες από πάνω, και μετά το σβήσιμο των μονάδων ακριβώς το φόντο.
   Οι δύο χωρικοί αδειάζουν ό,τι κουβαλάνε και μένουν αδρανείς.
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m4_check as M4                           # noqa: E402
import m5_check as M5                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import make_map as MM                           # noqa: E402
import terrain as T                             # noqa: E402

U_JOB = 27
J_GO, J_WORK, J_BACK = 1, 2, 3
J_CARRY, J_KIND, J_SI, J_SJ = 0x7700, 0x7780, 0x7F00, 0x7F80
SRC_TAB, SRC_N = 0x6F00, 32
HUD_PAGE = 0x4000
VILLAGERS = (0, 3, 6, 9)
KIND_NAME = ('τροφή', 'ξύλο', 'χρυσό', 'πέτρα')
RES = {k: i for i, (k, _, _, _, _) in enumerate(T.RESOURCES)}

BERRIES, TREE, GOLD = (37, 52), (31, 75), (46, 50)


def word(c, a):
    return c.peek(a) | c.peek(a + 1) << 8


def hud_vals(c, sym):
    return [word(c, sym['HUD_VAL'] + 2 * k) for k in range(6)]


def hud_ok(c, vals):
    """Οι αριθμοί της μπάρας στη σελίδα του HUD = οι τιμές, με τα ψηφία."""
    glyph = MM.digit_glyphs()
    for x, v in zip(MM.BAR_X, vals):
        ds = [10 if ch == ' ' else int(ch) for ch in str(min(v, 9999)).rjust(4)]
        for k, d in enumerate(ds):
            for l in range(5):
                y = MM.BAR_Y + l
                a = HUD_PAGE + (y & 7) * 0x800 + (y >> 3) * 80 + x + 2 * k
                if list(c.read_ram(a, 2)) != glyph[d * 10 + 2 * l:
                                                     d * 10 + 2 * l + 2]:
                    return False
    return True


def tile_cursor(g, i, j):
    """Μια θέση του κέρσορα (με την ίδια ισοτιμία βήματος) που πέφτει στο
    πλακίδιο (i, j), όσο πιο κοντά στο κέντρο του."""
    c, sym = g.c, g.sym
    cx, cy = M4.M2.cam(c, sym)
    x0, y0 = g.cursor()
    fx, fy = 2 * (i - j) + 192, 4 * (i + j) + 4
    best = None
    for x in range(x0 % 2, 77, 2):
        for y in range(y0 % 6, 129, 6):
            if M5.feet_tile(cx + x, cy + y) == (i, j):
                d = abs(cx + x - fx) * 2 + abs(cy + y - fy)
                if best is None or d < best[0]:
                    best = (d, x, y)
    assert best, 'το πλακίδιο %s δεν φαίνεται' % ((i, j),)
    return best[1], best[2]


def click_unit(g, k):
    c = g.c
    u = S.unit(c, k)
    x0, y0 = g.cursor()
    g.move_cursor(u['sx'] + (x0 - u['sx']) % 2, u['sy'] + (y0 - u['sy']) % 6)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(2)
    return {v['idx'] for v in S.units(c) if v['fl'] & S.F_SEL}


def command(g, tile):
    g.move_cursor(*tile_cursor(g, *tile))
    g.c.key_down(CPCMOD.KEY_RETURN)
    g.tick(1)
    g.c.key_up(CPCMOD.KEY_RETURN)
    g.tick(1)


class Watch:
    """Παρακολουθεί τους χωρικούς καρέ προς καρέ: αδειάσματα, μπάρα, εμπόδια."""

    def __init__(self, g, nav):
        self.g, self.nav = g, nav
        self.base = hud_vals(g.c, g.sym)
        self.dep = [0] * 4                      # αδειάστηκαν, ανά είδος
        self.trips = collections.Counter()      # αδειάσματα ανά χωρικό
        self.prev = {}
        self.bad_hud = []
        self.on_block = []
        self.together = 0                       # καρέ: 4 δουλεύουν, 3 πηγές
        self.pos = {}

    def state(self, v):
        c = self.g.c
        return (c.peek(S.UNIT_TAB + v * S.U_SIZE + U_JOB), c.peek(J_CARRY + v),
                c.peek(J_KIND + v), (c.peek(J_SI + v), c.peek(J_SJ + v)))

    def tick(self, n=1):
        g, c = self.g, self.g.c
        for _ in range(n):
            g.tick(1)
            jobs = {}
            for v in VILLAGERS:
                job, carry, kind, src = self.state(v)
                pj, pc, pk, _ = self.prev.get(v, (0, 0, 0, None))
                if pj == J_BACK and pc and carry == 0:
                    self.dep[pk] += pc
                    self.trips[v] += 1
                self.prev[v] = (job, carry, kind, src)
                if job:
                    jobs[v] = src
                u = S.unit(c, v)
                p = (u['wx'], u['wy'])
                if p != self.pos.get(v) and self.nav.blocked(*M5.unit_tile(u)):
                    self.on_block.append((v, p))
                self.pos[v] = p
            if len(jobs) == 4 and len(set(jobs.values())) == 3:
                self.together += 1
            want = [b + d for b, d in zip(self.base, self.dep)] + self.base[4:]
            got = hud_vals(c, g.sym)
            if got != want and len(self.bad_hud) < 3:
                self.bad_hud.append((len(g.times), got, want))


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    nav = M5.Nav()
    blob = nav.blob

    start = hud_vals(c, sym)
    g.report('μπάρα', start == [200, 200, 100, 200, 12, 1] and
             hud_ok(c, start), 'αρχή: %s, στην οθόνη με τα ψηφία του mockup'
             % ' '.join(map(str, start)))
    w = Watch(g, nav)
    w.tick(3)                               # οι μονάδες στη θέση τους (SX, SY)

    # ------------------------------------------------- οι εντολές
    plan = [(0, BERRIES), (3, BERRIES), (6, TREE)]
    for v, tile in plan:
        sel = click_unit(g, v)
        g.report('κλικ', sel == {v}, 'χωρικός %d επιλεγμένος' % v)
        command(g, tile)
        w.tick(1)
    c.key_down(CPCMOD.KEY_RIGHT)            # ο χρυσός είναι δεξιά της οθόνης
    while M4.M2.cam(c, sym)[0] < 114:
        w.tick(1)
    c.key_up(CPCMOD.KEY_RIGHT)
    w.tick(2)
    sel = click_unit(g, 9)
    g.report('κλικ', sel == {9}, 'χωρικός 9 επιλεγμένος (κάμερα %s)'
             % (M4.M2.cam(c, sym),))
    command(g, GOLD)
    jobs = {v: w.state(v) for v in VILLAGERS}
    srcs = {v: s[3] for v, s in jobs.items()}
    g.report('δουλειά', all(s[0] for s in jobs.values()) and srcs ==
             {0: BERRIES, 3: BERRIES, 6: TREE, 9: GOLD},
             'πηγές %s, είδη %s' % (srcs, {v: KIND_NAME[s[2]]
                                          for v, s in jobs.items()}))

    # ------------------------------------------------- δουλεύουν
    for k in range(2400):
        w.tick(1)
        if min(w.trips[v] for v in VILLAGERS) >= 2:
            break
    g.report('ταυτόχρονα', w.together > 0, '%d καρέ με και τους 4 σε δουλειά, '
             'σε 3 πηγές' % w.together)
    g.report('φορτία', min(w.trips[v] for v in VILLAGERS) >= 2,
             'σε %d καρέ, αδειάσματα ανά χωρικό %s'
             % (k + 1, dict(sorted(w.trips.items()))))
    vals = hud_vals(c, sym)
    g.report('αριθμοί', not w.bad_hud and vals[:4] != start[:4],
             'σε κάθε καρέ μπάρα = αρχή + αδειάσματα: %s -> %s%s'
             % (start[:4], vals[:4], '' if not w.bad_hud
                else ' — ΛΑΘΟΣ %s' % w.bad_hud))

    def sources():
        out = {}
        for e in range(SRC_N):
            b = c.read_ram(SRC_TAB + 4 * e, 4)
            if b[1] != 0xFF:
                off = b[0] | b[1] << 8
                out[(off % 96, off // 96)] = b[2] | b[3] << 8
        return out
    srctab = sources()
    taken = sum(MM.T.RESOURCES[blob[j * 96 + i] & 15][4] - a
                for (i, j), a in srctab.items())
    carry = sum(c.peek(J_CARRY + v) for v in VILLAGERS)
    g.report('διατήρηση', taken == sum(w.dep) + carry and
             set(srctab) == {BERRIES, TREE, GOLD},
             'από τις πηγές λείπουν %d = %d αδειάστηκαν + %d κουβαλάνε'
             % (taken, sum(w.dep), carry))
    g.report('οθόνη', hud_ok(c, vals), 'η μπάρα δείχνει %s'
             % ' '.join(map(str, vals)))

    # ------------------------------------------------- άδειασμα
    for e in range(SRC_N):
        b = c.read_ram(SRC_TAB + 4 * e, 2)
        if b[1] != 0xFF and (b[0] | b[1] << 8) == BERRIES[1] * 96 + BERRIES[0]:
            c.poke(SRC_TAB + 4 * e + 2, 3)
            c.poke(SRC_TAB + 4 * e + 3, 0)
    mb = sym['MAP'] if 'MAP' in sym else 0x8000
    at = mb + BERRIES[1] * 96 + BERRIES[0]
    for k in range(400):
        w.tick(1)
        if c.peek(at) & 15 != RES['berry_bush']:
            break
    gone = c.peek(at) & 15 == RES['bush_empty']
    t_gone = len(g.times)
    for k2 in range(800):
        w.tick(1)
        if all(w.state(v)[0] == 0 and w.state(v)[1] == 0 for v in (0, 3)):
            break
    idle = [w.state(v)[:2] for v in (0, 3)]
    if idle != [(0, 0), (0, 0)]:
        for v in (0, 3):
            u = S.unit(c, v)
            b = c.read_ram(S.UNIT_TAB + v * S.U_SIZE, S.U_SIZE)
            print('      %d: θέση (%d,%d) στόχος (%d,%d) fl %02X sy %d field %d '
                  'wf %02X stuck %d' % (v, u['wx'], u['wy'], u['tx'], u['ty'],
                                        u['fl'], u['sy'], b[24], b[15], b[29]))
    g.report('άδειασε', gone and idle == [(0, 0), (0, 0)] and not w.bad_hud,
             'το πλακίδιο έγινε θάμνος άδειος σε %d καρέ· οι 0 και 3 '
             'αδειάζουν και μένουν αδρανείς σε %d (δουλειά, φορτίο: %s)'
             % (k + 1, k2 + 1, idle))
    grd, res = M4.M.mockup.make_map()
    res[BERRIES[1]][BERRIES[0]] = 'bush_empty'
    g.world = M4.M.mockup.render_world(grd, res, towns=False)
    M4.M.wait_phase(c, sym, 6)
    w.tick(1)
    g.report('χάρτης', g.compose('depleted'), 'η οθόνη = το mockup με τον '
             'άδειο θάμνο, με τις μονάδες από πάνω')

    g.report('εμπόδια', not w.on_block, 'κανένας χωρικός σε εμπόδιο%s'
             % ('' if not w.on_block else ': %s' % w.on_block[:3]))
    still = [t for t, m in zip(g.times, g.scrolled) if not m]
    g.report('χρόνος', max(still) < 40, 'καρέ χωρίς κύλιση: μέσος %.1f ms, '
             'μέγιστος %.1f ms (όριο 40), %d καρέ'
             % (sum(still) / len(still), max(still), len(still)))
    print('χρόνος   %-9s το καρέ του αδειάσματος (2 κομμάτια στήλης + '
          'καθρέφτης): %.1f ms' % ('<40' if g.times[t_gone - 1] < 40 else 'ΠΑΝΩ',
                                  g.times[t_gone - 1]))
    c.poke(sym['ERASE_REQ'], 1)             # ο καθρέφτης: ξανά ακριβώς το φόντο
    M4.M3.wait_uphase(c, sym, 3)
    M4.M3.wait_uphase(c, sym, 4)
    cx, cy = M4.M2.cam(c, sym)
    g.report('σβήσιμο', M4.M2.diff(M4.M2.decode_scrolled(c, sym),
                                   M4.M.reference(g.world, cx, cy), 'm6_erased',
                                   c, g.shots),
             'χωρίς μονάδες, η οθόνη (από τον καθρέφτη) = το mockup με τον '
             'άδειο θάμνο')
    if g.shots:
        c.screenshot(os.path.join(M4.M.BUILD, 'm6_gather.png'), aspect=True)
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
