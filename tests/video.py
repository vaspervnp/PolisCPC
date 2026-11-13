"""Βίντεο του παιχνιδιού: 5 λεπτά από τη δισκέτα, με εικόνα και ήχο.

    python3 tests/video.py [--dry] [--secs 300]

-> build/polis_video.mp4   (1536x1088, 50 fps, ήχος AY 44,1 kHz)

Ο CPC είναι ο headless emulator των τεστ, αλλά από ένα αντίγραφο της
βιβλιοθήκης του (build/libcpcvideo.so, χτίζεται εδώ από το
~/cpcemu/cpcheadless.c) που κρατάει τα δείγματα ήχου του AY· η αρχική
βιβλιοθήκη δεν αλλάζει. Κάθε καρέ του emulator (20 ms) γίνεται καρέ του
βίντεο, όπως το βλέπει η οθόνη (με το περιθώριο).

Το σενάριο παίζεται με πλήκτρα, όπως θα έπαιζε ένας παίκτης: RUN"POLIS,
το μενού (οι πολιτισμοί με αριστερά/δεξιά), PLAY AS GREEKS. Από τους 3
χωρικούς της αρχής ο ένας χτίζει στρατώνα και οι δύο μαζεύουν μούρα· το
Κέντρο Πόλης βγάζει κι άλλους (σπίτι, μούρα, χρυσός, ξύλο), ο στρατώνας
σπαθοφόρους, που μαζεύονται στην άμυνα, και από τα OUT_AT s ο στρατός
πάει στην πόλη του αντιπάλου, με την κάμερα μαζί του· όπου εμφανιστεί
εχθρός, η μάχη. Ό,τι δεν πετύχει (π.χ. κλικ που πιάνει άλλη μονάδα)
γράφεται και το σενάριο συνεχίζει.

--dry: χωρίς εικόνα/ήχο, μόνο στιγμιότυπα (build/video_*.png) — για να
δοκιμάζεται γρήγορα το σενάριο.
"""
import ctypes
import os
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m5_check as M5                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CP                                # noqa: E402

BUILD = M.BUILD
EMU = os.path.expanduser('~/cpcemu')
LIB = os.path.join(BUILD, 'libcpcvideo.so')
OUT = os.path.join(BUILD, 'polis_video.mp4')
W, H = 768, 272                                 # η οθόνη του emulator
RATE = 44100

# ο χάρτης (src/mockup.py, οι έλεγχοι M6/M7/M10)
TC = (31, 59)                   # μέσα στο Κέντρο Πόλης (30-33, 58-61)
BERRIES = (37, 52)
BERRIES2 = (39, 53)
GOLD = (46, 50)
DEFEND = (42, 56)
OUT_AT = 150                   # s: η αντεπίθεση, το νωρίτερο
ARMY_N = 3                      # ... με τόσους στρατιώτες στην άμυνα
TREE = (31, 75)
BARRACKS = (35, 67)             # το κέντρο της κάτοψης (34-36, 66-68)
HOUSE = (27, 63)
AI_TC = (59, 28)
VILLAGERS = (0, 3, 6)           # η αρχή: 3 χωρικοί
SELLIST = 0xA840                # game/input.asm (equ)


# ------------------------------------------------------------ η βιβλιοθήκη

PATCH = '''
static void audio_cb(const float* s, int n, void* user) {
    emu_t* e = (emu_t*)user;
    if (e->alen + n > e->acap) {
        e->acap = (e->acap + n) * 2;
        e->abuf = (float*)realloc(e->abuf, e->acap * sizeof(float));
    }
    memcpy(e->abuf + e->alen, s, n * sizeof(float));
    e->alen += n;
}
int cpcemu_audio_take(void* h, float* out, int max) {
    emu_t* e = (emu_t*)h;
    int n = (int)(e->alen < (size_t)max ? e->alen : (size_t)max);
    memcpy(out, e->abuf, n * sizeof(float));
    memmove(e->abuf, e->abuf + n, (e->alen - n) * sizeof(float));
    e->alen -= n;
    return n;
}

// type: 0 = CPC6128'''


