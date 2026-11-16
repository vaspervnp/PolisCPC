"""M15, φάσεις 1-2: οι ομάδες στην οθόνη και η εκπαίδευση — σε headless CPC 6128.

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
4. ΕΚΠΑΙΔΕΥΣΗ (φάση 2). Ένας στρατώνας μακριά από τους στρατιώτες της
   πόλης (και τέσσερα σπίτια: χώρος στον πληθυσμό), T x 3: ΕΝΑ νέο πιόνι
   σπαθοφόρων με πλήθος 3 (ο δεύτερος και ο τρίτος μπαίνουν στην ομάδα του
   πρώτου, που στέκεται δίπλα)· ο πληθυσμός +3.
5. ΓΕΜΑΤΗ. Η ομάδα με πλήθος SQ_MAX: ο επόμενος γίνεται νέο πιόνι του 1.
6. ΜΑΚΡΙΑ. Το πιόνι του 1 πάει μακριά (πάνω από 3 πλακίδια από τον
   στρατώνα): ο επόμενος πάλι νέο πιόνι, όχι μαζί του.
7. ΠΛΗΘΥΣΜΟΣ. Σε όλη τη διαδρομή ο πληθυσμός της μπάρας = το άθροισμα των
   πληθών των ζωντανών μονάδων του παίκτη.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import m8_check as M8                           # noqa: E402
import m9_check as M9                           # noqa: E402
import make_map as MM                           # noqa: E402
import m5_check as M5                           # noqa: E402
import scene as S                               # noqa: E402

SQ_N, SQ_MAX = 0x3F00, 20
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


BARR = (40, 72)                 # B_I, B_J: κανένας σπαθοφόρος της πόλης ως
                                # 3 πλακίδια, κανένας εχθρός κοντά
U_TEAM = 28


def people(c):
    """Το άθροισμα των πληθών των ζωντανών μονάδων του παίκτη."""
    return sum(c.peek(SQ_N + k) + 1 for k in range(S.UNITS)
               if c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM) == 0)


def train(g, slot, n):
    """T x n στον στρατώνα και αναμονή ως το τέλος της ουράς -> οι νέες
    θέσεις του πίνακα (δείκτες)."""
    c, sym = g.c, g.sym
    before = {k for k in range(S.UNITS)
              if c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM) != 255}
    c.poke(sym['SEL_BLD'], slot)
    for _ in range(n):
        M7.press(g, 't')
    for _ in range(400 * n):
        g.tick(1)
        if c.peek(sym['BQ_TOT']) == 0:
            break
    g.tick(3)
    return [k for k in range(S.UNITS) if k not in before and
            c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM) != 255]


def phase2(g):
    c, sym = g.c, g.sym
    for k in COUNTS:                            # ξανά μόνοι τους (φάση 1)
        c.poke(SQ_N + k, 0)
        c.poke(S.UNIT_TAB + k * S.U_SIZE + U_LOOK, 255)
    M9.set_res(c, sym, 3000)
    free = [k for k in range(M7.BLD_MAX) if c.peek(M7.BLD_SLOTS[k]) == 255]
    bar = free[0]
    M7.fake_bld(c, sym, bar, 'barracks')
    c.poke(M7.BLD_SLOTS[bar] + 2, BARR[0])
    c.poke(M7.BLD_SLOTS[bar] + 3, BARR[1])
    for h in free[1:5]:                         # όριο 15 + 4 x 5 = 35
        M7.fake_bld(c, sym, h, 'house')
    pops = []

    pop0 = M6.hud_vals(c, sym)[4]
    new = train(g, bar, 3)
    pop1 = M6.hud_vals(c, sym)[4]
    pops.append((pop1, people(c)))
    a = new[0] if len(new) == 1 else None
    g.report('εκπαίδευση', a is not None and S.unit(c, a)['set'] == 1 and
             c.peek(SQ_N + a) == 2 and pop1 == pop0 + 3,
             'T x 3: νέα πιόνια %s, πλήθος %s· πληθυσμός %d -> %d'
             % (new, [c.peek(SQ_N + k) + 1 for k in new], pop0, pop1))

    if a is not None:
        c.poke(SQ_N + a, SQ_MAX - 1)
        c.poke(S.UNIT_TAB + a * S.U_SIZE + U_LOOK, 255)
    pop1 = M6.hud_vals(c, sym)[4]               # (το 20 είναι του τεστ)
    c.poke(sym['HUD_VAL'] + 8, (pop1 + SQ_MAX - 3) & 255)
    c.poke(sym['HUD_VAL'] + 9, (pop1 + SQ_MAX - 3) >> 8)
    pop1 = M6.hud_vals(c, sym)[4]
    new2 = train(g, bar, 1)
    pop2 = M6.hud_vals(c, sym)[4]
    pops.append((pop2, people(c)))
    b = new2[0] if len(new2) == 1 else None
    g.report('γεμάτη', b is not None and c.peek(SQ_N + b) == 0 and
             a is not None and c.peek(SQ_N + a) == SQ_MAX - 1 and
             pop2 == pop1 + 1,
             'ομάδα %s με %d: ο επόμενος νέο πιόνι %s του %s· πληθυσμός '
             '%d -> %d' % (a, SQ_MAX, new2,
                           [c.peek(SQ_N + k) + 1 for k in new2], pop1, pop2))

    far = None
    if b is not None:
        u = S.unit(c, b)
        M8.place(c, b, u['wx'] + 40, u['wy'] + 40, u['wx'] + 44)
        g.tick(60)
        far = M5.unit_tile(S.unit(c, b))
    new3 = train(g, bar, 1)
    pop3 = M6.hud_vals(c, sym)[4]
    pops.append((pop3, people(c)))
    g.report('μακριά', b is not None and len(new3) == 1 and new3[0] != b and
             c.peek(SQ_N + b) == 0 and c.peek(SQ_N + new3[0]) == 0 and
             pop3 == pop2 + 1,
             'το πιόνι %s του 1 στο %s: ο επόμενος νέο πιόνι %s· πληθυσμός '
             '%d -> %d' % (b, far, new3, pop2, pop3))
    g.report('πληθυσμός', all(p == q for p, q in pops),
             'μπάρα / άθροισμα των πληθών: %s' % pops)


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
    phase2(g)
    print('\nM15 (φάσεις 1-2): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
