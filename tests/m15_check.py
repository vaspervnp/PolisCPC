"""M15, φάσεις 1-3: οι ομάδες στην οθόνη, η εκπαίδευση, η μάχη — σε headless
CPC 6128.

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
8. ΖΗΜΙΑ (φάση 3). Η ομάδα των 5 σπαθοφόρων (υγεία του μπροστινού 10)
   απέναντι σε εχθρική ομάδα 10 σπαθοφόρων (υγεία 60): το πρώτο της χτύπημα
   παίρνει από τον μπροστινό τους 5 x 8 = 40 x τυχαία 30-98% (12-39).
9. ΘΑΝΑΤΟΣ ΑΝΑ ΑΝΘΡΩΠΟ. Το πρώτο χτύπημα των εχθρών (8 x όσοι έχουν μείνει,
   x τυχαία): ο μπροστινός (10) πεθαίνει, το υπόλοιπο πάει στον επόμενο με
   γεμάτη υγεία (60), κι αν τη φτάνει, κι αυτός· ο πληθυσμός - όσοι πέθαναν.
10. ΣΕΙΡΑ. Η μικρότερη ομάδα (οι 5) χτυπάει πρώτη.
11. ΤΕΛΟΣ. Η μάχη ως το τέλος: ο πληθυσμός = το άθροισμα των πληθών.
12. ΤΡΕΙΣ. Ένας εχθρός μόνος του έρχεται στους 20 που στέκονται: το
    χτύπημά τους είναι το πολύ 3 x 8 = 24 x τυχαία (7-23), ζει.
13. ΠΡΩΤΟΣ. Κι ας στέκονται εκείνοι, ο ένας χτυπάει πρώτος.
14. ΕΝΩΣΗ (φάση 4). Μία ομάδα των 5 επιλεγμένη, RETURN πάνω σε δική μας
    ομάδα του ίδιου είδους (8): πάει εκεί και μπαίνει όλη (13), η εγγραφή
    της φεύγει.
15. ΠΕΡΙΣΣΕΥΟΥΝ. Οι 12 στους 13: μπαίνουν 7 (20), οι 5 μένουν, χωρίς
    εντολή.
16. ΧΩΡΙΣΜΟΣ. Η ομάδα των 20 επιλεγμένη, X: 10 και 10, η νέα στο διπλανό
    πλακίδιο, του ίδιου σετ.
17. ΠΛΗΘΥΣΜΟΣ. Ούτε η ένωση ούτε ο χωρισμός τον αλλάζουν.
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
import cpc as CPCMOD                            # noqa: E402
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
    return a, [k for k in [b] + new3 if k is not None]


C7_HP = 0x7E00
FOE = 43                        # σπαθοφόρος του αντιπάλου (της M4)


def after(n, hp, dmg, full=60):
    """Το πλήθος και η υγεία μετά από χτύπημα dmg (bank7.asm, hit)."""
    while dmg >= hp and n > 1:
        dmg, n, hp = dmg - hp, n - 1, full
    return (n, hp - dmg) if dmg < hp else (n, 0)


def dmg_range(per, n, target):
    """Οι δυνατές ζημιές (bank7.asm, sq_dmg): per x min(n, 3 x target), ως
    255, x f / 256 (f = 77 + 11/16 r, r = 0..255), στρογγυλεμένο, >= 1."""
    full = min(255, per * min(n, 3 * target))
    fs = {77 + (r >> 1) + (r >> 3) + (r >> 4) for r in range(256)}
    return {max(1, (full * f + 128) >> 8) for f in fs}


def state(c, k):
    return c.peek(SQ_N + k) + 1, S.c7_read(c, C7_HP + k)[0]


def fight(g, a, f, n=600):
    """Ως το πρώτο χτύπημα και των δύο -> (πρώτη αλλαγή, καρέ) της a, της f,
    και η f πριν από τη δική της αλλαγή."""
    c = g.c
    sa, sf = state(c, a), state(c, f)
    fa = ff = None
    foe = sf
    for t in range(n):
        if fa is None:
            foe = state(c, f)
        g.tick(1)
        if fa is None and state(c, a) != sa:
            fa = (state(c, a), t, M6.hud_vals(c, g.sym)[4])
        if ff is None and state(c, f) != sf:
            ff = (state(c, f), t)
        if fa and ff:
            break
    return fa, ff, foe


def phase3(g, a, quiet):
    c, sym = g.c, g.sym
    for k in quiet:                 # οι άλλοι του στρατώνα: όχι στη μάχη
        r = S.UNIT_TAB + k * S.U_SIZE + 11
        c.poke(r, c.peek(r) | S.F_WANDER)
    c.poke(SQ_N + a, 4)
    c.poke(S.UNIT_TAB + a * S.U_SIZE + U_LOOK, 255)
    S.c7_write(c, C7_HP + a, [10])
    pop0 = people(c)                # (το 20 -> 5 είναι του τεστ)
    c.poke(sym['HUD_VAL'] + 8, pop0 & 255)
    c.poke(sym['HUD_VAL'] + 9, pop0 >> 8)
    u = S.unit(c, a)
    M8.enemy(c, FOE, u['wx'] + 6, u['wy'])
    c.poke(SQ_N + FOE, 9)
    c.poke(S.UNIT_TAB + FOE * S.U_SIZE + U_LOOK, 255)
    S.c7_write(c, C7_HP + FOE, [60])
    sa, sf = state(c, a), state(c, FOE)
    fa, ff, foe = fight(g, a, FOE)
    ok = fa and ff
    ds = dmg_range(8, sa[0], sf[0])
    g.report('ζημιά', ok and ff[0][0] == sf[0] and 60 - ff[0][1] in ds,
             'η ομάδα των %d χτυπάει τους %d (υγεία %d): %s (ζημιά %d-%d)'
             % (sa[0], sf[0], sf[1], ff and ff[0], min(ds), max(ds)))
    ds = dmg_range(8, foe[0], sa[0])
    wants = {after(sa[0], sa[1], d) for d in ds}
    g.report('θάνατος', ok and fa[0] in wants and
             fa[2] == pop0 - (sa[0] - fa[0][0]),
             'οι %d (ζημιά %d-%d) χτυπούν τους %d (υγεία %d): πλήθος, υγεία '
             '%s· πληθυσμός %d -> %s'
             % (foe[0], min(ds), max(ds), sa[0], sa[1], fa and fa[0], pop0,
                fa and fa[2]))
    g.report('σειρά', ok and ff[1] <= fa[1],
             'η μικρότερη (%d) χτυπάει πρώτη: στο καρέ %s, η μεγάλη στο %s'
             % (sa[0], ff and ff[1], fa and fa[1]))
    for t in range(3000):
        g.tick(1)
        ta = c.peek(S.UNIT_TAB + a * S.U_SIZE + U_TEAM)
        tf = c.peek(S.UNIT_TAB + FOE * S.U_SIZE + U_TEAM)
        if ta != 0 or tf != 1:
            break
    g.tick(5)
    end = (state(c, a) if ta == 0 else 'νεκρή', state(c, FOE) if tf == 1
           else 'νεκρή')
    pe = M6.hud_vals(c, sym)[4]
    g.report('τέλος', pe == people(c) and (ta != 0 or tf != 1),
             'σε %d καρέ: η ομάδα %s, ο εχθρός %s· πληθυσμός %d, άθροισμα %d'
             % (t + 1, end[0], end[1], pe, people(c)))

    # ένας μόνος του (που έρχεται) απέναντι στους 20 (που στέκονται)
    k = quiet[0]
    r = S.UNIT_TAB + k * S.U_SIZE
    c.poke(r + 11, c.peek(r + 11) & ~(S.F_WANDER | S.F_MOVE) & 255)
    c.poke(SQ_N + k, SQ_MAX - 1)
    c.poke(r + U_LOOK, 255)
    S.c7_write(c, C7_HP + k, [60])
    f = [i for i in range(128)
         if c.peek(S.UNIT_TAB + i * S.U_SIZE + U_TEAM) == 255][0]
    u = S.unit(c, k)
    M8.enemy(c, f, u['wx'] + 24, u['wy'])
    c.poke(S.UNIT_TAB + f * S.U_SIZE + 8, 1)            # σπαθοφόρος
    c.poke(S.UNIT_TAB + f * S.U_SIZE + U_LOOK, 255)
    c.poke(SQ_N + f, 0)
    S.c7_write(c, C7_HP + f, [60])
    pop0 = people(c)
    c.poke(sym['HUD_VAL'] + 8, pop0 & 255)
    c.poke(sym['HUD_VAL'] + 9, pop0 >> 8)
    fk, ff, _ = fight(g, k, f)
    ok = fk and ff
    ds = dmg_range(8, SQ_MAX, 1)
    g.report('τρεις', ok and ff[0][0] == 1 and 60 - ff[0][1] in ds,
             'οι %d χτυπούν έναν (υγεία 60): %s — όσο 3 το πολύ (ζημιά %d-%d)'
             % (SQ_MAX, ff and ff[0], min(ds), max(ds)))
    ds = dmg_range(8, 1, SQ_MAX)
    g.report('πρώτος', ok and fk[1] <= ff[1] and
             fk[0] in {after(SQ_MAX, 60, d) for d in ds},
             'ο ένας χτυπάει πρώτος: στο καρέ %s %s, οι %d στο %s'
             % (fk and fk[1], fk and fk[0], SQ_MAX, ff and ff[1]))
    return [FOE, f, k]


def team(c, k):
    return c.peek(S.UNIT_TAB + k * S.U_SIZE + U_TEAM)


def cnt(c, k):
    return c.peek(SQ_N + k) + 1


def return_on(g, k):
    """Ο κέρσορας πάνω στη μονάδα k (όπως το κλικ), και RETURN."""
    u = S.unit(g.c, k)
    x0, y0 = g.cursor()
    g.move_cursor(u['sx'] + (x0 - u['sx']) % 2, u['sy'] + (y0 - u['sy']) % 6)
    g.c.key_down(CPCMOD.KEY_RETURN)
    g.tick(1)
    g.c.key_up(CPCMOD.KEY_RETURN)
    g.tick(1)


def phase4(g, away):
    c, sym = g.c, g.sym
    for k in away:                  # η μάχη της φάσης 3: όχι πια
        r = S.UNIT_TAB + k * S.U_SIZE + 11
        c.poke(r, c.peek(r) | S.F_WANDER)
    A, B, C = 1, 4, 7               # σπαθοφόροι (σετ 1)
    u = S.unit(c, B)
    for k, n, dx, dy in ((A, 5, -16, 0), (B, 8, 0, 0), (C, 12, 0, 24)):
        M8.place(c, k, u['wx'] + dx, u['wy'] + dy, u['wx'] + dx + 1)
        c.poke(SQ_N + k, n - 1)
        c.poke(S.UNIT_TAB + k * S.U_SIZE + U_LOOK, 255)
    pop0 = people(c)
    c.poke(sym['HUD_VAL'] + 8, pop0 & 255)
    c.poke(sym['HUD_VAL'] + 9, pop0 >> 8)
    g.tick(20)
    pops = []

    sel = M6.click_unit(g, A)
    return_on(g, B)
    for t in range(600):
        g.tick(1)
        if team(c, A) != 0:
            break
    g.tick(5)
    pops.append((M6.hud_vals(c, sym)[4], people(c)))
    g.report('ένωση', sel == {A} and team(c, A) != 0 and cnt(c, B) == 13,
             'επιλεγμένη %s (5), RETURN πάνω στην %d (8): σε %d καρέ η %d %s, '
             'η %d με %d' % (sel, B, t + 1, A, 'έφυγε' if team(c, A) != 0
                             else 'ακόμα εδώ', B, cnt(c, B)))

    sel = M6.click_unit(g, C)
    return_on(g, B)
    for t in range(600):
        g.tick(1)
        if cnt(c, B) == SQ_MAX:
            break
    g.tick(30)
    pops.append((M6.hud_vals(c, sym)[4], people(c)))
    g.report('περισσεύουν', sel == {C} and cnt(c, B) == SQ_MAX and
             team(c, C) == 0 and cnt(c, C) == 5 and
             S.c7_read(c, 0x7F00 + C)[0] == 255,
             'οι 12 στους 13: η %d με %d, η %d με %d (εντολή %d)'
             % (B, cnt(c, B), C, cnt(c, C), S.c7_read(c, 0x7F00 + C)[0]))

    sel = M6.click_unit(g, B)
    before = {k for k in range(S.UNITS) if team(c, k) != 255}
    M7.press(g, 'x')
    g.tick(5)
    new = [k for k in range(S.UNITS) if k not in before and team(c, k) == 0]
    t0, t1 = M5.unit_tile(S.unit(c, B)), new and M5.unit_tile(S.unit(c, new[0]))
    pops.append((M6.hud_vals(c, sym)[4], people(c)))
    g.report('χωρισμός', sel == {B} and len(new) == 1 and cnt(c, B) == 10 and
             cnt(c, new[0]) == 10 and S.unit(c, new[0])['set'] == 1 and
             max(abs(a - b) for a, b in zip(t0, t1)) <= 1,
             'X στην %d (20): %d, νέα %s με %s, στο %s (η παλιά στο %s)'
             % (B, cnt(c, B), new, [cnt(c, k) for k in new], t1, t0))
    g.report('πληθυσμός', all(p == q == pop0 for p, q in pops),
             'μπάρα / άθροισμα: %s (πριν %d)' % (pops, pop0))


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
    a, quiet = phase2(g)
    if a is not None:
        phase4(g, phase3(g, a, quiet))
    print('\nM15 (φάσεις 1-4): %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
