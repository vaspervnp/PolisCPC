"""M7: κτίρια — σε headless CPC 6128.

    python3 tests/m7_check.py [--shots]

Με τα πλήκτρα του παίκτη (Q A O P, SPACE, RETURN, B R T ESC):

1. ΑΡΧΗ. Το Κέντρο Πόλης είναι στον χάρτη: η οθόνη είναι pixel προς pixel
   ο κόσμος του mockup με την εικόνα του (src/make_bank6.py), και η κάτοψή
   του (30..33, 58..61) είναι εμπόδιο.
2. ΔΕΝΤΡΟ. Με τους χωρικούς της πόλης επιλεγμένους, R (σκοπευτήριο) ΔΕΝ
   ανοίγει τοποθέτηση: θέλει στρατώνα.
3. ΣΤΡΑΤΩΝΑΣ. B, ο κέρσορας στο (37, 61), RETURN: θεμέλιο (το έδαφος της
   κάτοψης γίνεται χώμα), ξύλο 200 -> 75, οι χωρικοί πάνε και τον χτίζουν.
   Όταν τελειώσει: η οθόνη = ο κόσμος με Κέντρο Πόλης ΚΑΙ στρατώνα, με τις
   μονάδες από πάνω, και η κάτοψη είναι εμπόδιο.
4. ΔΕΝΤΡΟ ΞΑΝΑ. Τώρα (με αρκετό ξύλο) το R ανοίγει τοποθέτηση (ο κέρσορας
   γίνεται γωνία)· ESC την κλείνει.
5. ΔΥΟ ΣΠΑΘΟΦΟΡΟΙ. Κλικ στον στρατώνα, T δύο φορές: τροφή 200 -> 130, χρυσός
   100 -> 70. Βγαίνουν δύο σπαθοφόροι (σετ 1, ομάδα του παίκτη) δίπλα του, ο
   πληθυσμός 12 -> 14, και η μπάρα το δείχνει.
6. ΔΙΑΒΑΣΗ. Μια μονάδα στέλνεται από τη μία πλευρά του στρατώνα στην άλλη
   (ο ευθύς δρόμος περνάει από μέσα): φτάνει, χωρίς να πατήσει ποτέ στην
   κάτοψη.
7. ΧΡΟΝΟΣ. Κάθε καρέ χωρίς κύλιση < 40 ms.
"""
import collections
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m4_check as M4                           # noqa: E402
import m5_check as M5                           # noqa: E402
import m6_check as M6                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import make_bank6 as MB                         # noqa: E402

# οι θέσεις των κτιρίων: 16 στο #A400 και 12 στο #BE40 (game/buildings.asm)
BLD_SLOTS = [0xA400 + k * 16 for k in range(16)] + \
    [0xBE40 + k * 16 for k in range(12)]
B_SIZE, BLD_MAX = 16, 28
HUD_PAGE = 0x4000
SPR_MARK, ANCHOR_REC = 0x7280, S.ANCHOR_REC
MAP = 0x8000
BARRACKS = (37, 61)             # το κέντρο της κάτοψης (i0 = 36, j0 = 60)
TC = (30, 58, 4)
QMAX = 5


def blds(c, own=0):
    """Τα κτίρια του παίκτη (own = 1: του αντιπάλου, None: όλα, M10)."""
    out = []
    for k in range(BLD_MAX):
        b = c.read_ram(BLD_SLOTS[k], B_SIZE)
        if b[0] != 255 and own in (None, b[1]):
            out.append(dict(slot=k, type=MB.KEYS[b[0]], own=b[1], i0=b[2],
                            j0=b[3], st=b[4], prog=b[14], qn=b[15]))
    return out


class Nav(M5.Nav):
    """Τα εμπόδια του χάρτη ΚΑΙ οι κατόψεις των κτιρίων."""
    def __init__(self):
        super().__init__()
        self.foot = set()

    def add(self, i0, j0, n):
        self.foot |= {(i, j) for i in range(i0, i0 + n)
                      for j in range(j0, j0 + n)}

    def blocked(self, i, j):
        return (i, j) in self.foot or super().blocked(i, j)


def hud_addr(y, x):
    return HUD_PAGE + (y & 7) * 0x800 + (y >> 3) * 80 + x


