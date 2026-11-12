"""M1: ο χάρτης 96x96 και το ισομετρικό έδαφος, ελεγμένα σε headless CPC 6128.

    python3 tests/m1_check.py [--shots]

Για κάθε θέση κάμερας, η RAM της οθόνης (γραμμές 0-143) πρέπει να είναι
ΑΚΡΙΒΩΣ ίδια, pixel προς pixel, με το ίδιο κομμάτι του κόσμου όπως το
ζωγραφίζει το src/mockup.py (έδαφος + πόροι, χωρίς κτίρια/μονάδες). Δύο
εντελώς διαφορετικοί αλγόριθμοι — ο mockup στρώνει ρόμβους και sprites, ο
Z80 γράφει ζώνες των 2 γραμμών — πρέπει να βγάλουν το ίδιο αποτέλεσμα.

Θέσεις: η πόλη του παίκτη (από το .sna ΚΑΙ από το .dsk με RUN"POLIS), η
πάνω κορυφή του χάρτη (μαύρο γύρω, ψαλίδι στα όρια του χάρτη), η δεξιά άκρη
και η κάτω.

Χρόνος: το παιχνίδι γράφει phase=1 όταν αρχίζει να σχεδιάζει και phase=2
όταν τελειώνει· ο έλεγχος τρέχει τον emulator σε βήματα των 100 µs.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))
sys.path.insert(0, os.environ.get('CPCEMU', os.path.expanduser('~/cpcemu')))

from cpc import CPC                             # noqa: E402
import mockup                                   # noqa: E402

BUILD = os.path.join(ROOT, 'build')
VIEW_W, VIEW_H = 160, 144
STEP_US = 100
SNAP = []                       # ο καθρέφτης του φόντου μετά τη σχεδίαση (M3)


def symbols():
    sym = {}
    with open(os.path.join(BUILD, 'polis.sym')) as f:
        for line in f:
            p = line.split()
            if len(p) >= 2 and p[1].startswith('#'):
                sym[p[0]] = int(p[1][1:], 16)
    return sym


# Τα κτίρια με τα οποία αρχίζει το παιχνίδι (M7): (κλειδί, i0, j0).
GAME_BLDS = [('town_center', 30, 58)]


def game_world(grd=None, res=None, blds=None, found=()):
    """Ο κόσμος όπως τον ζωγραφίζει το παιχνίδι: έδαφος, πόροι, και τα
    κτίρια του (με τις εικόνες του src/make_bank6.py). `found`: θεμέλια
    (κλειδί, i0, j0) — η κάτοψη γίνεται «χώμα τραχύ», χωρίς εικόνα."""
    import make_bank6 as MB
    if grd is None:
        grd, res = mockup.make_map()
    grd = [list(r) for r in grd]
    for key, i0, j0 in found:
        n = MB.footprint(key)
        for j in range(j0, j0 + n):
            for i in range(i0, i0 + n):
                grd[j][i] = 'dirt_rough'
    items = [(MB.image(k), i0, j0, MB.footprint(k))
             for k, i0, j0 in (GAME_BLDS if blds is None else blds)]
    return mockup.render_world(grd, res, towns=False, blds=items)


def reference(world, cam_x, cam_y):
    """Το κομμάτι του κόσμου του mockup που αντιστοιχεί στην κάμερα του Z80.
    Ο κόσμος του mockup έχει X σε pixels (= 2 x bytes) και Y μετατοπισμένο
    κατά mockup.TOP."""
    x0, y0 = cam_x * 2, cam_y + mockup.TOP
    out = []
    for y in range(VIEW_H):
        row = []
        for x in range(VIEW_W):
            yy, xx = y0 + y, x0 + x
            p = 0
            if 0 <= yy < len(world) and 0 <= xx < len(world[0]):
                p = world[yy][xx] or 0
            row.append(p)
        out.append(row)
    return out


def wait_phase(c, sym, want, limit_ms=4000):
    t = 0
    while c.peek(sym['PHASE']) != want:
        c.run_us(STEP_US)
        t += STEP_US
        if t > limit_ms * 1000:
            raise RuntimeError('phase %d δεν ήρθε σε %d ms' % (want, limit_ms))
    return t


def render_at(c, sym, cam_x, cam_y):
    """Βάζει την κάμερα, ζητάει σχεδίαση και μετράει πόσο κράτησε."""
    c.poke(sym['PHASE'], 0)
    for k, v in ((sym['CAM_X'], cam_x), (sym['CAM_Y'], cam_y & 0xFFFF)):
        c.poke(k, v & 0xFF)
        c.poke(k + 1, v >> 8)
    c.poke(sym['REDRAW'], 1)
    wait_phase(c, sym, 1)
    t = wait_phase(c, sym, 2) / 1000.0
    SNAP.append(wait_phase(c, sym, 6) / 1000.0)
    return t


def compare(c, ref, name, shots):
    rows = c.decode_screen_ram(0xC000, mode=0)
    bad = [(x, y) for y in range(VIEW_H) for x in range(VIEW_W)
           if rows[y][x] != ref[y][x]]
    if shots:
        path = os.path.join(BUILD, 'm1_%s.png' % name)
        c.screenshot(path, aspect=True)
        print('   ', path)
    if bad:
        x, y = bad[0]
        print('      %d pixels διαφέρουν· πρώτο στο (%d,%d): %d αντί %d'
              % (len(bad), x, y, rows[y][x], ref[y][x]))
    return not bad


def main():
    shots = '--shots' in sys.argv
    sym = symbols()
    grd, res = mockup.make_map()
    world = game_world(grd, res)

    cams = [('town', 98, 303), ('top', 152, -1), ('right', 304, 315),
            ('bottom', 150, 623), ('left', 0, 351)]
    ok = True

    c = CPC()
    c.run_frames(5)
    assert c.quickload(os.path.join(BUILD, 'polis.sna')), 'quickload'
    t0 = wait_phase(c, sym, 2) / 1000.0
    good = compare(c, reference(world, 98, 303), 'sna', shots)
    print('%-7s %-9s αρχική σχεδίαση' % ('sna', 'OK' if good else 'ΑΠΟΤΥΧΙΑ'))
    ok &= good
    times = []
    for name, cx, cy in cams:
        ms = render_at(c, sym, cx, cy)
        good = compare(c, reference(world, cx, cy), name, shots)
        times.append(ms)
        print('%-7s %-9s cam=(%d,%d)  %.1f ms'
              % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', cx, cy, ms))
        ok &= good

    c = CPC()
    c.run_frames(150)
    c.insert_disc(os.path.join(BUILD, 'polis.dsk'))
    c.type_text('RUN"POLIS\n')
    wait_phase(c, sym, 2, limit_ms=8000)
    good = c.mode == 0 and compare(c, reference(world, 98, 303), 'dsk', shots)
    print('%-7s %-9s RUN"POLIS' % ('dsk', 'OK' if good else 'ΑΠΟΤΥΧΙΑ'))
    ok &= good

    print('\nολόκληρο το παράθυρο: %.1f - %.1f ms (%.1f - %.1f καρέ των 20 ms)'
          % (min(times), max(times), min(times) / 20, max(times) / 20))
    print('και μετά ο καθρέφτης του φόντου (M3): %.1f ms' % max(SNAP))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