def build_lib():
    """Το cpcheadless.c με τον ήχο: callback που κρατάει τα δείγματα."""
    src_path = os.path.join(EMU, 'cpcheadless.c')
    if os.path.exists(LIB) and \
            os.path.getmtime(LIB) > os.path.getmtime(src_path):
        return
    src = open(src_path).read()
    for old, new in (
            ('    uint8_t* disc_data;',
             '    float* abuf; size_t alen, acap;\n    uint8_t* disc_data;'),
            ('\n// type: 0 = CPC6128', PATCH),
            ('desc.audio.volume = 0.0f;   // no audio wanted',
             'desc.audio.volume = 0.7f;\n    desc.audio.callback = '
             '(chips_audio_callback_t){ .func = audio_cb, .user_data = e };')):
        assert old in src, old
        src = src.replace(old, new, 1)
    c_path = os.path.join(BUILD, 'cpcvideo.c')
    open(c_path, 'w').write(src)
    subprocess.check_call(['gcc', '-O2', '-shared', '-fPIC', '-I', EMU,
                           '-o', LIB, c_path])


# ------------------------------------------------------------ η εγγραφή

class Done(Exception):
    pass


class Rec:
    """Ο CPC, και κάθε καρέ του στο ffmpeg (εικόνα) και σε αρχείο (ήχος)."""

    def __init__(self, frames, dry):
        lib = ctypes.CDLL(LIB)
        CP._lib = CP._bind(lib)
        lib.cpcemu_audio_take.argtypes = [
            ctypes.c_void_p, ctypes.POINTER(ctypes.c_float), ctypes.c_int]
        self.lib, self.dry, self.limit = lib, dry, frames
        self.c = CP.CPC()
        self.sym = M.symbols()
        self.n = 0
        self.abuf = (ctypes.c_float * 8192)()
        self.audio = open(os.path.join(BUILD, 'video.f32'), 'wb')
        self.ff = None
        if not dry:
            self.ff = subprocess.Popen(
                ['ffmpeg', '-loglevel', 'error', '-y', '-f', 'rawvideo',
                 '-pix_fmt', 'rgb24', '-s', '%dx%d' % (W, H), '-r', '50',
                 '-i', '-', '-vf', 'scale=1536:1088:flags=neighbor',
                 '-c:v', 'libx264', '-preset', 'medium', '-crf', '18',
                 '-tune', 'animation', '-pix_fmt', 'yuv420p',
                 os.path.join(BUILD, 'video_v.mp4')], stdin=subprocess.PIPE)
        self.in_game = False
        raw = self.c.run_frames
        self._raw = raw
        self.c.run_frames = self.frames         # και οι βοηθοί των τεστ
        self.t0 = time.time()

    def frames(self, n=1):
        for _ in range(n):
            if self.n >= self.limit:
                raise Done()
            self._raw(1)
            self.n += 1
            k = self.lib.cpcemu_audio_take(self.c._h, self.abuf, 8192)
            self.audio.write(bytes(self.abuf)[:4 * k])
            if self.ff:
                self.ff.stdin.write(self.c.image().tobytes())
            if self.dry and self.n % 750 == 0:
                self.shot('t%03d' % (self.n // 50))
            if self.n % 1500 == 0:
                print('   %3d s βίντεο (%d s)' % (self.n // 50,
                                                 time.time() - self.t0))

    def close(self):
        self.audio.close()
        if self.ff:
            self.ff.stdin.close()
            self.ff.wait()

    def shot(self, name):
        path = os.path.join(BUILD, 'video_%s.png' % name)
        self.c.screenshot(path, aspect=True)


# ------------------------------------------------------------ ο παίκτης

class Player:
    """Ο «παίκτης»: τα ίδια ονόματα με το M4.Game, ώστε να δουλεύουν οι
    βοηθοί των τεστ (M6.tile_cursor, M6.click_unit, M7.press)."""

    def __init__(self, rec):
        self.r, self.c, self.sym = rec, rec.c, rec.sym
        self.busy = set()

    def tick(self, n=1):                        # ~ ένα καρέ μονάδων
        self.r.frames(2 * n)

    def wait(self, secs):
        self.r.frames(int(secs * 50))

    def cursor(self):
        return self.c.peek(self.sym['CUR_X']), self.c.peek(self.sym['CUR_Y'])

    def cam(self):
        return M2.cam(self.c, self.sym)

    def move_cursor(self, x, y):
        x0, y0 = self.cursor()
        x = max(2, min(74, x)) // 2 * 2 + x0 % 2
        y = y0 % 6 + max(0, min(126, y) - y0 % 6) // 6 * 6
        for axis, want, keys in ((0, x, 'op'), (1, y, 'qa')):
            for _ in range(4):
                if self.cursor()[axis] == want:
                    break
                k = keys[1] if want > self.cursor()[axis] else keys[0]
                self.c.key_down(k)
                n = 0
                while (self.cursor()[axis] < want) == (k == keys[1]) \
                        and self.cursor()[axis] != want and n < 200:
                    self.tick(1)
                    n += 1
                self.c.key_up(k)
                self.tick(1)

    def press(self, key, n=2):
        M7.press(self, key, n)

    def screen_of(self, i, j):
        cx, cy = self.cam()
        return 2 * (i - j) + 192 - cx, 4 * (i + j) + 4 - cy

    def look(self, i, j, box=(20, 56, 30, 96)):
        """Κύλιση (βελάκια) ώσπου το πλακίδιο να είναι στο κέντρο."""
        x0, x1, y0, y1 = box
        for _ in range(400):
            x, y = self.screen_of(i, j)
            keys = []
            if x < x0:
                keys.append(CP.KEY_LEFT)
            elif x > x1:
                keys.append(CP.KEY_RIGHT)
            if y < y0:
                keys.append(CP.KEY_UP)
            elif y > y1:
                keys.append(CP.KEY_DOWN)
            if not keys:
                break
            for k in keys:
                self.c.key_down(k)
            self.tick(1)
            for k in keys:
                self.c.key_up(k)
        self.tick(2)

    def click_unit(self, k):
        u = S.unit(self.c, k)
        if u['sy'] == 255 or u['team'] != 0:
            return False
        for _ in range(4):              # ίσως πιάστηκε άλλη, πιο μπροστά
            M6.click_unit(self, k)
            if self.selected() == [k]:
                return True
            self.tick(6)
            u = S.unit(self.c, k)
            if u['sy'] == 255:
                break
        log('  το κλικ δεν έπιασε τον %d: %s' % (k, self.selected()))
        return False

    def at_tile(self, i, j, key=CP.KEY_RETURN):
        """Ο κέρσορας στο πλακίδιο, και ένα πλήκτρο (RETURN: «πήγαινε»)."""
        self.look(i, j)
        try:
            self.move_cursor(*M6.tile_cursor(self, i, j))
        except AssertionError as e:
            log('  δεν φαίνεται: %s' % e)
            return False
        self.press(key, 1)
        return True

    def box(self, x0, y0, x1, y1):
        self.move_cursor(x0, y0)
        self.c.key_down(' ')
        self.tick(2)
        self.move_cursor(x1, y1)
        self.c.key_up(' ')
        self.tick(3)
        return self.selected()

    def selected(self):
        n = self.c.peek(self.sym['SEL_N'])
        b = self.c.read_ram(SELLIST, 2 * n)
        return [((b[k] | b[k + 1] << 8) - S.UNIT_TAB) // S.U_SIZE
                for k in range(0, 2 * n, 2)]

    def box_units(self, units, near, r=5):
        """Κουτί γύρω από όσες από τις μονάδες φαίνονται και είναι ως r
        πλακίδια από το near."""
        us = [u for u in units if u['sy'] != 255 and max(
            abs(a - b) for a, b in zip(M5.unit_tile(u), near)) <= r]
        if not us:
            return []
        xs = [u['sx'] for u in us]
        ys = [u['sy'] for u in us]
        return self.box(min(xs) - 2, min(ys) - 4, max(xs) + 8, max(ys) + 24)

    def follow(self, units, secs, tile=None, stop=None):
        """Η κάμερα ακολουθεί την πρώτη ζωντανή από τις μονάδες."""
        for _ in range(int(secs * 2)):
            self.wait(0.5)
            a = [k for k in units if S.unit(self.c, k)['team'] == 0]
            if not a:
                return
            u = S.unit(self.c, a[0])
            self.look(*M5.unit_tile(u), box=(24, 48, 40, 90))
            if tile and max(abs(x - y) for x, y in zip(
                    M5.unit_tile(u), tile)) <= 2:
                return
            if stop and stop():
                return

    def enemy_near(self, tile, d):
        """Η πιο κοντινή εχθρική μονάδα (ζωντανή) ως d πλακίδια."""
        best = None
        for u in S.units(self.c):
            if u['team'] != 1 or u['fl'] & S.F_WANDER:
                continue
            k = max(abs(x - y) for x, y in zip(M5.unit_tile(u), tile))
            if k <= d and (best is None or k < best[0]):
                best = (k, u)
        return best and best[1]

    def town(self):
        """Στην πόλη: οι αργοί χωρικοί σε δουλειά, σπαθοφόροι, σπίτι."""
        c, sym = self.c, self.sym
        self.look(*TC)
        self.wait(1)
        idle = [u for u in self.mine((0, 3))
                if c.peek(u['addr'] + 27) in (0, 255) or
                (u['idx'] not in VILLAGERS and u['idx'] not in self.busy)]
        self.busy.update(u['idx'] for u in idle)
        log('  αργοί χωρικοί: %s (%.1f s)' % ([u['idx'] for u in idle],
                                            self.r.n / 50))
        jobs = [BERRIES2, GOLD, BERRIES, TREE]
        b = [b for b in M7.blds(c) if b['type'] == 'barracks']
        if idle and not [b for b in M7.blds(c) if b['type'] == 'house']:
            for u in list(idle):
                if self.build(u['idx'], 'h', HOUSE):
                    idle.remove(u)
                    break
            self.wait(1)
        for n, u in enumerate(idle):
            self.job(u['idx'], jobs[n % len(jobs)])
        hud = [M2.word(c, sym['HUD_VAL'] + 2 * k) for k in range(4)]
        log('  κτίρια %s, μπάρα %s' % ([(x['type'], x['st'], x['qn'])
                                       for x in M7.blds(c)], hud))
        vil = len(self.mine((0, 3)))
        tc = [x for x in M7.blds(c) if x['type'] == 'town_center']
        if vil < 7 and tc and tc[0]['qn'] == 0 and hud[0] >= 85:
            self.train(TC, 1)
            hud[0] -= 50
        if b and b[0]['st'] == 1 and b[0]['qn'] == 0:
            n = min(3, hud[0] // 35, hud[2] // 15)
            if n:
                self.train(BARRACKS, n)
                log('  σπαθοφόροι: %d' % n)
        self.wait(2)

    def mine(self, kind=None):
        return [u for u in S.units(self.c)
                if u['team'] == 0 and (kind is None or u['set'] in kind)]

    def job(self, k, tile):
        """Ένας χωρικός σε δουλειά (κλικ πάνω του, RETURN στον πόρο)."""
        u = S.unit(self.c, k)
        if u['team'] != 0:
            return False
        self.look(*M5.unit_tile(u))
        if not self.click_unit(k):
            log('  ο %d δεν φαίνεται' % k)
            return False
        self.tick(4)
        return self.at_tile(*tile)

    def build(self, k, key, tile):
        u = S.unit(self.c, k)
        if u['team'] != 0:
            return False
        self.look(*M5.unit_tile(u))
        if not self.click_unit(k):
            self.press(CP.KEY_ESC)
            return False
        self.tick(4)
        self.press(key)
        self.tick(6)
        return self.at_tile(*tile)

    def train(self, tile, n):
        self.look(*tile)
        self.move_cursor(*M6.tile_cursor(self, *tile))
        self.c.key_down(' ')
        self.tick(2)
        self.c.key_up(' ')
        self.tick(6)
        for _ in range(n):
            self.press('t')
            self.tick(8)


def log(s):
    print(s, flush=True)


def scenario(p):
    r, c, sym = p.r, p.c, p.sym
    # ---- ο CPC ξεκινά, RUN"POLIS
    r.frames(120)
    c.insert_disc(os.path.join(BUILD, 'polis.dsk'))
    for ch in 'RUN"POLIS\n':
        k = CP.KEY_RETURN if ch == '\n' else ch
        c.key_down(k)
        r.frames(4)
        c.key_up(k)
        r.frames(5)
    M.wait_menu(c)
    log('μενού στα %.1f s' % (r.n / 50))
    # ---- το μενού: οι πολιτισμοί, και PLAY AS GREEKS
    p.wait(3)
    for k in [CP.KEY_RIGHT] * 3 + [CP.KEY_LEFT] * 3:
        c.key_down(k)
        r.frames(4)
        c.key_up(k)
        p.wait(0.9)
    r.shot('menu')
    p.wait(1)
    c.key_down(CP.KEY_RETURN)
    r.frames(4)
    c.key_up(CP.KEY_RETURN)
    for _ in range(1000):
        r.frames(5)
        if c.peek(sym['PHASE']) == 6 and c.read_ram(0x38, 1) == b'\xc3':
            break
    r.in_game = True
    log('παιχνίδι στα %.1f s' % (r.n / 50))
    p.wait(2)

    # ---- οι 3 χωρικοί: στρατώνας, μούρα· δύο ακόμα από το Κέντρο Πόλης
    ok = p.build(6, 'b', BARRACKS)
    log('στρατώνας: %s, %s' % (ok, [b['type'] for b in M7.blds(c)]))
    p.job(0, BERRIES)
    p.job(3, BERRIES2)
    p.look(*TC)
    p.train(TC, 2)
    log('δουλειές: %s' % [c.peek(S.UNIT_TAB + k * S.U_SIZE + 27)
                          for k in VILLAGERS])
    r.shot('town')
    p.wait(4)
    battle(p, [])


def battle(p, army):
    """Ως το τέλος του χρόνου: η άμυνα της πόλης, οι επισκέψεις στην πόλη
    (χωρικοί, σπαθοφόροι), η αντεπίθεση στα OUT_AT s, και η κάμερα εκεί
    όπου γίνεται η μάχη — αλλιώς βόλτα στην πόλη."""
    r, c, sym = p.r, p.c, p.sym

    def alive():
        return [k for k in army if S.unit(c, k)['team'] == 0]

    def lead():
        a = alive()
        return a and M5.unit_tile(S.unit(c, a[0]))

    def near(t, d):
        return [u for u in p.mine((1, 2)) if max(abs(a - b) for a, b in zip(
            M5.unit_tile(u), t)) <= d]

    visits = [50, 80, 110, 140, 170, 255]
    tour = [DEFEND, BERRIES, TC, TREE, BARRACKS]
    phase = 'home'
    fights = 0
    while True:
        if c.peek(sym['GAME_END']):
            log('τέλος: %d (%.1f s)' % (c.peek(sym['GAME_END']), r.n / 50))
            r.shot('end')
            p.wait(1000)
        if visits and r.n >= visits[0] * 50:
            v = visits.pop(0)
            p.town()
            new = [u for u in near(BARRACKS, 7) if u['idx'] not in army
                   and u['set'] == 1]
            if new:                     # οι νέοι σπαθοφόροι
                p.look(*BARRACKS)
                sel = p.box_units(new, BARRACKS, 7)
                log('ενισχύσεις: %s (%.1f s)' % (sel, r.n / 50))
                to = lead() if phase == 'march' and alive() else DEFEND
                if sel and p.at_tile(*to):
                    army += [k for k in sel if k not in army]
            continue
        foe = p.enemy_near(TC, 16)
        if not foe and phase == 'march' and alive():
            foe = p.enemy_near(lead(), 9)
        if foe:
            t = M5.unit_tile(foe)
            if not fights:
                log('μάχη στο %s (%.1f s)' % (t, r.n / 50))
                r.shot('fight')
            fights += 1
            p.look(*t)
            us = near(t, 12)
            if us:
                p.box_units(us, t, 12)
                p.at_tile(*M5.unit_tile(S.unit(c, foe['idx'])))
            for _ in range(6):
                p.wait(0.5)
                f = S.unit(c, foe['idx'])
                if f['team'] != 1:
                    break
                p.look(*M5.unit_tile(f))
            continue
        ready = [b for b in M7.blds(c)
                 if b['type'] == 'barracks' and b['st'] == 1]
        if phase == 'home' and ready and r.n >= OUT_AT * 50 and \
                (len(near(DEFEND, 10)) >= ARMY_N or r.n >= 160 * 50):
            phase = 'march'
            t = lead() or DEFEND
            p.look(*t)
            sel = p.box_units(near(t, 14), t, 14)
            army = [k for k in sel if S.unit(c, k)['set'] in (1, 2)] or army
            log('αντεπίθεση: %s (%.1f s)' % (army, r.n / 50))
            r.shot('out')
        if phase == 'march':
            if not alive():
                phase = 'lost'
                log('ο στρατός έπεσε (%.1f s)' % (r.n / 50))
                continue
            i, j = lead()
            if max(abs(i - AI_TC[0]), abs(j - AI_TC[1])) < 10:
                p.box_units([S.unit(c, k) for k in alive()], (i, j), 8)
                p.at_tile(*AI_TC)
                p.follow(army, 4)
                continue
            di = max(-8, min(8, AI_TC[0] - i))
            dj = max(-8, min(8, AI_TC[1] - j))
            p.look(i, j, box=(18, 36, 40, 90))
            p.box_units([S.unit(c, k) for k in alive()], (i, j), 8)
            if not p.at_tile(i + di, j + dj):
                p.at_tile(i + di // 2, j + dj // 2)
            p.follow(army, 6, (i + di, j + dj),
                     stop=lambda: p.enemy_near(lead() or TC, 9) or
                     p.enemy_near(TC, 16))
            continue
        t = tour.pop(0)                 # βόλτα στην πόλη
        tour.append(t)
        p.look(*t)
        p.wait(3)


def mux(secs):
    v = os.path.join(BUILD, 'video_v.mp4')
    a = os.path.join(BUILD, 'video.f32')
    fade = max(0, secs - 2)
    subprocess.check_call(
        ['ffmpeg', '-loglevel', 'error', '-y', '-i', v,
         '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', a,
         '-vf', 'fade=in:0:25,fade=out:st=%d:d=2' % fade,
         '-af', 'highpass=f=20,afade=out:st=%d:d=2' % fade,
         '-c:v', 'libx264', '-crf', '18', '-tune', 'animation',
         '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '160k',
         '-movflags', '+faststart', '-shortest', OUT])
    os.remove(v)
    os.remove(a)


def main():
    dry = '--dry' in sys.argv
    secs = 300
    if '--secs' in sys.argv:
        secs = int(sys.argv[sys.argv.index('--secs') + 1])
    build_lib()
    r = Rec(secs * 50, dry)
    try:
        scenario(Player(r))
    except Done:
        pass
    r.shot('last')
    r.close()
    log('%d καρέ (%.1f s βίντεο) σε %d s'
        % (r.n, r.n / 50, time.time() - r.t0))
    if not dry:
        mux(secs)
        log(OUT)


if __name__ == '__main__':
    main()
