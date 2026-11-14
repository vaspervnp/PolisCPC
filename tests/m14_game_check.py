"""M14, η αποδοχή: η δισκέτα από ψυχρή εκκίνηση, και μια παρτίδα ως το τέλος.

    python3 tests/m14_game_check.py [--shots] [--quiet]

Σε headless CPC 6128, RUN"POLIS και PLAY: η παρτίδα όπως την παίρνει ο
παίκτης, ΧΩΡΙΣ καμία αλλαγή στη μνήμη (ούτε κύματα νωρίτερα, ούτε
στρατιώτες δίπλα στον στόχο, ούτε στόχοι «σχεδόν»).

1. ΗΤΤΑ. Ο παίκτης δεν αγγίζει τίποτα: τα κύματα του αντιπάλου τελειώνουν
   την παρτίδα (game_end = 2) — χωρίς κόλλημα: ως τότε ο χρόνος της πίστας
   (lv_sec) προχωράει.
2. ΝΙΚΗ. Ένας «παίκτης» στην Python παίζει ΜΟΝΟ με πλήκτρα (Q A O P, SPACE,
   RETURN, τα γράμματα των κτιρίων, T, τα βελάκια), και διαβάζει τη μνήμη
   μόνο για να αποφασίσει — ό,τι θα έβλεπε στην οθόνη: χωρικοί στα μούρα,
   στο ξύλο και στον χρυσό, χωρικοί από το Κέντρο, σπίτια, στρατώνας,
   σπαθοφόροι συγκεντρωμένοι βορειοανατολικά της πόλης, και μετά
   επίθεση στο Κέντρο του αντιπάλου και κυνήγι όσων μείνουν. Η παρτίδα
   πρέπει να τελειώσει με νίκη (game_end = 1) πριν το LIMIT.
3. ΧΡΟΝΟΣ — μέτρηση: τα καρέ μονάδων όλης της νίκης.
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
import m12_check as M12                         # noqa: E402
import scene as S                               # noqa: E402
import cpc as CP                                # noqa: E402
import make_map as MM                           # noqa: E402

U_JOB, U_TEAM = 27, 28
J_KIND = 0x7780                 # game/gather.asm: 0 τροφή, 1 ξύλο, 2 χρυσός
TC = (31, 59)                   # το Κέντρο του παίκτη (30, 58), 4 x 4
AI_TC = (59, 28)                # του αντιπάλου (58, 27): το κέντρο του
SRC = {0: {'berry_bush', 'farm_plot', 'fish', 'gazelle'}, 1: {'tree', 'tree_pine', 'tree_palm'},
       2: {'gold_rock'}}                  # τροφή, ξύλο, χρυσός
MAP = 0x8000                    # 96 x 96: low nibble = ο πόρος (make_map.py)
WANT = {0: 6, 1: 2, 2: 3}       # χωρικοί ανά πόρο (το ξύλο: 1 όταν περισσεύει)
BARRACKS = [(35, 67), (36, 63), (33, 70), (38, 66), (28, 68), (39, 62)]
HOUSES = [(27, 63), (25, 60), (27, 66), (24, 63), (28, 53), (25, 56),
          (22, 60), (30, 66), (22, 64), (33, 53)]
STORE = [(44, 52), (48, 53), (43, 48), (49, 47)]   # αποθήκη δίπλα στον χρυσό
RALLY = (36, 57)                # στον δρόμο των κυμάτων (από το (44, 56))
ECON = [(24, 54), (22, 58), (26, 69), (22, 66), (34, 71), (30, 70),
        (21, 62), (37, 70), (24, 72), (19, 58), (28, 74), (33, 74)]
ARMY = 12                       # σπαθοφόροι για την επίθεση (ο αμυνόμενος
                                # πλεονεκτεί: χτυπάει πρώτος)
FIRST = 330                     # s: μετά το πρώτο κύμα (στα 300)
VIL_MAX = 10
LIMIT = 2400                    # s της πίστας
QUIET = '--quiet' in sys.argv
OK = True


def report(name, good, what):
    global OK
    print('%-8s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    OK &= bool(good)


def log(*a):
    if not QUIET:
        print('   ', *a, flush=True)


def boot():
    """RUN"POLIS, PLAY (το πρώτο του μενού)."""
    sym = M.symbols()
    c = M12.boot(os.path.join(M.BUILD, 'polis.dsk'), [CP.KEY_RETURN])
    M.wait_phase(c, sym, 6, limit_ms=20000)
    return c, sym


