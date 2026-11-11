"""M3: 16 μονάδες κινούνται στα 25 Hz — χωρίς σκουπίδια, σωστά, και σε χρόνο.

    python3 tests/m3_check.py [--shots]

Τρία πράγματα, σε headless CPC 6128:

1. ΧΡΟΝΟΣ. Το παιχνίδι γράφει uphase=3 όταν αρχίζει το καρέ των μονάδων
   (επαναφορά 16 ορθογωνίων, κίνηση, ταξινόμηση, σχεδίαση 16 sprites) και
   uphase=4 όταν τελειώνει. Μετριέται σε 50 καρέ, με βήμα 50 µs. Αποδοχή:
   < 32 ms (το καρέ των 25 Hz είναι 40 ms· τα 8 που μένουν είναι για λογική).

2. ΣΥΝΘΕΣΗ. Ανάμεσα σε δύο καρέ, η οθόνη πρέπει να είναι ΑΚΡΙΒΩΣ: το φόντο
   του M1 (mockup), με τις 16 μονάδες από πάνω, στη σειρά του πίνακα `order`,
   με τα καρέ που λέει ο πίνακας μονάδων (οι όψεις W καθρεφτισμένες εδώ, στην
   Python, ανεξάρτητα από τον Z80).

3. ΣΚΟΥΠΙΔΙΑ. Μετά από 150 καρέ κίνησης, το erase_req σβήνει όλες τις
   μονάδες· η οθόνη πρέπει να ξαναγίνει pixel προς pixel το φόντο.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
from cpc import CPC                             # noqa: E402
import gfx                                      # noqa: E402

UNITS, U_SIZE = 16, 16
SETS = ['villager_m', 'swordsman', 'archer']
SPR_BASE, SPR_STRIDE, SPR_WEST = 0x4000, 0xC80, 0xA80


def frames(name):
    blob = open(os.path.join(M.ROOT, 'data', name + '.bin'), 'rb').read()
    return [gfx.decode_masked(blob[k:k + 128], 8, 16)
            for k in range(0, len(blob), 128)]


def wait_uphase(c, sym, want, limit_ms=500):
    t = 0
    while c.peek(sym['UPHASE']) != want:
        c.run_us(50)
        t += 50
        if t > limit_ms * 1000:
            raise RuntimeError('uphase %d δεν ήρθε' % want)
    return t


def tick_time(c, sym):
    """Περιμένει να ΑΡΧΙΣΕΙ ένα καρέ μονάδων και μετράει πόσο κρατάει."""
    wait_uphase(c, sym, 4)
    wait_uphase(c, sym, 3)
    return wait_uphase(c, sym, 4) / 1000.0


def expected(c, sym, ref, sets):
    tab = c.read_ram(sym['UNIT_TAB'], UNITS * U_SIZE)
    order = c.read_ram(sym['ORDER'], UNITS)
    img = [list(r) for r in ref]
    for entry in order:
        idx = entry // U_SIZE           # το order κρατάει δείκτη x 16
        u = tab[idx * U_SIZE:(idx + 1) * U_SIZE]
        x, y, kind = u[7], u[8], u[4]
        ptr = u[10] | u[11] << 8
        off = ptr - (SPR_BASE + kind * SPR_STRIDE)
        if off < SPR_WEST:
            spr = sets[kind][off // 128]
        else:
            spr = gfx.mirror(sets[kind][4 + (off - SPR_WEST) // 128])
        for j in range(16):
            for i in range(8):
                p = spr[j][i]
                if p is not None:
                    img[y + j][x * 2 + i] = p
    return img


def main():
    shots = '--shots' in sys.argv
    sym = M.symbols()
    grd, res = M.mockup.make_map()
    world = M.mockup.render_world(grd, res, towns=False)
    ref = M.reference(world, 98, 303)
    sets = [frames(n) for n in SETS]
    ok = True

    c = CPC()
    c.run_frames(5)
    assert c.quickload(os.path.join(M.BUILD, 'polis.sna')), 'quickload'
    M.wait_phase(c, sym, 6)

    times = [tick_time(c, sym) for _ in range(50)]
    good = max(times) < 32
    print('χρόνος   %-9s καρέ μονάδων: μέσος %.1f ms, μέγιστος %.1f ms '
          '(όριο 32)' % ('OK' if good else 'ΑΠΟΤΥΧΙΑ',
                         sum(times) / len(times), max(times)))
    ok &= good

    for k in range(3):
        for _ in range(17):
            tick_time(c, sym)
        exp = expected(c, sym, ref, sets)
        good = M.compare(c, exp, 'units%d' % k, shots)
        print('σύνθεση  %-9s μετά από %d καρέ'
              % ('OK' if good else 'ΑΠΟΤΥΧΙΑ', 50 + 17 * (k + 1)))
        ok &= good

    for _ in range(100):
        tick_time(c, sym)
    c.poke(sym['ERASE_REQ'], 1)
    wait_uphase(c, sym, 3)
    wait_uphase(c, sym, 4)
    good = M.compare(c, ref, 'erased', shots)
    print('σβήσιμο  %-9s μετά από ~250 καρέ, η οθόνη είναι ξανά το φόντο'
          % ('OK' if good else 'ΑΠΟΤΥΧΙΑ'))
    ok &= good
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
