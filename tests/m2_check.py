"""M2: η κύλιση — το CRTC μετακινεί την εικόνα, ο Z80 ζωγραφίζει μόνο τη λωρίδα.

    python3 tests/m2_check.py [--shots]

Σε headless CPC 6128, με τα βελάκια πατημένα:

1. ΧΑΡΤΗΣ. Μετά από κάθε διαδρομή (δεξιά, κάτω, αριστερά, πάνω, διαγώνια,
   και ως τις άκρες του χάρτη), η μνήμη της οθόνης, διαβασμένη ΟΠΩΣ ΤΗ
   ΔΙΑΒΑΖΕΙ ΤΟ CRTC με τη μετατόπιση scr_s, πρέπει να είναι pixel προς pixel
   ο κόσμος του mockup στη νέα κάμερα. Η κάμερα πρέπει να έχει πάει όσο
   λένε τα βήματα, και να σταματάει στις άκρες.

2. ΟΘΟΝΗ. Αυτό που ΒΓΑΙΝΕΙ στην οθόνη (το framebuffer του emulator, με το
   split του CRTC και το HUD) μετά την κύλιση πρέπει να είναι ίδιο με αυτό
   που βγαίνει όταν η ίδια κάμερα ζωγραφίζεται από την αρχή (scr_s = 0). Το
   HUD δεν κουνιέται.

3. ΜΟΝΑΔΕΣ. Οι μονάδες κινούνται ενώ η οθόνη κυλάει: η σύνθεση πρέπει να
   είναι σωστή, και όταν σβηστούν, να μένει ακριβώς το φόντο — άρα και ο
   καθρέφτης του φόντου (C4) ακολούθησε την κύλιση.

4. ΧΡΟΝΟΣ — ΜΕΤΡΗΣΗ, όχι κριτήριο (βλ. milestones.md, M2): το καρέ με
   κύλιση και τις 16 μονάδες, και η λωρίδα μόνη της ανά κατεύθυνση, με την
   κάμερα του χειρότερου βήματος. Πάνω από 40 ms το καρέ των 25 Hz χάνει ένα
   VSYNC (16,7 Hz όσο κρατάει). Το exit code είναι μόνο η ορθότητα (1-3).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import m3_check as M3                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
from cpc import CPC                             # noqa: E402

KEYS = {'R': CPCMOD.KEY_RIGHT, 'L': CPCMOD.KEY_LEFT,
        'D': CPCMOD.KEY_DOWN, 'U': CPCMOD.KEY_UP}
MAX_CAM_X, MIN_CAM_Y, MAX_CAM_Y = 304, -1, 623


def word(c, addr, signed=False):
    v = c.peek(addr) | c.peek(addr + 1) << 8
    return v - 0x10000 if signed and v >= 0x8000 else v


def cam(c, sym):
    return word(c, sym['CAM_X']), word(c, sym['CAM_Y'], signed=True)


def decode_scrolled(c, sym):
    """Οι 144 γραμμές του χάρτη όπως τις διαβάζει το CRTC με το scr_s."""
    s = word(c, sym['SCR_S'])
    ram = c.read_ram(0xC000, 0x4000)
    out = []
    for y in range(M.VIEW_H):
        base = (y & 7) * 0x800
        off = 2 * s + (y >> 3) * 80
        row = []
        for b in range(80):
            row.extend(CPCMOD._decode_byte(ram[base + ((off + b) & 0x7FF)], 0))
        out.append(row)
    return out


def diff(rows, ref, name, c, shots):
    bad = [(x, y) for y in range(M.VIEW_H) for x in range(M.VIEW_W)
           if rows[y][x] != ref[y][x]]
    if shots:
        path = os.path.join(M.BUILD, 'm2_%s.png' % name)
        c.screenshot(path, aspect=True)
        print('   ', path)
    if bad:
        x, y = bad[0]
        print('      %d pixels διαφέρουν· πρώτο στο (%d,%d): %d αντί %d'
              % (len(bad), x, y, rows[y][x], ref[y][x]))
    return not bad


def hold(c, sym, keys, ticks, times):
    for k in keys:
        c.key_down(KEYS[k])
    for _ in range(ticks):
        t = M3.tick_time(c, sym)
        times.append((t, cam(c, sym)))
    for k in keys:
        c.key_up(KEYS[k])
    for _ in range(2):                  # να φύγει το πλήκτρο, να ηρεμήσει
        M3.tick_time(c, sym)


def expect_cam(c, sym, keys, n):
    """Πού πρέπει να πάει η κάμερα σε n καρέ (+ τα 2 του αφήματος): ένας
    άξονας ανά καρέ, η κάθετη σε ΔΥΟ καρέ (v_pend: στο πρώτο τίποτα δεν
    κουνιέται, στο δεύτερο τελειώνει ό,τι κι αν πατιέται), στη διαγώνια
    εναλλάξ (sdiag), και ο άλλος άξονας αν ο δικός του είναι στην άκρη."""
    x, y = cam(c, sym)
    sx = keys.count('R') - keys.count('L')
    sy = keys.count('D') - keys.count('U')
    diag = c.peek(sym['SDIAG'])
    pend = None

    def step_h(x):
        if sx > 0 and x < MAX_CAM_X:
            return x + 2
        if sx < 0 and x > 0:
            return x - 2
        return x

    def step_v(y):
        if sy > 0 and y + 8 <= MAX_CAM_Y:
            return y + 8
        if sy < 0 and y - 8 >= MIN_CAM_Y:
            return y - 8
        return y

    for _ in range(n):
        if pend is not None:
            y, pend = pend, None
        elif sx and sy:
            diag ^= 1
            if diag:
                ny = step_v(y)
                if ny != y:
                    pend = ny
                else:
                    x = step_h(x)
            else:
                nx = step_h(x)
                if nx != x:
                    x = nx
                elif step_v(y) != y:
                    pend = step_v(y)
        elif sx:
            x = step_h(x)
        elif sy and step_v(y) != y:
            pend = step_v(y)
    if pend is not None:
        y = pend
    return x, y


def main():
    shots = '--shots' in sys.argv
    sym = M.symbols()
    grd, res = M.mockup.make_map()
    world = M.game_world(grd, res)
    ok = True

    c = CPC()
    c.run_frames(5)
    assert c.quickload(os.path.join(M.BUILD, 'polis.sna')), 'quickload'
    M.wait_phase(c, sym, 6)

    # ---------------------------------------------------- 3. μονάδες
    times = []
    c.key_down(KEYS['R'])
    for k in range(3):
        for _ in range(4):
            times.append(M3.tick_time(c, sym))
        cx, cy = cam(c, sym)
        exp = S.expected(c, sym, M.reference(world, cx, cy))
        good = diff(decode_scrolled(c, sym), exp, 'units%d' % k, c, shots)
        print('μονάδες  %-9s κύλιση δεξιά ενώ κινούνται, κάμερα (%d,%d)'
              % ('OK' if good else 'ΑΠΟΤΥΧΙΑ', cx, cy))
        ok &= good
    c.key_up(KEYS['R'])
    c.key_down(KEYS['D'])
    for _ in range(5):
        times.append(M3.tick_time(c, sym))
    c.key_up(KEYS['D'])
    for _ in range(3):
        M3.tick_time(c, sym)
    cx, cy = cam(c, sym)
    exp = S.expected(c, sym, M.reference(world, cx, cy))
    good = diff(decode_scrolled(c, sym), exp, 'units_d', c, shots)
    print('μονάδες  %-9s μετά από κύλιση κάτω, κάμερα (%d,%d)'
          % ('OK' if good else 'ΑΠΟΤΥΧΙΑ', cx, cy))
    ok &= good
    c.poke(sym['ERASE_REQ'], 1)
    M3.wait_uphase(c, sym, 3)
    M3.wait_uphase(c, sym, 4)
    good = diff(decode_scrolled(c, sym), M.reference(world, cx, cy),
                'erased', c, shots)
    print('σβήσιμο  %-9s η οθόνη είναι ξανά το φόντο: ο καθρέφτης κύλησε'
          % ('OK' if good else 'ΑΠΟΤΥΧΙΑ'))
    ok &= good
    tmax = max(times)
    print('χρόνος   %-9s καρέ με κύλιση και μονάδες: μέσος %.1f ms, '
          'μέγιστος %.1f ms (25 Hz: 40)'
          % ('<40' if tmax < 40 else 'ΠΑΝΩ', sum(times) / len(times), tmax))

    # ------------------------------------------- 1. χάρτης (χωρίς μονάδες)
    routes = [('R', 10), ('D', 8), ('L', 25), ('U', 20), ('RD', 12),
              ('R', 120), ('D', 100), ('L', 200), ('U', 100), ('LD', 6), ('RU', 30)]
    per = {}
    for keys, n in routes:
        want_x, want_y = expect_cam(c, sym, keys, n)
        t = []
        hold(c, sym, keys, n, t)
        cx, cy = cam(c, sym)
        good = (cx, cy) == (want_x, want_y)
        if not good:
            print('      κάμερα (%d,%d), αναμενόταν (%d,%d)'
                  % (cx, cy, want_x, want_y))
        good &= diff(decode_scrolled(c, sym), M.reference(world, cx, cy),
                     'route_%s%d' % (keys, n), c, shots)
        print('χάρτης   %-9s %-3s x %3d -> κάμερα (%d,%d)'
              % ('OK' if good else 'ΑΠΟΤΥΧΙΑ', keys, n, cx, cy))
        ok &= good
        per.setdefault(keys, []).extend(t)

    # ------------------------------------------------ 2. η οθόνη, με HUD
    shown = c.image()
    cx, cy = cam(c, sym)
    M.render_at(c, sym, cx, cy)
    for _ in range(3):
        c.run_frames(1)
    fresh = c.image()
    good = shown.tobytes() == fresh.tobytes()
    if not good:
        a, b = shown.load(), fresh.load()
        bad = [(x, y) for y in range(shown.height) for x in range(shown.width)
               if a[x, y] != b[x, y]]
        print('      %d pixels διαφέρουν· πρώτο στο %s' % (len(bad), bad[0]))
        if shots:
            shown.save(os.path.join(M.BUILD, 'm2_shown.png'))
            fresh.save(os.path.join(M.BUILD, 'm2_fresh.png'))
    print('οθόνη    %-9s μετά την κύλιση = σχεδίαση από την αρχή (με HUD)'
          % ('OK' if good else 'ΑΠΟΤΥΧΙΑ'))
    ok &= good

    for keys, t in per.items():
        worst = max(t)
        print('χρόνος   %-9s λωρίδα %-3s μέσος %.1f ms, μέγιστος %.1f ms '
              '(κάμερα %s)'
              % ('<40' if worst[0] < 40 else 'ΠΑΝΩ', keys,
                 sum(x for x, _ in t) / len(t), worst[0], worst[1]))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