def c7w(c, sym, name):
    b = S.c7_read(c, sym[name], 2)
    return b[0] | b[1] << 8


def tile_xy(i, j):
    """Το κέντρο του πλακιδίου στον κόσμο (bytes, γραμμές)."""
    return 2 * (i - j) + 192, 4 * (i + j) + 4


class Bot:
    def __init__(self, c, sym):
        g = M4.Game.__new__(M4.Game)
        g.c, g.sym, g.shots, g.times, g.scrolled, g.ok = c, sym, False, [], \
            [], True
        self.g, self.c, self.sym = g, c, sym
        g.tick = self.tick              # (και ο κέρσορας: μετά το τέλος, καρέ)
        self.house_i = 0
        self.bar_i = 0
        self.store_i = 0
        self.econ_i = 0
        self.ordered = 0
        self.attacking = False
        self.events = []

    # ---------------------------------------------------- χρόνος, κατάσταση
    def tick(self, n=1):
        for _ in range(n):
            if self.c.peek(self.sym['GAME_END']):
                self.c.run_frames(2)
                continue
            cam = M2.cam(self.c, self.sym)
            try:
                self.g.times.append(M3.tick_time(self.c, self.sym))
            except RuntimeError:
                continue
            self.g.scrolled.append(M2.cam(self.c, self.sym) != cam)

    def sec(self):
        return c7w(self.c, self.sym, 'LV_SEC')

    def ended(self):
        return self.c.peek(self.sym['GAME_END'])

    def mine(self):
        return [u for u in S.units(self.c) if u['team'] == 0 and
                not u['fl'] & S.F_WANDER]

    def enemies(self):
        return [u for u in S.units(self.c) if u['team'] == 1 and
                not u['fl'] & S.F_WANDER]

    def source(self, k):
        """Το πλακίδιο της κοντινότερης στο Κέντρο ζωντανής πηγής του πόρου
        k, από τον χάρτη της μνήμης (οι άδειες αλλάζουν πόρο)."""
        m = self.c.read_ram(MAP, 96 * 96)
        best = None
        for j in range(TC[1] - 24, TC[1] + 24):
            for i in range(TC[0] - 24, TC[0] + 24):
                if 0 <= i < 96 and 0 <= j < 96 and \
                        MM.T.RESOURCES[m[j * 96 + i] & 15][0] in SRC[k]:
                    d = max(abs(i - TC[0]), abs(j - TC[1]))
                    if best is None or d < best[0]:
                        best = (d, i, j)
        return best and best[1:]

    def job(self, u):
        return self.c.peek(u['addr'] + U_JOB)

    def kind(self, u):
        return self.c.peek(J_KIND + u['idx'])

    # ---------------------------------------------------- κάμερα, κέρσορας
    def cam_to(self, i, j):
        """Βελάκια ώσπου το πλακίδιο να είναι κοντά στη μέση της οθόνης."""
        fx, fy = tile_xy(i, j)
        tx, ty = fx - 38, fy - 64
        stuck = 0
        for _ in range(400):
            cx, cy = M2.cam(self.c, self.sym)
            keys = []
            if tx - cx > 6:
                keys.append(CP.KEY_RIGHT)
            elif cx - tx > 6:
                keys.append(CP.KEY_LEFT)
            if ty - cy > 12:
                keys.append(CP.KEY_DOWN)
            elif cy - ty > 12:
                keys.append(CP.KEY_UP)
            if not keys:
                return True
            for k in keys:
                self.c.key_down(k)
            self.tick(1)
            for k in keys:
                self.c.key_up(k)
            if M2.cam(self.c, self.sym) == (cx, cy):
                stuck += 1
                if stuck > 6:           # η άκρη του χάρτη
                    return True
            else:
                stuck = 0
        return False

    def cursor_tile(self, i, j):
        self.cam_to(i, j)
        try:
            self.move(*M6.tile_cursor(self.g, i, j))
            return True
        except AssertionError:
            return False

    def move(self, x, y):
        """Ο κέρσορας ως το (x, y)· αν δεν φτάνει, τα Q A O P αφήνονται (αλλιώς
        ένα πατημένο σπρώχνει την κάμερα στην άκρη για πάντα)."""
        try:
            self.g.move_cursor(x, y)
        finally:
            for k in 'qaop':
                self.c.key_up(k)

    def press(self, key, n=2):
        self.c.key_down(key)
        self.tick(n)
        self.c.key_up(key)
        self.tick(2)

    def select_unit(self, u):
        u = S.unit(self.c, u['idx'])
        i, j = M3_feet(u)
        self.cam_to(i, j)
        u = S.unit(self.c, u['idx'])
        if u['sy'] == 255 or u['sx'] > 76:
            return False
        try:
            sel = M6.click_unit(self.g, u['idx'])
        except AssertionError:
            return False
        finally:
            for k in 'qaop ':
                self.c.key_up(k)
        return u['idx'] in sel

    def select_box(self, i, j, w=14, h=44):
        """SPACE κρατημένο από τη μια γωνία ως την άλλη, γύρω από το (i, j)."""
        self.cam_to(i, j)
        cx, cy = M2.cam(self.c, self.sym)
        fx, fy = tile_xy(i, j)
        x0, y0 = self.g.cursor()
        a = (max(0, fx - cx - w) // 2 * 2 + x0 % 2,
             max(0, fy - cy - h) // 6 * 6 + y0 % 6)
        b = (min(76, fx - cx + w) // 2 * 2 + x0 % 2,
             min(112, fy - cy + h) // 6 * 6 + y0 % 6)
        b = (min(b[0], 76 - (76 - b[0]) % 2), b[1])
        try:
            self.move(*a)
            self.c.key_down(' ')
            self.tick(2)
            self.move(*b)
        except AssertionError:
            self.c.key_up(' ')
            self.tick(2)
            return 0
        self.c.key_up(' ')
        self.tick(2)
        return self.c.peek(self.sym['SEL_N'])

    def command(self, i, j):
        if not self.cursor_tile(i, j):
            return False
        self.press(CP.KEY_RETURN, 1)
        return True

    def build(self, v, key, tile):
        """-> True χτίστηκε, False η θέση δεν δέχτηκε, None ο χωρικός δεν
        επιλέχτηκε (ξανά αργότερα)."""
        n0 = len(M7.blds(self.c))
        if not self.select_unit(v):
            return None
        self.press(key)
        if not self.cursor_tile(*tile):
            self.press(CP.KEY_ESC)
            return False
        self.press(CP.KEY_RETURN, 1)
        ok = len(M7.blds(self.c)) > n0
        if not ok:
            self.press(CP.KEY_ESC)
        return ok

    def train(self, b):
        if not self.cursor_tile(b['i0'] + 1, b['j0'] + 1):
            return False
        q = b['qn']
        self.press(' ')
        self.press('t')
        nb = [x for x in M7.blds(self.c) if x['slot'] == b['slot']]
        return bool(nb) and nb[0]['qn'] > q

    # ---------------------------------------------------- αποφάσεις
    def step(self):
        c = self.c
        food, wood, gold, stone, pop = M6.hud_vals(c, self.sym)[:5]
        blds = M7.blds(c)
        ready = [b for b in blds if b['st']]
        houses = [b for b in ready if b['type'] == 'house']
        found = [b for b in blds if not b['st']]
        cap = 15 + 5 * len(houses)
        queued = sum(b['qn'] for b in ready)
        mine = self.mine()
        vils = [u for u in mine if u['set'] in (0, 3)]
        sols = [u for u in mine if u['set'] in (1, 2)]
        tc = [b for b in ready if b['type'] == 'town_center']
        bar = [b for b in blds if b['type'] == 'barracks']

        # στρατώνας
        if not bar and wood >= 125 and vils and self.bar_i < len(BARRACKS):
            v = min(vils, key=lambda u: max(abs(a - b) for a, b in
                                            zip(M3_feet(u), TC)))
            r = self.build(v, 'b', BARRACKS[self.bar_i])
            if r:
                log(self.sec(), 's: στρατώνας στο', BARRACKS[self.bar_i])
            elif r is False:
                self.bar_i += 1
            return
        # σπίτι (ο χωρικός πιο κοντά στο Κέντρο)
        if pop + queued >= cap - 2 and wood >= 30 and not found and vils \
                and self.house_i < len(HOUSES):
            v = min(vils, key=lambda u: max(abs(a - b) for a, b in
                                            zip(M3_feet(u), TC)))
            t = HOUSES[self.house_i]
            r = self.build(v, 'h', t)
            if r:
                log(self.sec(), 's: σπίτι στο', t)
            if r is not None:
                self.house_i += 1       # χτίστηκε, ή η θέση δεν δέχτηκε
            return
        # χωρικοί
        if tc and len(vils) + tc[0]['qn'] < VIL_MAX and food >= 50 and \
                tc[0]['qn'] < 2 and pop + queued < cap:
            if self.train(tc[0]):
                return
        # σπαθοφόροι
        rb = [b for b in bar if b['st']]
        if rb and food >= 35 and gold >= 15 and rb[0]['qn'] < 2 and \
                pop + queued < cap:
            if self.train(rb[0]):
                return
        # αποθήκη δίπλα στον χρυσό (τα ταξίδια ως το Κέντρο είναι 15 πλακίδια)
        if rb and wood >= 120 and not found and self.store_i < len(STORE) \
                and not any(b['type'] == 'storage_pit' for b in blds):
            v = min(vils, key=lambda u: max(abs(a - b) for a, b in
                                            zip(M3_feet(u), STORE[0])))
            r = self.build(v, 's', STORE[self.store_i])
            if r:
                log(self.sec(), 's: αποθήκη στο', STORE[self.store_i])
            elif r is False:
                self.store_i += 1
            return
        # τροφή: όταν δεν μένει κοντινή, σιταποθήκη -> αγορά -> χωράφια
        if self.food_build(blds, ready, found, wood, vils):
            return
        # οι αδρανείς χωρικοί: στον πόρο που λείπει
        idle = [u for u in vils if self.job(u) == 0 and
                not u['fl'] & S.F_MOVE]
        stalled = [b for b in found
                   if not any(self.job(u) == 4 for u in vils)]
        if idle and stalled:            # θεμέλιο χωρίς χτίστη: εκεί
            b = stalled[0]
            n = 3 if b['type'] in ('farm', 'barracks', 'granary',
                                   'market') else 2
            if self.select_unit(idle[0]) and \
                    self.command(b['i0'] + n // 2, b['j0'] + n // 2):
                return
        if idle:
            have = {k: 0 for k in WANT}
            for u in vils:
                if self.job(u) and self.job(u) != 4:
                    have[self.kind(u)] = have.get(self.kind(u), 0) + 1
            want = dict(WANT)
            if wood > 200:
                want[1] = 1
            if not rb:
                want[2] = 0
            for k in sorted(want, key=lambda k: have[k] - want[k]):
                t = self.source(k)      # (ο πόρος που λείπει, αλλιώς ο
                if t:                   # επόμενος που υπάρχει)
                    for v in idle[:4]:  # (ένας πίσω από το Κέντρο δεν
                        if self.select_unit(v):     # επιλέγεται: ο επόμενος)
                            self.command(*t)
                            return
                    break
        # εχθρικοί στρατιώτες κοντά στην πόλη: οι δικοί μας πολεμούν μόνοι
        # τους, από τη θέση τους (μια εντολή θα τους έβγαζε από τη μάχη· και
        # όποιος πλησιάζει χάνει: ο ακίνητος χτυπάει πρώτος)
        near = [u for u in self.enemies() if u['set'] in (1, 2) and
                max(abs(a - b) for a, b in zip(M3_feet(u), TC)) < 20]
        if near and not self.attacking:
            return
        # οι νέοι σπαθοφόροι: στη συγκέντρωση
        ri, rj = RALLY
        loose = [u for u in sols if not u['fl'] & S.F_MOVE and
                 max(abs(a - b) for a, b in zip(M3_feet(u), RALLY)) > 4]
        if loose and not self.attacking:
            if self.select_unit(loose[0]):
                self.command(ri, rj)
            return
        # επίθεση
        if (len(sols) >= ARMY and self.sec() >= FIRST) or \
                (self.attacking and sols):
            self.attack(sols)

    def food_build(self, blds, ready, found, wood, vils):
        fs = self.source(0)
        if fs and max(abs(a - b) for a, b in zip(fs, TC)) <= 10:
            return False
        if found or not vils or self.econ_i >= len(ECON):
            return False
        have = {b['type'] for b in blds}
        done = {b['type'] for b in ready}
        if 'granary' not in have:
            key, cost = 'g', 120
        elif 'granary' not in done:
            return False
        elif 'market' not in have:
            key, cost = 'm', 150
        elif 'market' not in done:
            return False
        else:
            key, cost = 'f', 75
        if wood < cost:
            return False
        t = ECON[self.econ_i]
        for v in sorted(vils, key=lambda u: max(abs(a - b) for a, b in
                                                zip(M3_feet(u), TC)))[:3]:
            r = self.build(v, key, t)
            if r is not None:
                break
        if r:
            log(self.sec(), 's:', {'g': 'σιταποθήκη', 'm': 'αγορά',
                                   'f': 'χωράφι'}[key], 'στο', t)
            self.events.append(key)
        if r is not None:
            self.econ_i += 1
        return r is not None

    def attack(self, sols):
        en = self.enemies()
        ai_tc = [b for b in M7.blds(self.c, 1) if b['type'] == 'town_center']
        busy = [u for u in sols if u['fl'] & S.F_MOVE]
        if self.attacking and len(busy) * 2 > len(sols) and \
                self.sec() - self.ordered < 20:
            return                      # ακόμα στον δρόμο (ως 20 s: μετά,
        self.ordered = self.sec()       # η εντολή ξανά — κολλάνε σε δάση)
        if not self.attacking:
            log(self.sec(), 's: επίθεση με', len(sols))
            self.attacking = True
        # όλοι οι σπαθοφόροι μαζί: κουτί γύρω από τον καθένα που δεν έχει
        # επιλεγεί, ως να επιλεγούν όλοι (ή 4 γύροι)
        for _ in range(4):
            sel = {u['idx'] for u in S.units(self.c) if u['fl'] & S.F_SEL}
            rest = [u for u in sols if u['idx'] not in sel]
            if not rest:
                break
            i, j = M3_feet(S.unit(self.c, rest[0]['idx']))
            self.select_box(i, j)
            sel = [u for u in S.units(self.c) if u['fl'] & S.F_SEL]
            if any(u['set'] in (0, 3) for u in sel):
                break                   # (ένας χωρικός μέσα: φτάνει)
        if ai_tc:
            self.command(*AI_TC)
        elif en:
            sx, sy = M3_feet(sols[0])
            e = min(en, key=lambda u: max(abs(a - b) for a, b in
                                          zip(M3_feet(u), (sx, sy))))
            self.command(*M3_feet(e))


def M3_feet(u):
    """Το πλακίδιο των ποδιών της (pathing.asm: unit_tile)."""
    fx, fy = u['wx'] + 2, u['wy'] + 14
    return (2 * fx + fy - 383) >> 3, (fy - 2 * fx + 383) >> 3


def lose():
    c, sym = boot()
    last, t = -1, 0
    for f in range(LIMIT * 25):
        c.run_frames(2)
        if c.peek(sym['GAME_END']):
            break
        if f % 250 == 0:
            t = c7w(c, sym, 'LV_SEC')
            if t == last:
                break                   # ο χρόνος σταμάτησε: κόλλημα
            last = t
    end = c.peek(sym['GAME_END'])
    t = c7w(c, sym, 'LV_SEC')
    report('ΗΤΤΑ', end == 2, 'αδρανής παίκτης: game_end %d στα %d s' % (end, t))


def win():
    c, sym = boot()
    bot = Bot(c, sym)
    last = 0
    while not bot.ended() and bot.sec() < LIMIT:
        bot.step()
        bot.tick(4)
        if bot.sec() // 60 != last // 60:
            mine = bot.mine()
            log('%4d s: πόροι %s, χωρικοί %d, στρατιώτες %d, εχθροί %d'
                % (bot.sec(), M6.hud_vals(c, sym)[:5],
                   sum(1 for u in mine if u['set'] in (0, 3)),
                   sum(1 for u in mine if u['set'] in (1, 2)),
                   len(bot.enemies())))
        last = bot.sec()
    end = bot.ended()
    report('ΝΙΚΗ', end == 1, 'game_end %d στα %d s (χωράφια %d)'
           % (end, bot.sec(), bot.events.count('f')))
    if '--shots' in sys.argv:
        path = os.path.join(M.BUILD, 'm14_game.png')
        c.screenshot(path, aspect=True)
        print('   ', path)
    for what, m in (('χωρίς κύλιση', False), ('με κύλιση', True)):
        ts = [t for t, s in zip(bot.g.times, bot.g.scrolled) if s == m]
        if ts:
            over = [t for t in ts if t >= 40]
            print('%-8s %-9s καρέ μονάδων %s: μέσος %.1f ms, μέγιστος %.1f '
                  'ms, %d από τα %d πάνω από 40 (μέτρηση)'
                  % ('χρόνος', '<40' if not over else 'ΠΑΝΩ', what,
                     sum(ts) / len(ts), max(ts), len(over), len(ts)))


def main():
    if '--win' not in sys.argv:
        lose()
    if '--lose' not in sys.argv:
        win()
    print('\nM14 (παρτίδα): %s' % ('OK' if OK else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if OK else 1)


if __name__ == '__main__':
    main()
