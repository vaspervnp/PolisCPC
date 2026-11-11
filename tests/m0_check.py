"""M0: η αποδοχή, ελεγμένη σε headless CPC 6128.

    python3 tests/m0_check.py [--shots]

Χρειάζεται τον headless emulator (floooh/chips) στο ~/cpcemu ή όπου δείχνει
το CPCEMU. Ελέγχει και τις δύο εξόδους του game/build.sh:

    polis.sna   φορτώνει και ξεκινάει κατευθείαν
    polis.dsk   εκκίνηση BASIC, RUN"POLIS

και για την καθεμία:

    * Mode 0
    * η οθόνη έχει 16 λωρίδες των 10 pixels, pen 0..15 — διαβασμένες από τη
      RAM της οθόνης, ανεξάρτητα από το gate array
    * κάθε λωρίδα βγαίνει στην εικόνα με το χρώμα του polis_hw — δηλαδή τα
      INK έχουν μπει σωστά
    * το border αναβοσβήνει κόκκινο σε κάθε καρέ: ο μετρητής χρόνου ζει
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'src'))
sys.path.insert(0, os.environ.get('CPCEMU', os.path.expanduser('~/cpcemu')))

import gfx                                      # noqa: E402
from cpc import CPC                             # noqa: E402

BUILD = os.path.join(ROOT, 'build')
HW_RED = 0x4C


def check(c, name, shots):
    errs = []
    if c.mode != 0:
        errs.append('mode %d, περίμενα 0' % c.mode)
    rows = c.decode_screen_ram(0xC000, mode=0)
    flat = [r for r in rows]
    for y in (0, 99, 199):
        line = flat[y]
        want = [x // 10 for x in range(160)]
        if list(line[:160]) != want:
            errs.append('γραμμή %d: %s' % (y, line[:40]))
            break

    # Τα χρώματα στην εικόνα: το κέντρο κάθε λωρίδας, στη μέση της οθόνης.
    # Η εικόνα 768 pixels έχει περίγραμμα· η οθόνη 160 pixels Mode 0 πιάνει
    # 640 από αυτά (4 ανά pixel).
    img = c.image()
    pal = c.palette()
    left = (img.width - 640) // 2
    top = (img.height - 200) // 2
    for pen in range(16):
        x = left + (pen * 10 + 5) * 4
        got = img.getpixel((x, top + 100))
        want = pal[gfx.HW[pen] & 0x1F]
        if got != want:
            errs.append('pen %d: %s, περίμενα %s (hw #%02X)'
                        % (pen, got, want, gfx.HW[pen]))

    # Ο μετρητής: σε κάποιο σημείο του καρέ το border είναι κόκκινο.
    # Με άδειο `frame_work` η λωρίδα κρατάει λιγότερο από μία γραμμή
    # σάρωσης, οπότε ψάχνουμε σε ΟΛΟ το framebuffer, όχι σε μία στήλη.
    red = pal[HW_RED & 0x1F]
    seen = False
    for _ in range(3):
        c.run_frames(1)
        if red in {col for _, col in
                   c.image(full_framebuffer=True).getcolors(1 << 16)}:
            seen = True
            break
    if not seen:
        errs.append('το border δεν έγινε ποτέ κόκκινο')

    if shots:
        path = os.path.join(BUILD, 'm0_%s.png' % name)
        c.screenshot(path, aspect=True)
        print('  ', path)
    print('%-4s %s' % (name, 'OK' if not errs else 'ΑΠΟΤΥΧΙΑ'))
    for e in errs:
        print('     ', e)
    return not errs


def main():
    shots = '--shots' in sys.argv
    ok = True

    c = CPC()
    c.run_frames(5)
    assert c.quickload(os.path.join(BUILD, 'polis.sna')), 'quickload'
    c.run_frames(25)                    # οι λωρίδες θέλουν ~5 καρέ
    ok &= check(c, 'sna', shots)

    c = CPC()
    c.run_frames(150)                   # ώς το Ready της BASIC
    c.insert_disc(os.path.join(BUILD, 'polis.dsk'))
    c.type_text('RUN"POLIS\n')
    c.run_frames(250)
    ok &= check(c, 'dsk', shots)

    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
