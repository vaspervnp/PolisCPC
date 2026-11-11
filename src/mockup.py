"""Ένας ολόκληρος χάρτης και η οθόνη πάνω του — ο μόνος τρόπος να κριθεί
το σύνολο.

    python3 src/mockup.py

Βγάζει τρία αρχεία στο preview/:

    screen.png  μία οθόνη 160x200: χάρτης, HUD, μονάδες μαζί
    map.png     ΟΛΟΣ ο χάρτης 96x96, με το πλέγμα των οθονών από πάνω —
                για να φαίνεται πόσες οθόνες είναι και τι έχει μέσα
    scroll.gif  η κάμερα περνάει πάνω από τον χάρτη, με τον μίνι χάρτη να
                ακολουθεί: η κύλιση όπως θα τη δει ο παίκτης

Ο ΧΑΡΤΗΣ ΕΙΝΑΙ 96x96 ΠΛΑΚΙΔΙΑ, ΔΗΛΑΔΗ ~12,8 ΟΘΟΝΕΣ

Ο ισομετρικός χάρτης είναι ρόμβος 8N pixels πλάτος x 8N γραμμές ύψος, άρα
εμβαδόν 32·N² pixels. Το παράθυρο χάρτη είναι 160x144. Με N=96:
32·96² / (160·144) = 12,8 οθόνες — πάνω από τις 9 που ζητήθηκαν. Ο χάρτης
είναι ένα byte ανά πλακίδιο, 9.216 bytes: χωράει σε μία τράπεζα.

Τα contact sheets δείχνουν αν ΕΝΑ πλακίδιο είναι καλό. Δεν δείχνουν αν ο
χάρτης διαβάζεται, αν τα δέντρα χάνονται μέσα στο γρασίδι, αν το HUD χωράει
ή αν οι μονάδες ξεχωρίζουν από το έδαφος. Αυτά φαίνονται μόνο εδώ.

Η ΔΙΑΤΑΞΗ ΠΟΥ ΔΟΚΙΜΑΖΕΤΑΙ

    γραμμές   0-143  παράθυρο χάρτη, ισομετρικό: 20 ρόμβοι πλάτος x 36 σειρές
    γραμμές 144-159  λωρίδα πόρων, 6 μετρητές x 24 pixels = 144 από 160
    γραμμές 160-191  μίνι χάρτης | κάρτα μονάδας | 16 κουμπιά (8x2)
    γραμμές 192-199  γραμμή μηνυμάτων

Τα κουμπιά είναι 8 pixels πλατιά: οκτώ στη σειρά πιάνουν 64 από τα 160.
"""
import os
import math
import random

import buildings as B
import gfx
import iso
import preview
import terrain as T
import units

W, H = 160, 200
MAP_TILES_X, MAP_TILES_Y = 20, 18
MAP_H = MAP_TILES_Y * T.TILE_H          # 144
PREVIEW = os.path.join(gfx.OUT, 'preview')

TER = {k: i for i, (k, _, _, _) in enumerate(T.TERRAIN)}
TER_ART = {k: a for k, _, a, _ in T.TERRAIN}
RES_ART = {k: a for k, _, a, _, _ in T.RESOURCES}
HUD_ART = dict([(k, a) for k, _, a in T.ICONS] +
               [(k, a) for k, _, a, _ in T.COMMANDS])

# Ψηφία 3x5. Στο Mode 0 είναι 6x5 μονάδες οθόνης — στενά και ευανάγνωστα.
DIGITS = ['111101101101111', '010110010010111', '111001111100111',
          '111001111001111', '101101111001001', '111100111001111',
          '111100111101111', '111001001001001', '111101111101111',
          '111101111001111']


def digit(img, n, x, y, pen):
    for j in range(5):
        for i in range(3):
            if DIGITS[n][j * 3 + i] == '1':
                px, py = x + i, y + j
                if 0 <= py < H and 0 <= px < W:
                    img[py][px] = pen


