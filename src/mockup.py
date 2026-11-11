"""Μια ολόκληρη οθόνη 160x200 — ο μόνος τρόπος να κριθεί το σύνολο.

    python3 src/mockup.py

Τα contact sheets δείχνουν αν ΕΝΑ πλακίδιο είναι καλό. Δεν δείχνουν αν ο
χάρτης διαβάζεται, αν τα δέντρα χάνονται μέσα στο γρασίδι, αν το HUD χωράει
ή αν οι μονάδες ξεχωρίζουν από το έδαφος. Αυτά φαίνονται μόνο εδώ.

Η ΔΙΑΤΑΞΗ ΠΟΥ ΔΟΚΙΜΑΖΕΤΑΙ

    γραμμές   0-143  παράθυρο χάρτη, 20x18 πλακίδια
    γραμμές 144-159  λωρίδα πόρων, 6 μετρητές x 24 pixels = 144 από 160
    γραμμές 160-191  μίνι χάρτης | κάρτα μονάδας | 16 κουμπιά (8x2)
    γραμμές 192-199  γραμμή μηνυμάτων

Τα κουμπιά είναι 8 pixels πλατιά: οκτώ στη σειρά πιάνουν 64 από τα 160.
"""
import os
import random

import buildings as B
import gfx
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


def make_map(seed=7):
    """Ένας μικρός χάρτης: λίμνη στα ΒΑ, δάσος στα ΝΔ, δρόμος στη μέση."""
    rnd = random.Random(seed)
    grd = [['grass'] * MAP_TILES_X for _ in range(MAP_TILES_Y)]
    res = [[None] * MAP_TILES_X for _ in range(MAP_TILES_Y)]

    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X):
            r = rnd.random()
            grd[y][x] = ('grass_tuft' if r < .12 else
                         'grass_flower' if r < .18 else 'grass')

    # λίμνη: πάνω δεξιά
    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X):
            d = (x - 17) + (6 - y) * 0.5
            if y < 6 and x > 12 + (y - 2) * 0.4:
                grd[y][x] = 'water_deep' if d > 1.5 else 'water_shallow'
    for x in range(MAP_TILES_X):          # ακτή εκεί που τελειώνει το νερό
        for y in range(MAP_TILES_Y - 1):
            wet = grd[y][x].startswith('water')
            if wet and not grd[y + 1][x].startswith('water'):
                grd[y + 1][x] = 'shore_s'
    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X - 1):
            if (grd[y][x].startswith('water') and
                    grd[y][x + 1] == 'grass'):
                grd[y][x + 1] = 'shore_e'

    # αμμουδιά και χώμα
    for y in range(10, 14):
        for x in range(1, 5):
            grd[y][x] = 'dirt' if rnd.random() < .7 else 'dirt_rough'
    # δρόμος
    for x in range(4, 16):
        grd[12][x] = 'road'

    def free(x, y):
        return grd[y][x] in ('grass', 'grass_tuft', 'grass_flower')

    # δάσος κάτω αριστερά
    for y in range(13, MAP_TILES_Y):
        for x in range(0, 8):
            if free(x, y) and rnd.random() < .55:
                res[y][x] = 'tree' if rnd.random() < .7 else 'tree_pine'
    for y in range(14, 17):               # μούρα στην άκρη του δάσους
        if free(9, y):
            res[y][9] = 'berry_bush'
    res[15][10] = 'berry_bush' if free(10, 15) else None
    # ορυκτά
    for (x, y, k) in ((16, 14, 'gold_rock'), (17, 15, 'gold_rock'),
                      (18, 13, 'stone_rock'), (17, 12, 'stone_rock'),
                      (15, 16, 'rock_small'), (2, 9, 'stump'),
                      (12, 16, 'gazelle'), (10, 9, 'ruins')):
        if free(x, y):
            res[y][x] = k
    # ψάρια και καλάμια
    for (x, y) in ((16, 2), (18, 4), (14, 1)):
        if grd[y][x].startswith('water'):
            res[y][x] = 'fish'
    if grd[1][18].startswith('water'):
        res[1][18] = 'whale'
    for x in range(13, 17):
        if grd[6][x] == 'shore_s':
            res[6][x] = 'reeds'
    return grd, res


def draw():
    img = gfx.blank(W, H, gfx.PEN['K'])

    grd, res = make_map()
    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X):
            gfx.stamp(img, T.tile(TER_ART[grd[y][x]]), x * 8, y * 8)
    # Οι πόροι ΜΕΤΑ από όλο το έδαφος, και από πάνω προς τα κάτω: ένα δέντρο
    # σκεπάζει το πλακίδιο πάνω του, άρα πρέπει να μπει αφού αυτό ζωγραφιστεί.
    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X):
            if res[y][x]:
                gfx.stamp(img, T.res(RES_ART[res[y][x]]), x * 8, y * 8 - 8)

    for key, culture, age, tx, ty in (('town_center', 'greek', 2, 10, 7),
                                      ('barracks', 'greek', 2, 14, 8),
                                      ('house', 'greek', 1, 9, 10),
                                      ('house', 'greek', 1, 11, 10)):
        b = B.render(key, culture, age)
        gfx.stamp(img, b, tx * 8, ty * 8 + 8 - len(b))

    sets = {s.name: s for s in units.all_sets()}
    for name, frame, tx, ty in (('villager_m', 1, 7, 13), ('villager_f', 2, 6, 14),
                                ('swordsman', 0, 13, 11), ('archer', 5, 15, 11),
                                ('villager_m', 9, 16, 13)):
        gfx.stamp(img, sets[name].frames[frame], tx * 8, ty * 8)

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

    # μίνι χάρτης: ένα pixel ανά πλακίδιο, πράσινο/κυανό/γκρι
    mm = {'water_deep': 'K', 'water_shallow': 'c', 'shore_s': 'S',
          'shore_e': 'S', 'dirt': 'D', 'dirt_rough': 'D', 'road': 'D'}
    for y in range(MAP_TILES_Y):
        for x in range(MAP_TILES_X):
            pen = gfx.PEN[mm.get(grd[y][x], 'n')]
            if res[y][x] and res[y][x].startswith('tree'):
                pen = gfx.PEN['g']
            img[163 + y][3 + x] = pen
    for x in range(2, 24):
        img[162][x] = img[182][x] = gfx.PEN['i']
    for y in range(162, 183):
        img[y][2] = img[y][23] = gfx.PEN['i']

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