def card(c):
    """Η κάρτα του HUD: (ψηφίο ή None αν κενή, pixels της μπάρας ή None αν
    η μπάρα δεν είναι γεμάτη από αριστερά)."""
    glyph = M6.MM.digit_glyphs()
    rows = [list(c.read_ram(hud_addr(M6.MM.CARD_Y + l, M6.MM.CARD_X), 2))
            for l in range(5)]
    dig = [d for d in range(11) if rows == [glyph[d * 10 + 2 * l:
                                                  d * 10 + 2 * l + 2]
                                            for l in range(5)]]
    bar = list(c.read_ram(hud_addr(M6.MM.CARD_BY, M6.MM.CARD_X), 6))
    val = {M6.MM.card_byte(n): n for n in (2, 1, 0)}
    px = [val.get(b, -1) for b in bar]
    ok = -1 not in px and px == sorted(px, reverse=True) and px.count(1) <= 1
    return (dig[0] if dig and dig[0] < 10 else None), (sum(px) if ok else None)


def marked(c):
    """Το σημάδι του επιλεγμένου κτιρίου φαίνεται."""
    a = S.rec(c, ANCHOR_REC)
    return a['frame'] == SPR_MARK and a['drawn'] & 1 and a['sy'] != 255


def fake_bld(c, sym, slot, typ, st=1):
    """Μια εγγραφή κτιρίου έξω από τον χάρτη (WX #4000: ποτέ στην οθόνη)."""
    rec = bytearray([255] * B_SIZE)
    rec[0], rec[1], rec[2], rec[3], rec[4] = MB.KEYS.index(typ), 0, 90, 90, st
    rec[6:10] = bytes([0, 0x40, 0, 0])
    rec[14], rec[15] = 0, 0
    for k, b in enumerate(rec):
        c.poke(BLD_SLOTS[slot] + k, b)
    top = sym['BLD_TOP']                  # οι βρόχοι ως εκεί (bld_new)
    c.poke(top, max(c.peek(top), slot + 1))


def cmd_cursor(g, i, j):
    """Ο κέρσορας για να πάει ΜΙΑ μονάδα στο πλακίδιο (i, j): ο στόχος της
    πρώτης του σχηματισμού είναι τα πόδια στο (cw_x - 7, cw_y) — do_command."""
    c, sym = g.c, g.sym
    cx, cy = M4.M2.cam(c, sym)
    x0, y0 = g.cursor()
    fx, fy = 2 * (i - j) + 192, 4 * (i + j) + 4
    best = None
    for x in range(x0 % 2, 77, 2):
        for y in range(y0 % 6, 129, 6):
            if M5.feet_tile(cx + x - 7, cy + y) == (i, j):
                d = abs(cx + x - 7 - fx) * 2 + abs(cy + y - fy)
                if best is None or d < best[0]:
                    best = (d, x, y)
    assert best, 'το πλακίδιο %s δεν φαίνεται' % ((i, j),)
    return best[1], best[2]


