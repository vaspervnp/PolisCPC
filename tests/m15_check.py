"""M15, φάση 1: οι ομάδες στην οθόνη — σε headless CPC 6128.

    python3 tests/m15_check.py [--shots]

Κάθε στρατιώτης (σετ 1, 2, 4) είναι μια ομάδα: το πλήθος της στο SQ_N
(#3F00 + δείκτης, πλήθος - 1). Ελέγχει:

1. ΑΡΙΘΜΟΣ. Με πλήθη 1, 7, 12, 20 σε στρατιώτες της πόλης (και ξανά
   σχεδιασμένους), η οθόνη = ο κόσμος με τον αριθμό κάθε ομάδας στις 5
   κάτω γραμμές της (scene.stamp_label: τα ψηφία του HUD, οι δεκάδες κενές
   κάτω από το 10)· ο μόνος του (πλήθος 1) και οι χωρικοί χωρίς αριθμό.
2. ΚΑΡΤΑ. Μία ομάδα επιλεγμένη: στην κάρτα του HUD το πλήθος της (οι
   δεκάδες στο CARD_X - 2, οι μονάδες στο CARD_X) και η υγεία της στη
   μπάρα (γεμάτη: 6 bytes CARD_FULL).
3. ΣΒΗΣΙΜΟ. Χωρίς επιλογή: τα δύο ψηφία κενά, η μπάρα άδεια.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import make_map as MM                           # noqa: E402
import scene as S                               # noqa: E402

SQ_N = 0x3F00
HUD_PAGE = 0x4000
U_LOOK = 16
CARD_FULL, CARD_EMPTY = 0xF3, 0xC0              # data/gather.asm
COUNTS = {1: 7, 2: 12, 4: 20, 5: 1, 7: 9}       # δείκτης -> πλήθος
DIGITS = open(os.path.join(os.path.dirname(HERE), 'data', 'digits.bin'),
              'rb').read()


def card_digit(c, x):
    """Το ψηφίο της κάρτας στο byte x (None αν δεν είναι κανένα)."""
    rows = []
    for l in range(5):
        y = MM.CARD_Y + l
        a = HUD_PAGE + (y & 7) * 0x800 + (y >> 3) * 80 + x
        rows += list(c.read_ram(a, 2))
    for d in range(11):
        if list(DIGITS[d * 10:d * 10 + 10]) == rows:
            return d
    return None


def card_bar(c):
    y = MM.CARD_BY
    a = HUD_PAGE + (y & 7) * 0x800 + (y >> 3) * 80 + MM.CARD_X
    return list(c.read_ram(a, 6))


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)
    for k, n in COUNTS.items():
        c.poke(SQ_N + k, n - 1)
        c.poke(S.UNIT_TAB + k * S.U_SIZE + U_LOOK, 255)    # ξανά σχεδίαση
    g.tick(3)
    sets = {k: S.unit(c, k)['set'] for k in COUNTS}
    g.report('αριθμός', all(s in (1, 2) for s in sets.values()) and
             g.compose('squads'),
             'πλήθη %s (σετ %s): η οθόνη = ο κόσμος με τους αριθμούς'
             % (COUNTS, sets))

    sel = M6.click_unit(g, 2)
    g.tick(3)
    tens, ones = card_digit(c, MM.CARD_X - 2), card_digit(c, MM.CARD_X)
    bar = card_bar(c)
    g.report('κάρτα', 2 in sel and (tens, ones) == (1, 2) and
             bar == [CARD_FULL] * 6,
             'επιλεγμένη η %s: στην κάρτα %s %s, μπάρα %s'
             % (sel, tens, ones, [hex(b) for b in bar]))

    g.move_cursor(60, 112)                      # κλικ σε άδειο έδαφος
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(3)
    tens, ones = card_digit(c, MM.CARD_X - 2), card_digit(c, MM.CARD_X)
    g.report('σβήσιμο', c.peek(sym['SEL_N']) == 0 and (tens, ones) ==
             (10, 10) and card_bar(c) == [CARD_EMPTY] * 6,
             'χωρίς επιλογή: στην κάρτα %s %s, μπάρα %s'
             % (tens, ones, [hex(b) for b in card_bar(c)]))
    print('\nM15 (φάση 1): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
