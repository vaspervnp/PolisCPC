"""Μια ολόκληρη οθόνη 160x200 — ο μόνος τρόπος να κριθεί το σύνολο.

    python3 src/mockup.py

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


N = 44                                  # ο χάρτης του mockup: 44x44 πλακίδια
S = 10                                  # τα σημεία του σεναρίου μετατοπίζονται
X0, Y0 = 76, -108 + 4 * 2 * (22 - S - 12)  # το (12,12) του σεναρίου στο κέντρο


def make_map(seed=7):
    """Ένας μικρός ισομετρικός χάρτης: λίμνη πάνω δεξιά, δάσος κάτω αριστερά,
    ορυχεία δεξιά, δρόμος που περνάει από την πόλη.

    Στην οθόνη: το i πάει κάτω-ΔΕΞΙΑ, το j κάτω-ΑΡΙΣΤΕΡΑ. Μια περιοχή
    ορθογώνια σε (i, j) είναι ρόμβος στην οθόνη.
    """
    rnd = random.Random(seed)
    grd = [['grass'] * N for _ in range(N)]          # grd[j][i]
    res = [[None] * N for _ in range(N)]
    for j in range(N):
        for i in range(N):
            r = rnd.random()
            grd[j][i] = ('grass_tuft' if r < .10 else
                         'grass_flower' if r < .15 else 'grass')

    # λίμνη: i 9.., j ..5 — βαθύ στη μέση, ρηχό στις άκρες
    for j in range(0, S + 6):
        for i in range(S + 9, N):
            deep = j <= S + 3 and i >= S + 12
            grd[j][i] = 'water_deep' if deep else 'water_shallow'
    for i in range(S + 9, N):
        grd[S + 6][i] = 'shore_ne'       # νερό στο j-1: ακμή ΒΑ
    for j in range(0, S + 6):
        grd[j][S + 8] = 'shore_se'       # νερό στο i+1: ακμή ΝΑ

    # χώμα γύρω από την πόλη και ένας δρόμος κατά μήκος του i
    for j in range(S + 8, S + 15):
        for i in range(S + 6, S + 14):
            if rnd.random() < .35:
                grd[j][i] = 'dirt' if rnd.random() < .7 else 'dirt_rough'
    for i in range(0, N):
        grd[S + 15][i] = 'road'
    for j in range(S + 15, N):
        grd[j][S + 16] = 'road'

    def free(i, j):
        return (0 <= i < N and 0 <= j < N and res[j][i] is None and
                grd[j][i] in ('grass', 'grass_tuft', 'grass_flower'))

    # δάσος: κάτω αριστερά (j μεγάλο, i μικρό)
    for j in range(S + 16, N):
        for i in range(0, S + 14):
            if free(i, j) and rnd.random() < .6 - .03 * (i - S - 4):
                res[j][i] = 'tree' if rnd.random() < .7 else 'tree_pine'
    for (i, j) in ((12, 17), (13, 18), (11, 16)):
        if free(i + S, j + S):
            res[j + S][i + S] = 'berry_bush'
    # ορυχεία δεξιά, ζώα, ερείπια
    for (i, j, k) in ((20, 9, 'gold_rock'), (21, 10, 'gold_rock'),
                      (19, 12, 'stone_rock'), (20, 13, 'stone_rock'),
                      (22, 12, 'rock_small'), (4, 10, 'stump'),
                      (18, 19, 'gazelle'), (3, 6, 'ruins'),
                      (5, 13, 'tree'), (2, 12, 'tree_pine')):
        if free(i + S, j + S):
            res[j + S][i + S] = k
    for (i, j) in ((14, 2), (18, 4), (12, 1), (25, 3)):
        res[j + S][i + S] = 'fish'
    res[S + 1][S + 21] = 'whale'
    for i in (10, 13, 15):
        res[S + 6][i + S] = 'reeds'
    # δάσος και στη δυτική άκρη, πέρα από το σενάριο
    for j in range(0, N):
        for i in range(0, N):
            if (i - j) < -S - 4 and free(i, j) and rnd.random() < .55:
                res[j][i] = 'tree' if rnd.random() < .6 else 'tree_pine'
    return grd, res


# (κτίριο, πολιτισμός, εποχή, i, j) — i, j η ΠΙΣΩ γωνία της κάτοψης
TOWN = (('town_center', 'greek', 3, 9, 9),
        ('house', 'greek', 3, 14, 8),
        ('house', 'greek', 3, 14, 11),
        ('house', 'greek', 3, 6, 13),
        ('granary', 'greek', 3, 4, 8),
        ('barracks', 'greek', 3, 17, 16),
        ('farm', 'greek', 2, 9, 17),
        ('temple', 'greek', 3, 12, 20),
        ('tower', 'greek', 3, 19, 6),
        ('dock', 'greek', 3, 16, 5))

# (μονάδα, καρέ, i, j)
UNITS = (('villager_m', 1, 12, 15), ('villager_f', 2, 10, 18),
         ('villager_m', 9, 19, 11), ('swordsman', 0, 15, 14),
         ('archer', 5, 17, 14), ('villager_f', 6, 7, 16),
         ('hoplite', 4, 13, 15))


def draw():
    img = gfx.blank(W, H, gfx.PEN['K'])
    view = gfx.blank(W, MAP_H, gfx.PEN['K'])

    grd, res = make_map()
    # Κάτω από ένα κτίριο δεν φυτρώνει τίποτα.
    for key, _, _, i0, j0 in TOWN:
        n = B.footprint(key)
        for j in range(j0 + S, j0 + S + n):
            for i in range(i0 + S, i0 + S + n):
                res[j][i] = None
    for j in range(N):
        for i in range(N):
            x, y = iso.tile_xy(i, j, X0, Y0)
            gfx.stamp(view, T.tile(TER_ART[grd[j][i]]), x, y)

    # Τα αντικείμενα ταξινομούνται κατά το ΜΠΡΟΣΤΙΝΟ τους πλακίδιο (i+j):
    # ό,τι είναι πιο κάτω στην οθόνη ζωγραφίζεται τελευταίο. Ο αλγόριθμος του
    # ζωγράφου — ο ίδιος που θα κάνει ο κάδος γραμμών στο παιχνίδι.
    objs = []
    for j in range(N):
        for i in range(N):
            if res[j][i]:
                x, y = iso.tile_xy(i, j, X0, Y0)
                objs.append((i + j, i, T.res(RES_ART[res[j][i]]), x, y - 10))
    for key, culture, age, i0, j0 in TOWN:
        i0, j0 = i0 + S, j0 + S
        b = B.render(key, culture, age)
        n = B.footprint(key)
        x, y = iso.tile_xy(i0, j0, X0, Y0)
        _, fy = iso.tile_xy(i0 + n - 1, j0 + n - 1, X0, Y0)
        # Το χωράφι είναι ΠΑΤΩΜΑ: μπαίνει πριν από ό,τι πατάει πάνω του.
        depth = -1 if key == 'farm' else i0 + j0 + 2 * (n - 1)
        objs.append((depth, i0 + n - 1, b, x + 4 - 4 * n, fy + 8 - len(b)))
    sets = {s.name: s for s in units.all_sets()}
    for name, frame, i, j in UNITS:
        i, j = i + S, j + S
        f = sets[name].frames[frame]
        x, y = iso.tile_xy(i, j, X0, Y0)
        objs.append((i + j, i + 0.5, f, x + 4 - len(f[0]) // 2, y - 10))
    objs.sort(key=lambda o: (o[0], o[1]))
    for _, _, art, x, y in objs:
        gfx.stamp(view, art, x, y)
    for y in range(MAP_H):
        img[y] = view[y]

    # ------------------------------------------------------------- HUD
    for y in range(MAP_H, H):
        for x in range(W):
            img[y][x] = gfx.PEN['K']
    for x in range(W):
        img[MAP_H][x] = gfx.PEN['t']

    bar = [('food', 842), ('wood', 1204), ('gold', 375),
           ('stone', 190), ('pop', 34), ('age', 2)]
    for i, (k, v) in enumerate(bar):
        ox = i * 24 + 1
        gfx.stamp(img, T.hud(HUD_ART[k]), ox, MAP_H + 1)
        number(img, v, ox + 9, MAP_H + 6, gfx.PEN['I'])
    gfx.stamp(img, T.hud(HUD_ART['alert']), 148, MAP_H + 1)

    # Μίνι χάρτης: ΡΟΜΒΟΣ, όπως στο Age of Empires — ο χάρτης είναι
    # ισομετρικός, άρα και η επισκόπησή του. 20 pixels πλάτος, 20 γραμμές
    # ύψος = 40x20 μονάδες, η ίδια αναλογία 2:1 με το πλακίδιο.
    mm = {'water_deep': 'K', 'water_shallow': 'c', 'shore_ne': 'S',
          'shore_se': 'S', 'shore_sw': 'S', 'shore_nw': 'S', 'dirt': 'o',
          'dirt_rough': 'o', 'road': 'D'}
    cx, cy = 13, 162
    for my in range(21):
        for mx in range(-10, 10):
            X, Y = mx + 0.5, my + 0.5
            i, j = int((Y + X) * N / 20), int((Y - X) * N / 20)
            if 0 <= i < N and 0 <= j < N:
                pen = gfx.PEN[mm.get(grd[j][i], 'n')]
                if res[j][i] and res[j][i].startswith('tree'):
                    pen = gfx.PEN['g']
                img[cy + my][cx + mx] = pen
    for key, _, _, i0, j0 in TOWN:
        n = B.footprint(key)
        i, j = i0 + S + n / 2, j0 + S + n / 2
        img[cy + int((i + j) * 10 / N)][cx + int((i - j) * 10 / N)] = \
            gfx.PEN['T']

    # κάρτα επιλεγμένης μονάδας
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


def main():
    img = draw()
    path = os.path.join(PREVIEW, 'screen.png')
    preview.contact_sheet(path, [('', img)], zoom=4, cols=1, title='', grid=False)
    print(path)


if __name__ == '__main__':
    main()
