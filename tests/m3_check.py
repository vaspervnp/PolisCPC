"""M3: 16 μονάδες κινούνται στα 25 Hz — χωρίς σκουπίδια, σωστά, και σε χρόνο.

    python3 tests/m3_check.py [--shots]

Από το M4 οι μονάδες είναι 128 στον κόσμο. Ο έλεγχος στήνει το σενάριο του
M3 γράφοντας στη μνήμη: 16 μονάδες ΜΕΣΑ στην οθόνη, όλες με στόχο στην
αντίθετη άκρη της — περπατάνε όλες μαζί. Σε headless CPC 6128:

1. ΧΡΟΝΟΣ — ΜΕΤΡΗΣΗ (βλ. milestones.md, M5). Το παιχνίδι γράφει uphase=3
   όταν αρχίζει το καρέ των μονάδων και uphase=4 όταν τελειώνει, σε 50
   καρέ, με βήμα 50 µs. Ως το M3 το όριο ήταν < 32 ms: μόνο η σχεδίαση, και
   8 ms για λογική. Από το M4/M5 η λογική είναι ΜΕΣΑ (απόφαση, βήματα με
   εύρεση δρόμου και ολίσθηση, κάδοι, περιπλάνηση των άλλων 112), και το
   σενάριο όπου ΚΑΙ ΟΙ 16 περπατάνε μαζί στην οθόνη περνάει τα 40 ms στις
   κορυφές. Τυπώνεται με και χωρίς την περιπλάνηση των άλλων· το exit code
   είναι μόνο η ορθότητα (2-3).

2. ΣΥΝΘΕΣΗ. Ανάμεσα σε δύο καρέ, η οθόνη πρέπει να είναι ΑΚΡΙΒΩΣ: το φόντο
   του M1 (mockup), με τις μονάδες από πάνω, στη σειρά του ORDER, με τα καρέ
   που λένε οι εγγραφές τους (tests/scene.py — οι όψεις W καθρεφτισμένες
   στην Python, ανεξάρτητα από τον Z80).

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
import scene as S                               # noqa: E402

UNITS = 16
SETS = S.SETS
SPR_BASE, SPR_STRIDE, SPR_WEST = 0x4000, 0xC80, 0xA80
frames = S.frames


def put16(c, addr, v):
    c.poke(addr, v & 0xFF)
    c.poke(addr + 1, (v >> 8) & 0xFF)


def setup(c, sym):
    """16 μονάδες σε πλέγμα 4x4 μέσα στην οθόνη (κάμερα 98, 303), η καθεμία με
    στόχο στην αντίθετη γωνία: περπατάνε όλες, για > 100 καρέ."""
    wait_uphase(c, sym, 4)
    for i in range(UNITS):
        a = S.UNIT_TAB + i * S.U_SIZE
        x, y = 104 + (i % 4) * 18, 312 + (i // 4) * 28
        tx = 172 if (i % 4) < 2 else 100
        ty = 425 if (i // 4) < 2 else 305
        put16(c, a + 0, x)
        put16(c, a + 2, y)
        put16(c, a + 4, tx)
        put16(c, a + 6, ty)
        fl = c.peek(a + 11)               # περπατάει, όχι περιπλάνηση
        c.poke(a + 11, (fl & ~S.F_WANDER) | S.F_MOVE)  # (τα άλλα bits μένουν)
        c.poke(S.ACT_TAB + i, 1)

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


def main():
    shots = '--shots' in sys.argv
    sym = M.symbols()
    grd, res = M.mockup.make_map()
    world = M.mockup.render_world(grd, res, towns=False)
    ref = M.reference(world, 98, 303)
    ok = True

    c = CPC()
    c.run_frames(5)
    assert c.quickload(os.path.join(M.BUILD, 'polis.sna')), 'quickload'
    M.wait_phase(c, sym, 6)
    setup(c, sym)
    for _ in range(10):                 # να μπουν όλες στην οθόνη
        tick_time(c, sym)

    def timing(what):
        times = [tick_time(c, sym) for _ in range(50)]
        print('χρόνος   %-9s %s: μέσος %.1f ms, μέγιστος %.1f ms (25 Hz: 40)'
              % ('<40' if max(times) < 40 else 'ΠΑΝΩ', what,
                 sum(times) / len(times), max(times)))
    timing('16 περπατάνε, + 112 περιπλανιούνται')

    for k in range(3):
        for _ in range(17):
            tick_time(c, sym)
        exp = S.expected(c, sym, ref)
        good = M.compare(c, exp, 'units%d' % k, shots)
        print('σύνθεση  %-9s μετά από %d καρέ'
              % ('OK' if good else 'ΑΠΟΤΥΧΙΑ', 50 + 17 * (k + 1)))
        ok &= good

    wait_uphase(c, sym, 4)              # οι άλλες 112 ακίνητες
    for i in range(UNITS, S.UNITS):
        a = S.UNIT_TAB + i * S.U_SIZE
        c.poke(a + 11, c.peek(a + 11) & ~(S.F_WANDER | S.F_MOVE))
    setup(c, sym)                       # και οι 16 ξανά από την αρχή
    for _ in range(10):
        tick_time(c, sym)
    timing('16 περπατάνε, οι άλλες 112 ακίνητες')

    for _ in range(40):
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