def press(g, key, n=2):
    g.c.key_down(key)
    g.tick(n)
    g.c.key_up(key)
    g.tick(2)


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    nav = Nav()
    nav.add(*TC)
    g.tick(3)
    grd, res = M4.M.mockup.make_map()

    # ------------------------------------------------- 1. αρχή
    bs = blds(c)
    foot_ok = all(c.peek(MAP + j * 96 + i) & 15 == MB.BLD_RES
                  for i in range(30, 34) for j in range(58, 62))
    g.report('αρχή', g.compose('start') and len(bs) == 1 and
             bs[0]['type'] == 'town_center' and bs[0]['st'] == 1 and foot_ok,
             'το Κέντρο Πόλης στον χάρτη και στην οθόνη, η κάτοψή του εμπόδιο')

    # ------------------------------------------------- 2. δέντρο: όχι ακόμα
    g.move_cursor(8, 40)                    # κουτί γύρω από τους 12 της πόλης
    c.key_down(' ')
    g.tick(2)
    g.move_cursor(60, 106)
    c.key_up(' ')
    g.tick(2)
    sel = {u['idx'] for u in S.units(c) if u['fl'] & S.F_SEL}
    press(g, 'r')
    g.report('δέντρο', 0 in sel and c.peek(sym['BMODE']) == 255,
             'επιλεγμένες %d (με τους χωρικούς)· R: το σκοπευτήριο θέλει '
             'στρατώνα — καμία τοποθέτηση' % len(sel))

    # ------------------------------------------------- 3. στρατώνας
    vals0 = M6.hud_vals(c, sym)
    press(g, 'b')
    mode = c.peek(sym['BMODE'])
    g.move_cursor(*M6.tile_cursor(g, *BARRACKS))
    press(g, CPCMOD.KEY_RETURN, 1)
    bs = blds(c)
    bar = [b for b in bs if b['type'] == 'barracks']
    vals1 = M6.hud_vals(c, sym)
    i0, j0 = BARRACKS[0] - 1, BARRACKS[1] - 1
    found = bar and (bar[0]['i0'], bar[0]['j0'], bar[0]['st']) == (i0, j0, 0) \
        and all(c.peek(MAP + j * 96 + i) == (4 << 4 | MB.BLD_RES)
                for i in range(i0, i0 + 3) for j in range(j0, j0 + 3))
    builders = [v for v in M6.VILLAGERS
                if c.peek(S.UNIT_TAB + v * S.U_SIZE + M6.U_JOB) == 4]
    g.report('θεμέλιο', mode == MB.KEYS.index('barracks') and found and
             vals1[1] == vals0[1] - 125 and builders,
             'B -> τύπος %d· θεμέλιο στο (%d, %d), ξύλο %d -> %d, χτίζουν οι '
             'χωρικοί %s' % (mode, i0, j0, vals0[1], vals1[1], builders))
    nav.add(i0, j0, 3)
    for k in range(60):                     # η επανασχεδίαση του θεμελίου
        g.tick(1)
        if c.peek(sym['RQ_N']) == 255:
            break
    g.world = M4.M.game_world(grd, res, found=[('barracks', i0, j0)])
    g.report('σύνθεση', g.compose('foundation'), 'το θεμέλιο στην οθόνη '
             '(χώμα στην κάτοψη), με τις μονάδες από πάνω')
    on_block = []
    pos = {}
    for k in range(1500):
        g.tick(1)
        for v in M6.VILLAGERS:
            u = S.unit(c, v)
            p = (u['wx'], u['wy'])
            if p != pos.get(v) and v in pos and nav.blocked(*M5.unit_tile(u)):
                on_block.append((v, p))
            pos[v] = p
        if blds(c)[-1]['st'] == 1 and c.peek(sym['RQ_N']) == 255:
            break
    done = [b for b in blds(c) if b['type'] == 'barracks'][0]['st'] == 1
    g.report('χτίστηκε', done, 'σε %d καρέ (%d πόντοι)'
             % (k + 1, MB.TYPES[2][4]))
    g.tick(2)
    g.world = M4.M.game_world(grd, res, blds=M4.M.GAME_BLDS + [
        ('barracks', i0, j0)], found=[('barracks', i0, j0)])
    g.report('σύνθεση', g.compose('barracks'), 'ο στρατώνας στην οθόνη '
             '(εικόνα της Εποχής Εργαλείων), με τις μονάδες από πάνω')

    # ------------------------------------------------- 4. δέντρο: τώρα ναι
    c.poke(sym['HUD_VAL'] + 2, 300 & 255)   # ξύλο για σκοπευτήριο (150): το
    c.poke(sym['HUD_VAL'] + 3, 300 >> 8)    # R ελέγχει και το κόστος
    c.poke(sym['HUD_DIRTY'], c.peek(sym['HUD_DIRTY']) | 2)   # και στη μπάρα
    press(g, 'r')
    m_r = c.peek(sym['BMODE'])
    press(g, CPCMOD.KEY_ESC)
    g.report('δέντρο', m_r == MB.KEYS.index('archery') and
             c.peek(sym['BMODE']) == 255,
             'με στρατώνα το R ανοίγει τοποθέτηση σκοπευτηρίου, το ESC την '
             'κλείνει')

    # ------------------------------------------------- 5. δύο σπαθοφόροι
    fx, fy = 2 * (i0 + 2 - (j0 + 2)) + 192, 4 * (i0 + j0 + 4) + 4  # (38, 62)
    cx, cy = M4.M2.cam(c, sym)
    tx, ty = M6.tile_cursor(g, i0 + 2, j0 + 2)
    g.move_cursor(tx, ty)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(2)
    slot = [b for b in blds(c) if b['type'] == 'barracks'][0]['slot']
    picked = c.peek(sym['SEL_BLD'])
    v0 = M6.hud_vals(c, sym)
    press(g, 't')
    press(g, 't')
    v1 = M6.hud_vals(c, sym)
    qn = [b for b in blds(c) if b['type'] == 'barracks'][0]['qn']
    g.tick(20)
    cd = card(c)
    g.report('κάρτα', cd[0] == 2 and cd[1] is not None and 0 < cd[1] < 12 and
             marked(c),
             'το HUD δείχνει ουρά %s και πρόοδο %s/12 pixels· το σημάδι στο '
             'κτίριο: %s' % (cd[0], cd[1], bool(marked(c))))
    g.report('ουρά', picked == slot and qn == 2 and v1[0] == v0[0] - 70 and
             v1[2] == v0[2] - 30,
             'κλικ στον στρατώνα (θέση %d), T x 2: ουρά %d, τροφή %d -> %d, '
             'χρυσός %d -> %d' % (picked, qn, v0[0], v1[0], v0[2], v1[2]))
    before = {u['idx'] for u in S.units(c)
              if c.peek(S.UNIT_TAB + u['idx'] * S.U_SIZE + 28) != 255}
    for kt in range(700):
        g.tick(1)
        if [b for b in blds(c) if b['type'] == 'barracks'][0]['qn'] == 0:
            break
    g.tick(2)
    tab = [c.read_ram(S.UNIT_TAB + k * S.U_SIZE, S.U_SIZE) for k in range(128)]
    new = [k for k in range(128) if tab[k][28] != 255 and k not in before]
    near = []
    for k in new:
        u = S.unit(c, k)
        i, j = M5.unit_tile(u)
        near.append(i0 - 1 <= i <= i0 + 3 and j0 - 1 <= j <= j0 + 3)
    vals = M6.hud_vals(c, sym)
    g.report('σπαθοφόροι', len(new) == 2 and all(tab[k][8] == 1 and
                                                 tab[k][28] == 0 for k in new)
             and all(near) and vals[4] == 14 and M6.hud_ok(c, vals),
             'σε %d καρέ: νέες μονάδες %s (σετ %s), δίπλα στον στρατώνα· '
             'πληθυσμός %d, η μπάρα %s' % (kt + 1, new, [tab[k][8] for k in new],
                                           vals[4], vals))
    cd = card(c)
    g.report('κάρτα', cd == (0, 0) and marked(c),
             'άδεια ουρά: ψηφίο %s, μπάρα %s pixels' % cd)
    g.report('σύνθεση', g.compose('trained'), 'οι δύο σπαθοφόροι στην οθόνη, '
             'και το σημάδι στον επιλεγμένο στρατώνα')

    # ------------------------------------------------- 6. διάβαση
    u5 = S.unit(c, 5)                       # τοξότης, δυτικά του στρατώνα
    g.move_cursor(u5['sx'] + (g.cursor()[0] - u5['sx']) % 2,
                  u5['sy'] + (g.cursor()[1] - u5['sy']) % 6)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(2)
    sel = {u['idx'] for u in S.units(c) if u['fl'] & S.F_SEL}
    goal = (41, 61)
    g.move_cursor(*M6.tile_cursor(g, *goal))
    press(g, CPCMOD.KEY_RETURN, 1)
    u = S.unit(c, 5)
    start, target = (u['wx'], u['wy']), (u['tx'], u['ty'])
    crosses = any(nav.foot and (M5.feet_tile(
        start[0] + 2 + (target[0] - start[0]) * k // 64,
        start[1] + 14 + (target[1] - start[1]) * k // 64) in
        {(i, j) for i in range(i0, i0 + 3) for j in range(j0, j0 + 3)})
        for k in range(65))
    trail, inside = [start], []
    foot = {(i, j) for i in range(i0, i0 + 3) for j in range(j0, j0 + 3)}
    for k in range(600):
        g.tick(1)
        u = S.unit(c, 5)
        p = (u['wx'], u['wy'])
        if p != trail[-1]:
            trail.append(p)
            if M5.unit_tile(u) in foot:
                inside.append(p)
        if not u['fl'] & S.F_MOVE:
            break
    g.report('διάβαση', sel == {5} and crosses and trail[-1] == target and
             not inside,
             'από %s σε %s (ο ευθύς δρόμος περνάει από τον στρατώνα): έφτασε '
             'σε %d βήματα, ποτέ μέσα στην κάτοψη%s'
             % (start, target, len(trail) - 1,
                '' if not inside else ': %s' % inside[:3]))
    g.report('εμπόδια', not on_block, 'κανένας χωρικός σε εμπόδιο όσο έχτιζε%s'
             % ('' if not on_block else ': %s' % on_block[:3]))

    cd = card(c)
    g.report('κάρτα', cd == (None, 0) and not marked(c),
             'καμία επιλογή κτιρίου: η κάρτα κενή, κανένα σημάδι')

    # ------------------------------------------------- 7. πίσω από κτίριο
    behind = (29, 59)                       # αριστερά, πίσω από το Κέντρο Πόλης
    near = min((abs(M5.unit_tile(x)[0] - behind[0]) +   # η πιο κοντινή της
                abs(M5.unit_tile(x)[1] - behind[1]), x['idx'])   # πόλης, από
               for x in S.units(c)[:12] if x['idx'] not in M6.VILLAGERS)[1]
    sel = M6.click_unit(g, near)            # τα δυτικά: χωρίς εμπόδιο
    v = min(sel)
    g.move_cursor(*cmd_cursor(g, *behind))
    press(g, CPCMOD.KEY_RETURN, 1)
    for k in range(600):
        g.tick(1)
        if not S.unit(c, v)['fl'] & S.F_MOVE:
            break
    g.tick(2)
    u = S.unit(c, v)
    hid = S.hidden(u, S.buildings(c))
    g.report('πίσω', len(sel) == 1 and M5.unit_tile(u) == behind and hid,
             'η μονάδα %d στο %s, πίσω από το Κέντρο Πόλης: κρύβεται %s%s'
             % (v, M5.unit_tile(u), hid, '' if hid else
                ' (επιλογή %s, στόχος %s, %d καρέ)'
                % (sorted(sel), M5.feet_tile(u['tx'] + 2, u['ty'] + 14),
                   k + 1)))
    g.report('σύνθεση', g.compose('behind'), 'μόνο το περίγραμμά του, στο pen '
             'της ομάδας, πάνω στο κτίριο')

    # ------------------------------------------------- 8. αποθήκη
    for k, v in ((0, 9999), (1, 9999), (2, 9999)):
        c.poke(sym['HUD_VAL'] + 2 * k, v & 255)
        c.poke(sym['HUD_VAL'] + 2 * k + 1, v >> 8)
    c.poke(sym['HUD_DIRTY'], c.peek(sym['HUD_DIRTY']) | 7)
    sel = M6.click_unit(g, 0)
    v = min(sel)
    press(g, 's')
    pit = (31, 72)
    g.move_cursor(*M6.tile_cursor(g, *pit))
    press(g, CPCMOD.KEY_RETURN, 1)
    nav.add(pit[0], pit[1], 2)
    for k in range(1500):
        g.tick(1)
        p = [b for b in blds(c) if b['type'] == 'storage_pit']
        if p and p[0]['st'] == 1 and c.peek(sym['RQ_N']) == 255:
            break
    built = p and p[0]['st'] == 1
    g.report('αποθήκη', len(sel) == 1 and v in M6.VILLAGERS and built,
             'S, RETURN στο %s: ο χωρικός %d την έχτισε σε %d καρέ%s'
             % (pit, v, k + 1, '' if built and len(sel) == 1 else
                ' — επιλογή %s, %s' % (sorted(sel), p)))
    M6.command(g, M6.TREE)
    drops, carry0 = [], 0
    w0 = M6.hud_vals(c, sym)[1]
    for k in range(2500):
        g.tick(1)
        cr = c.peek(M6.J_CARRY + v)
        if carry0 and not cr:
            drops.append(M5.unit_tile(S.unit(c, v)))
        carry0 = cr
        if len(drops) == 2:
            break
    ring = {(i, j) for i in range(pit[0] - 1, pit[0] + 3)
            for j in range(pit[1] - 1, pit[1] + 3)}
    w1 = M6.hud_vals(c, sym)[1]
    g.report('απόθεση', len(drops) == 2 and all(d in ring for d in drops) and
             w1 > w0,
             'ο χωρικός κόβει στο %s και αδειάζει στην αποθήκη (όχι στο '
             'Κέντρο Πόλης): στα %s, ξύλο %d -> %d'
             % (M6.TREE, drops, w0, w1))

    # ------------------------------------------------- 9. πληθυσμός
    for t in [(i0 + a, j0 + b) for a in (2, 1, 0) for b in (2, 1, 0)]:
        g.move_cursor(*M6.tile_cursor(g, *t))  # ένα πλακίδιο χωρίς μονάδα
        c.key_down(' ')
        g.tick(2)
        c.key_up(' ')
        g.tick(2)
        if c.peek(sym['SEL_BLD']) == slot:
            break
    pop = M6.hud_vals(c, sym)[4]
    for k in range(3):
        press(g, 't')
    q1 = [b for b in blds(c) if b['type'] == 'barracks'][0]['qn']
    free = [k for k in range(BLD_MAX) if c.peek(BLD_SLOTS[k]) == 255]
    fake_bld(c, sym, free[0], 'house')
    for k in range(3):
        press(g, 't')
    q2 = [b for b in blds(c) if b['type'] == 'barracks'][0]['qn']
    g.report('πληθυσμός', q1 == max(0, min(3, 15 - pop)) and
             q2 == max(0, min(q1 + 3, QMAX, 20 - pop)),
             'πληθυσμός %d, όριο 15: T x 3 -> ουρά %d· με ένα σπίτι (όριο 20) '
             'T x 3 -> ουρά %d (επιλογή %d)' % (pop, q1, q2,
                                                c.peek(sym['SEL_BLD'])))

    # ------------------------------------------------- 10. 28 κτίρια
    free = [k for k in range(BLD_MAX) if c.peek(BLD_SLOTS[k]) == 255]
    for k in free[:-1]:
        fake_bld(c, sym, k, 'house')
    sel = M6.click_unit(g, 3)
    house = (26, 66)
    press(g, 'h')
    g.move_cursor(*M6.tile_cursor(g, *house))
    press(g, CPCMOD.KEY_RETURN, 1)
    n1 = len(blds(c, None))             # (και το Κέντρο του αντιπάλου, M10)
    last = [b for b in blds(c) if b['slot'] == BLD_MAX - 1]
    press(g, 'h')
    g.move_cursor(*M6.tile_cursor(g, house[0] + 3, house[1]))
    press(g, CPCMOD.KEY_RETURN, 1)
    n2 = len(blds(c, None))
    g.tick(5)
    g.report('28 κτίρια', n1 == BLD_MAX and n2 == BLD_MAX and last and
             (last[0]['i0'], last[0]['j0']) == house,
             'με %d θέσεις γεμάτες, το H βάζει θεμέλιο στην τελευταία (%s), '
             'και το επόμενο δεν χωράει: %d κτίρια' % (BLD_MAX - 1, last and
                                                       last[0]['slot'], n2))

    # ------------------------------------------------- 11. χρόνος
    # Μέτρηση, όχι κριτήριο (M9): οι 56 που περιπλανιούνται (M10) αποφασίζουν
    # με το rnd, και το όριο βημάτων (T_BUDGET) τις μετατοπίζει κατά ένα καρέ
    # εδώ κι εκεί — όποια αλλαγή χρόνου φέρνει άλλες στην οθόνη, και το
    # μέγιστο κινείται ±5 ms από build σε build (το M3 / M4, ελεγχόμενα,
    # μένουν ίδια).
    still = [t for t, m in zip(g.times, g.scrolled) if not m]
    over = [t for t in still if t >= 40]
    print('%-8s %-9s καρέ χωρίς κύλιση: μέσος %.1f ms, μέγιστος %.1f ms, %d '
          'από τα %d πάνω από 40 (μέτρηση: με τις 56 που περιπλανιούνται)'
          % ('χρόνος', '<40' if not over else 'ΠΑΝΩ', sum(still) / len(still),
             max(still), len(over), len(still)))
    if g.shots:
        c.screenshot(os.path.join(M4.M.BUILD, 'm7_barracks.png'), aspect=True)
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
