"""Το ποντίκι AMX (2026-11-25, game/mouse.asm) — σε headless CPC 6128.

    python3 tests/m4_amx_check.py

Το AMX μπαίνει στη θύρα του joystick (γραμμή 9 του πίνακα πλήκτρων) και
δίνει την κίνηση σε παλμούς, πιο σύντομους από ένα καρέ. Ο emulator δεν
έχει AMX: οι παλμοί γίνονται με το joystick, σε βήματα των 100 µs.

1. ΔΙΑΝΥΣΜΑ. Στο #0000 η αρχή του ms_isr (ex (sp),hl, push af, push bc,
   ld b,#F4, jp ms_isr). Το #0038 μένει JP int_handler όσο κινούν τα
   πλήκτρα (Q A O P), και γίνεται rst 0 με την πρώτη κίνηση του joystick.
2. JOYSTICK. Πατημένο, ο κέρσορας κάνει ένα βήμα ανά καρέ μονάδων, όπως με
   τα πλήκτρα (2 bytes δεξιά, 6 γραμμές κάτω).
3. ΠΑΛΜΟΙ. Παλμοί του 1 ms με τυχαία κενά (μικρότεροι από την περίοδο της
   διακοπής, 3,3 ms: τους πιάνει μόνο η ανάγνωση στις 300 Hz): ο κέρσορας
   κινείται, και με διπλάσιους παλμούς 1,5-3 φορές πιο μακριά (πάνω από 2:
   ό,τι έμεινε κάτω από 6 μετρήσεις στο τέλος δεν δίνει βήμα, και σε κάθε
   βήμα ο μετρητής ξαναρχίζει από το 0 — mouse.asm, ms_ax).
4. ΣΤΑΣΗ. Χωρίς παλμούς ο κέρσορας δεν κινείται άλλο (κανένα βήμα από
   μετρήσεις που έμειναν).
"""
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m4_check as M4                           # noqa: E402
import cpc as CP                                # noqa: E402

MS_V = 0xA770                           # ms_x, ms_y (game/main.asm, equ)
OK = True


def report(name, good, what):
    global OK
    print('%-9s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    OK &= bool(good)


def pulses(c, mask, n, rng, on_us=1000):
    """n παλμοί του on_us στη γραμμή mask, με κενά 2-8 ms (τυχαία: ένα
    ποντίκι δεν χτυπάει στον ρυθμό της διακοπής)."""
    for _ in range(n):
        c.joystick(mask)
        c.run_us(on_us)
        c.joystick(0)
        c.run_us(rng.randrange(20, 81) * 100)


def main():
    g = M4.Game(False)
    c, sym = g.c, g.sym

    # 1. το διάνυσμα: σβηστό ως την πρώτη κίνηση, και μετά rst 0
    isr = sym['MS_ISR']
    ih = sym['INT_HANDLER']
    stub = [c.peek(i) for i in range(8)]
    want = [0xE3, 0xF5, 0xC5, 0x06, 0xF4, 0xC3, isr & 255, isr >> 8]
    v0 = [c.peek(0x38 + i) for i in range(3)]
    c.set_joystick_type(1)
    g.move_cursor(20, 34)
    off = [c.peek(0x38 + i) for i in range(3)]
    c.joystick(CP.JOY_LEFT)
    g.tick(2)
    c.joystick(0)
    g.tick(2)
    on = c.peek(0x38)
    report('ΔΙΑΝΥΣΜΑ', stub == want and v0 == off == [0xC3, ih & 255, ih >> 8]
           and on == 0xC7,
           '#0000: %s· #0038 με πλήκτρα %s, μετά το joystick %02X'
           % (' '.join('%02X' % b for b in stub),
              ' '.join('%02X' % b for b in off), on))
    g.move_cursor(20, 34)

    # 2. το joystick: ένα βήμα ανά καρέ μονάδων
    c.joystick(CP.JOY_RIGHT | CP.JOY_DOWN)
    g.tick(2)                           # (το πρώτο καρέ: όσο μάζευε)
    x0, y0 = g.cursor()
    g.tick(10)
    x1, y1 = g.cursor()
    c.joystick(0)
    g.tick(2)
    report('JOYSTICK', (x1 - x0, y1 - y0) == (20, 60),
           '10 καρέ: %+d bytes, %+d γραμμές (θέλει +20, +60)'
           % (x1 - x0, y1 - y0))

    # 3. παλμοί: απόσταση ανάλογη με το πλήθος
    g.move_cursor(10, 34)
    got = []
    rng = random.Random(23)
    for n in (120, 240):
        g.move_cursor(10, 34)
        c.poke(MS_V, 0)                 # (ms_x, ms_y)
        c.poke(MS_V + 1, 0)
        x0 = g.cursor()[0]
        pulses(c, CP.JOY_RIGHT, n, rng)
        g.tick(2)
        got.append(g.cursor()[0] - x0)
    a, b = got
    report('ΠΑΛΜΟΙ', a >= 4 and 1.5 <= b / a <= 3,
           '120 παλμοί του 1 ms: %+d bytes, 240: %+d' % (a, b))

    # 4. στάση
    x0 = g.cursor()[0]
    g.tick(20)
    report('ΣΤΑΣΗ', g.cursor()[0] == x0,
           'χωρίς παλμούς, 20 καρέ: %+d bytes' % (g.cursor()[0] - x0))

    print('\nAMX: %s' % ('OK' if OK else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if OK else 1)


if __name__ == '__main__':
    main()