def number(img, v, x, y, pen, width=4):
    for k, ch in enumerate(str(v).rjust(width)):
        if ch != ' ':
            digit(img, int(ch), x + k * 4, y, pen)


N = 96                                  # ο χάρτης: 96x96 πλακίδια
TOP = 64                                # χώρος πάνω από τον χάρτη για ψηλά κτίρια
WX0 = 4 * N - 4                         # το κουτί του (0,0) στον κόσμο
WW, WH = 8 * N, 8 * N + TOP             # ο κόσμος σε pixels

LAND = ('grass', 'grass_tuft', 'grass_flower')


def _noise(seed, scale):
    """Ομαλός θόρυβος τιμών σε (i, j) — για ακτές και δάση που δεν είναι
    ορθογώνια."""
    rnd = random.Random(seed)
    g = [[rnd.random() for _ in range(N // scale + 3)]
         for _ in range(N // scale + 3)]

    def f(i, j):
        x, y = i / scale, j / scale
        x0, y0 = int(x), int(y)
        tx, ty = x - x0, y - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] * (1 - tx) + g[y0][x0 + 1] * tx
        b = g[y0 + 1][x0] * (1 - tx) + g[y0 + 1][x0 + 1] * tx
        return a * (1 - ty) + b * ty
    return f


# Οι δύο πόλεις. (κτίριο, πολιτισμός, εποχή, i, j, παίκτης) — i, j η ΠΙΣΩ
# γωνία της κάτοψης. Ο παίκτης 0 είναι μπλε, ο 1 κόκκινος: ΙΔΙΑ δεδομένα,
# άλλος πίνακας pens (`gfx.team_table`).
TOWNS = (
    # ο παίκτης: Έλληνες, κάτω αριστερά, δίπλα στη θάλασσα
    ('town_center', 'greek', 3, 30, 58, 0),
    ('house', 'greek', 3, 35, 57, 0), ('house', 'greek', 3, 35, 60, 0),
    ('house', 'greek', 3, 27, 63, 0), ('house', 'greek', 3, 31, 64, 0),
    ('granary', 'greek', 3, 25, 57, 0),
    ('storage_pit', 'greek', 3, 26, 52, 0),
    ('barracks', 'greek', 3, 38, 64, 0),
    ('farm', 'greek', 2, 30, 67, 0), ('farm', 'greek', 2, 26, 67, 0),
    ('temple', 'greek', 3, 34, 69, 0),
    ('market', 'greek', 3, 39, 59, 0),
    ('tower', 'greek', 3, 42, 55, 0),
    ('dock', 'greek', 3, 22, 61, 0),
    ('wall', 'greek', 3, 44, 60, 0), ('wall', 'greek', 3, 44, 61, 0),
    ('wall', 'greek', 3, 44, 62, 0), ('wall', 'greek', 3, 44, 63, 0),
    # ο αντίπαλος: Αιγύπτιοι, πάνω δεξιά
    ('town_center', 'egypt', 3, 64, 24, 1),
    ('house', 'egypt', 3, 69, 23, 1), ('house', 'egypt', 3, 69, 26, 1),
    ('house', 'egypt', 3, 62, 29, 1),
    ('granary', 'egypt', 3, 59, 24, 1),
    ('barracks', 'egypt', 3, 66, 30, 1),
    ('archery', 'egypt', 3, 71, 30, 1),
    ('farm', 'egypt', 2, 60, 19, 1),
    ('tower', 'egypt', 3, 58, 31, 1),
    ('temple', 'egypt', 3, 72, 19, 1),
)

# (μονάδα, καρέ, i, j, παίκτης)
UNITS = (('villager_m', 1, 33, 56, 0), ('villager_f', 2, 28, 66, 0),
         ('villager_m', 9, 22, 53, 0), ('swordsman', 0, 40, 62, 0),
         ('archer', 5, 41, 63, 0), ('villager_f', 6, 32, 68, 0),
         ('hoplite', 4, 43, 58, 0), ('villager_m', 3, 47, 49, 0),
         ('villager_m', 5, 63, 29, 1), ('spearman', 0, 68, 33, 1),
         ('archer', 1, 70, 34, 1), ('clubman', 6, 52, 40, 1),
         ('slinger', 2, 53, 41, 1), ('villager_f', 1, 58, 22, 1))


def footprint_tiles(i0, j0, n):
    return [(i, j) for j in range(j0, j0 + n) for i in range(i0, i0 + n)]


def make_map(seed=7):
    """Ο χάρτης 96x96: θάλασσα στα ΒΑ, λίμνες, δάση από θόρυβο, μια έρημος,
    ορυχεία, δύο πόλεις και ο δρόμος ανάμεσά τους.

    Στην οθόνη: το i πάει κάτω-ΔΕΞΙΑ, το j κάτω-ΑΡΙΣΤΕΡΑ. Το (0,0) είναι η
    πάνω κορυφή του ρόμβου.
    """
    rnd = random.Random(seed)
    coast = _noise(seed + 1, 9)
    woods = _noise(seed + 2, 6)
    dry = _noise(seed + 3, 14)
    grd = [[None] * N for _ in range(N)]          # grd[j][i]
    res = [[None] * N for _ in range(N)]
    water = [[False] * N for _ in range(N)]

    # θάλασσα κατά μήκος της ακμής j=0 (πάνω δεξιά στην οθόνη), με ακτή
    # που κυματίζει, και μια λωρίδα της που μπαίνει μέσα ώς την πόλη
    for j in range(N):
        for i in range(N):
            if j < 6 + 8 * coast(i, 0) or (i < 24 and j < 66 and
                                           i < 4 + 16 * coast(0, j)):
                water[j][i] = True
    # λίμνες
    for (ci, cj, ri, rj) in ((50, 72, 6, 4), (78, 60, 4, 7), (16, 86, 5, 4)):
        for j in range(N):
            for i in range(N):
                if ((i - ci) / ri) ** 2 + ((j - cj) / rj) ** 2 < 1:
                    water[j][i] = True

    def wet(i, j):
        return 0 <= i < N and 0 <= j < N and water[j][i]

    for j in range(N):
        for i in range(N):
            if water[j][i]:
                near = any(not wet(i + a, j + b) and 0 <= i + a < N and
                           0 <= j + b < N
                           for a in range(-2, 3) for b in range(-2, 3))
                grd[j][i] = 'water_shallow' if near else 'water_deep'
                continue
            r = rnd.random()
            t = ('grass_tuft' if r < .10 else
                 'grass_flower' if r < .15 else 'grass')
            if dry(i, j) > .66 and i > 60 and j > 50:
                t = 'sand_dune' if r < .2 else 'sand'
            grd[j][i] = t

    # ΑΚΤΕΣ: η στεριά που αγγίζει νερό σε ΜΙΑ ακμή παίρνει το αντίστοιχο
    # πλακίδιο· όσα αγγίζουν σε δύο ή περισσότερες (κάβοι, κόλποι) γίνονται
    # άμμος, που κουμπώνει με όλα.
    for j in range(N):
        for i in range(N):
            if water[j][i]:
                continue
            sides = [s for s, (a, b) in (('ne', (0, -1)), ('se', (1, 0)),
                                         ('sw', (0, 1)), ('nw', (-1, 0)))
                     if wet(i + a, j + b)]
            if len(sides) == 1:
                grd[j][i] = 'shore_' + sides[0]
            elif sides:
                grd[j][i] = 'sand'

    # βραχότοπος με γκρεμούς γύρω από τα ορυχεία της πέτρας
    for j in range(40, 47):
        for i in range(76, 86):
            if not water[j][i] and rnd.random() < .7:
                grd[j][i] = 'rock_floor' if rnd.random() < .75 else 'cliff'

    # δρόμος από πόλη σε πόλη: κατά μήκος του i, μετά του j
    for i in range(34, 67):
        if not water[44][i]:
            grd[44][i] = 'road'
    for j in range(32, 58):
        grd[j][66 if j < 44 else 34] = 'road'
    # πατημένο χώμα γύρω από τα κέντρα πόλης
    for (ci, cj) in ((32, 60), (66, 26)):
        for j in range(cj - 7, cj + 9):
            for i in range(ci - 7, ci + 9):
                if grd[j][i] in LAND and rnd.random() < .3:
                    grd[j][i] = 'dirt' if rnd.random() < .7 else 'dirt_rough'

    busy = set()
    for key, _, _, i0, j0, _ in TOWNS:
        busy.update(footprint_tiles(i0, j0, B.footprint(key)))
    calm = set()                                  # χωρίς δάσος γύρω από πόλεις
    for (ci, cj) in ((32, 60), (66, 26)):
        calm.update((i, j) for j in range(cj - 12, cj + 15)
                    for i in range(ci - 12, ci + 15))

    def free(i, j):
        return (0 <= i < N and 0 <= j < N and res[j][i] is None and
                (i, j) not in busy and grd[j][i] in LAND)

    # δάση: εκεί που ο θόρυβος είναι ψηλός
    for j in range(N):
        for i in range(N):
            w = woods(i, j)
            if free(i, j) and (i, j) not in calm and w > .58 and \
                    rnd.random() < (w - .5) * 2.4:
                res[j][i] = 'tree_pine' if j < 30 and rnd.random() < .7 \
                    else 'tree' if rnd.random() < .75 else 'tree_pine'
    for j in range(N):
        for i in range(N):
            if grd[j][i] in ('sand', 'sand_dune') and rnd.random() < .04:
                res[j][i] = 'tree_palm'

    def cluster(kind, ci, cj, n):
        k = 0
        for (a, b) in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (0, 2),
                       (2, 1), (-1, 1)):
            if k < n and 0 <= ci + a < N and 0 <= cj + b < N and \
                    (ci + a, cj + b) not in busy and \
                    grd[cj + b][ci + a] in LAND + ('rock_floor', 'sand'):
                res[cj + b][ci + a] = kind
                k += 1

    for (ci, cj) in ((46, 50), (75, 36), (20, 40), (88, 76)):
        cluster('gold_rock', ci, cj, 4)
    for (ci, cj) in ((78, 42), (82, 44), (40, 76), (58, 10)):
        cluster('stone_rock', ci, cj, 5)
    for (ci, cj) in ((24, 50), (37, 52), (61, 33)):
        cluster('berry_bush', ci, cj, 5)
    for (i, j, k) in ((50, 30, 'gazelle'), (54, 33, 'gazelle'),
                      (44, 84, 'gazelle'), (12, 70, 'ruins'),
                      (86, 20, 'ruins'), (48, 46, 'rock_small'),
                      (70, 70, 'rock_small'), (40, 30, 'stump'),
                      (41, 31, 'bush_empty')):
        if free(i, j):
            res[j][i] = k
    for j in range(N):
        for i in range(N):
            g = grd[j][i]
            if g == 'water_deep' and rnd.random() < .006:
                res[j][i] = 'whale'
            elif g == 'water_shallow' and rnd.random() < .02:
                res[j][i] = 'fish'
            elif g.startswith('shore') and rnd.random() < .05 and free(i, j):
                pass
    for (i, j) in busy:
        res[j][i] = None
    return grd, res


# ------------------------------------------------------------ ο κόσμος

def world_xy(i, j):
    return iso.tile_xy(i, j, WX0, TOP)


def render_world(grd, res, towns=True):
    """Όλος ο χάρτης σε ΕΝΑ buffer pixels. Η οθόνη είναι ένα κομμάτι του —
    αυτό ακριβώς είναι η κύλιση. Με towns=False μόνο έδαφος και πόροι: αυτό
    ζωγραφίζει το παιχνίδι στο M1, και με αυτό συγκρίνει το tests/m1_check.py."""
    # Έξω από τον ρόμβο: pen 0, που στον χάρτη είναι μαύρο — όπως το «κενό»
    # γύρω από τον χάρτη στο Age of Empires. Όχι pen 1: αυτό είναι η βαθιά
    # θάλασσα, και ο χάρτης θα έλιωνε μέσα στο περίγραμμα.
    world = gfx.blank(WW, WH, gfx.PEN_MASK)
    tiles = {k: T.tile(TER_ART[k]) for k in TER_ART}
    for j in range(N):
        for i in range(N):
            x, y = world_xy(i, j)
            gfx.stamp(world, tiles[grd[j][i]], x, y)

    # Τα αντικείμενα ταξινομούνται κατά το ΜΠΡΟΣΤΙΝΟ τους πλακίδιο (i+j):
    # ό,τι είναι πιο κάτω στην οθόνη ζωγραφίζεται τελευταίο. Ο αλγόριθμος του
    # ζωγράφου — ο ίδιος που θα κάνει ο κάδος γραμμών στο παιχνίδι.
    arts = {k: T.res(RES_ART[k]) for k in RES_ART if RES_ART[k]}
    objs = []
    for j in range(N):
        for i in range(N):
            if res[j][i]:
                x, y = world_xy(i, j)
                objs.append((i + j, i, arts[res[j][i]], x, y - 10))
    red = dict(enumerate(gfx.team_table(1)))
    for key, culture, age, i0, j0, who in (TOWNS if towns else ()):
        b = B.render(key, culture, age)
        if who:
            b = gfx.recolour(b, red)
        n = B.footprint(key)
        x, _ = world_xy(i0, j0)
        _, fy = world_xy(i0 + n - 1, j0 + n - 1)
        # Το χωράφι είναι ΠΑΤΩΜΑ: μπαίνει πριν από ό,τι πατάει πάνω του.
        depth = -1 if key == 'farm' else i0 + j0 + 2 * (n - 1)
        objs.append((depth, i0 + n - 1, b, x + 4 - 4 * n, fy + 8 - len(b)))
    sets = {s.name: s for s in units.all_sets()}
    for name, frame, i, j, who in (UNITS if towns else ()):
        f = sets[name].frames[frame]
        if who:
            f = gfx.recolour(f, red)
        x, y = world_xy(i, j)
        objs.append((i + j, i + 0.5, f, x + 4 - len(f[0]) // 2, y - 10))
    objs.sort(key=lambda o: (o[0], o[1]))
    for _, _, art, x, y in objs:
        gfx.stamp(world, art, x, y)
    return world


# ---------------------------------------------------------------- HUD

MM_X, MM_Y, MM_S = 13, 162, 20          # μίνι χάρτης: κέντρο-πάνω, πλευρά


def minimap(img, grd, res, cam, rect=True):
    """Μίνι χάρτης: ΡΟΜΒΟΣ, όπως στο Age of Empires — ο χάρτης είναι
    ισομετρικός, άρα και η επισκόπησή του. 20 pixels πλάτος, 20 γραμμές
    ύψος = 40x20 μονάδες, η ίδια αναλογία 2:1 με το πλακίδιο. Το λευκό
    πλαίσιο είναι το παράθυρο — μετακινείται όσο κυλάει η κάμερα."""
    mm = {'water_deep': 'K', 'water_shallow': 'c', 'dirt': 'o',
          'dirt_rough': 'o', 'road': 'D', 'sand': 'S', 'sand_dune': 'S',
          'rock_floor': 'i', 'cliff': 'i'}
    for my in range(MM_S + 1):
        for mx in range(-MM_S // 2, MM_S // 2):
            X, Y = mx + 0.5, my + 0.5
            i = int((Y + X) * N / MM_S)
            j = int((Y - X) * N / MM_S)
            if 0 <= i < N and 0 <= j < N:
                g = grd[j][i]
                pen = gfx.PEN['S' if g.startswith('shore') else mm.get(g, 'n')]
                if res[j][i] and res[j][i].startswith('tree'):
                    pen = gfx.PEN['g']
                img[MM_Y + my][MM_X + mx] = pen
    for key, _, _, i0, j0, who in TOWNS:
        n = B.footprint(key)
        i, j = i0 + n / 2, j0 + n / 2
        img[MM_Y + int((i + j) * MM_S / 2 / N)][
            MM_X + int((i - j) * MM_S / 2 / N)] = \
            gfx.PEN['T'] if who == 0 else gfx.PEN['r']
    if not rect:
        return
    # το παράθυρο: κόσμος -> μίνι χάρτης, κλίμακα MM_S / 8N
    k = MM_S / (8.0 * N)
    cx, cy = cam
    x0 = MM_X + int(round((cx - 4 * N) * k))
    x1 = MM_X + int(round((cx + W - 4 * N) * k))
    y0 = MM_Y + int(round((cy - TOP) * k))
    y1 = MM_Y + int(round((cy + MAP_H - TOP) * k))
    for x in range(x0, x1 + 1):
        for y in (y0, y1):
            if 0 <= x < W and MM_Y - 1 <= y <= MM_Y + MM_S + 1:
                img[y][x] = gfx.PEN['I']
    for y in range(y0, y1 + 1):
        for x in (x0, x1):
            if 0 <= x < W and MM_Y - 1 <= y <= MM_Y + MM_S + 1:
                img[y][x] = gfx.PEN['I']


def frame(world, grd, res, cam, hud_bg):
    """Μία οθόνη: το κομμάτι του κόσμου στη θέση `cam` + το HUD."""
    cx, cy = cam
    img = [list(r) for r in hud_bg]
    for y in range(MAP_H):
        img[y] = list(world[cy + y][cx:cx + W])
    minimap(img, grd, res, cam)
    return img


def hud_background():
    img = gfx.blank(W, H, gfx.PEN['K'])
    for x in range(W):
        img[MAP_H][x] = gfx.PEN['t']

    bar = [('food', 842), ('wood', 1204), ('gold', 375),
           ('stone', 190), ('pop', 34), ('age', 2)]
    for i, (k, v) in enumerate(bar):
        ox = i * 24 + 1
        gfx.stamp(img, T.hud(HUD_ART[k]), ox, MAP_H + 1)
        number(img, v, ox + 9, MAP_H + 6, gfx.PEN['I'])
    gfx.stamp(img, T.hud(HUD_ART['alert']), 148, MAP_H + 1)

    # κάρτα επιλεγμένης μονάδας
    sets = {s.name: s for s in units.all_sets()}
    gfx.stamp(img, sets['swordsman'].frames[0], 27, 163)
    for x in range(26, 38):
        img[181][x] = gfx.PEN['n'] if x < 35 else gfx.PEN['r']

    # 16 κουμπιά, 8 στη σειρά x 2 σειρές
    for i, (k, _, _, _) in enumerate(T.COMMANDS):
        ox, oy = 44 + (i % 8) * 14, 162 + (i // 8) * 18
        for y in range(oy, oy + 17):
            for x in range(ox - 1, ox + 9):
                img[y][x] = gfx.PEN['t'] if i != 1 else gfx.PEN['i']
        gfx.stamp(img, T.hud(HUD_ART[k]), ox, oy)
    return img


# ---------------------------------------------------------- εικόνες

def to_image(img, zoom):
    """Pens -> εικόνα PIL με pixel 2:1, γρήγορα (παλέτα, όχι ορθογώνια)."""
    from PIL import Image
    h, w = len(img), len(img[0])
    im = Image.new('P', (w, h))
    pal = []
    for rgb in gfx.RGB:
        pal.extend(rgb)
    im.putpalette(pal + [0] * (768 - len(pal)))
    im.putdata([p if p is not None else 0 for row in img for p in row])
    return im.resize((w * 2 * zoom, h * zoom), Image.NEAREST)


def cam_on(i, j):
    """Η κάμερα (πάνω αριστερή γωνία) ώστε το πλακίδιο (i, j) να είναι στο
    κέντρο του παραθύρου — ευθυγραμμισμένη σε byte (ζυγό pixel)."""
    x, y = world_xy(i, j)
    cx = max(0, min(WW - W, x + 4 - W // 2)) & ~1
    cy = max(0, min(WH - MAP_H, y + 4 - MAP_H // 2))
    return cx, cy


def save_map(world, path):
    """Ολόκληρος ο χάρτης, με το πλέγμα των οθονών (160x144) από πάνω."""
    from PIL import ImageDraw
    z = 1
    im = to_image(world, z).convert('RGB')
    d = ImageDraw.Draw(im)
    for gx in range(0, WW + 1, W):
        d.line([(gx * 2 * z, 0), (gx * 2 * z, WH * z)], fill=(255, 255, 255))
    for gy in range(TOP, WH + 1, MAP_H):
        d.line([(0, gy * z), (WW * 2 * z, gy * z)], fill=(255, 255, 255))
    area = 32.0 * N * N / (W * MAP_H)
    from PIL import ImageFont
    try:
        font = ImageFont.truetype('DejaVuSans.ttf', 16)
    except OSError:
        font = None
    d.rectangle([4, 4, 640, 28], fill=(0, 0, 0))
    d.text((10, 7), 'χάρτης %dx%d πλακίδια = %.1f οθόνες χάρτη (%dx%d η καθεμία)'
           % (N, N, area, W, MAP_H), fill=(255, 220, 90), font=font)
    im.save(path)
    return area


def letterbox(im):
    """Τετράγωνος καμβάς: η οθόνη στη μέση, μαύρα περιθώρια πάνω και κάτω."""
    from PIL import Image
    side = max(im.width, im.height)
    out = Image.new('P', (side, side), 0)
    out.putpalette(im.getpalette())
    out.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return out


def save_scroll(world, grd, res, hud_bg, path):
    """Η κάμερα ταξιδεύει από την πόλη του παίκτη στην αντίπαλη και πίσω,
    σε βήματα των 4 pixels / 4 γραμμών: μισό πλακίδιο, όσο ένα byte-ζεύγος
    — το βήμα που θα κάνει και η κύλιση στο CPC."""
    route = [cam_on(32, 60), cam_on(48, 44), cam_on(66, 26), cam_on(80, 44),
             cam_on(50, 74), cam_on(32, 60)]
    frames = []
    for (ax, ay), (bx, by) in zip(route, route[1:]):
        steps = max(abs(bx - ax), abs(by - ay)) // 8 or 1
        for s in range(steps):
            t = s / steps
            cam = (int(ax + (bx - ax) * t) & ~1, int(ay + (by - ay) * t))
            frames.append(letterbox(
                to_image(frame(world, grd, res, cam, hud_bg), 2)))
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=80, loop=0)
    return len(frames)


def main():
    grd, res = make_map()
    world = render_world(grd, res)
    hud_bg = hud_background()

    img = frame(world, grd, res, cam_on(33, 60), hud_bg)
    path = os.path.join(PREVIEW, 'screen.png')
    preview.contact_sheet(path, [('', img)], zoom=4, cols=1, title='', grid=False)
    print(path)

    area = save_map(world, os.path.join(PREVIEW, 'map.png'))
    print('%s  (%.1f οθόνες)' % (os.path.join(PREVIEW, 'map.png'), area))

    n = save_scroll(world, grd, res, hud_bg, os.path.join(PREVIEW, 'scroll.gif'))
    print('%s  (%d καρέ)' % (os.path.join(PREVIEW, 'scroll.gif'), n))


if __name__ == '__main__':
    main()
