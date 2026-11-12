"""Οι πίστες των εκστρατειών (M13): ο επεξεργαστής πίστας εκτός CPC.

    python3 src/make_levels.py

-> data/l<εκστρατεία><n>.bin  ο χάρτης (9.216 bytes, όπως το map96.bin) και
                             ΜΕΤΑ του η κεφαλίδα της πίστας (H_LEN bytes):
                             το build.sh τα βάζει στη δισκέτα συμπιεσμένα
                             (LG1.BIN ... LE4.BIN). Το μενού τα αποσυμπιέζει
                             στο #8000: η κεφαλίδα πέφτει στο #A400 (LV_HDR).
-> data/level.asm            οι θέσεις των πεδίων της κεφαλίδας (H_*) και οι
                             στόχοι (OBJ_*)
-> data/lvdef.asm            η κεφαλίδα της παρτίδας χωρίς εκστρατεία: ο
                             χάρτης του mockup, με τις θέσεις ως το M12
-> preview/levels.png        οι 8 χάρτες

Η ΚΕΦΑΛΙΔΑ (ό,τι ως το M12 ήταν σταθερές του κώδικα): τα δύο Κέντρα Πόλης,
οι μονάδες γύρω τους (το πάνω-αριστερό της διάταξης 4 x 3, σε συντεταγμένες
κόσμου), η κάμερα, οι πόροι του παίκτη, η διαδρομή των κυμάτων του
αντιπάλου (3 σημεία), οι θέσεις όπου χτίζει (6), το «σπίτι» του, το πρώτο
κύμα (s), ο πολιτισμός, ο στόχος — και δύο γραμμές κειμένου για την οθόνη
της πίστας (όπως το menu_lines, src/make_menu.py).

ΕΛΕΓΧΟΙ σε κάθε πίστα: οι κατόψεις των Κέντρων και των θέσεων κτισίματος
ελεύθερες, οι 12 + 12 μονάδες σε βατά πλακίδια, η διαδρομή βατή, και οι δύο
πόλεις ενωμένες (BFS).
"""
import collections
import os
import random

import gfx
import make_map as MM
import make_menu as MN
import mockup

DATA = os.path.join(gfx.OUT, 'data')
N = mockup.N
LAND = mockup.LAND

MAGIC = (0xA5, 0x5A)
# (από το ROUTE ως το ARG: ένα κομμάτι, όπως είναι στη C7 — lv_c7, bank7.asm)
FIELDS = [('MAGIC', 2), ('TC', 2), ('AITC', 2), ('TOWN', 4), ('AIU', 4),
          ('CAM', 4), ('RES', 8), ('ROUTE', 6), ('SPOTS', 24), ('HOME', 2),
          ('COOL', 2), ('CULT', 1), ('CAMP', 1), ('NUM', 1), ('PROG', 2),
          ('OBJ', 1), ('ARG', 2), ('TEXT', 50)]
OFF = {}
_o = 0
for _k, _n in FIELDS:
    OFF[_k] = _o
    _o += _n
H_LEN = _o
OBJ = {'destroy': 0, 'survive': 1, 'gold': 2, 'age': 3}

# ως το M12 (game/buildings.asm, units.asm, bank7.asm, main.asm)
SPOT_OFF = [(6, -4), (6, 1), (-5, -5), (0, -5), (7, 6), (5, -9),
            (10, -9), (11, -4), (11, 1), (-2, -10), (12, 6), (15, -13)]
DEFAULT = dict(tc=(30, 58), aitc=(58, 27), town=(106, 330), aiu=(242, 350),
               cam=(98, 303), res=(200, 200, 100, 200),
               route=[(57, 44), (44, 44), (44, 56)],
               spots=[(58 + a, 27 + b) for a, b in SPOT_OFF],
               home=(60, 29), cool=180)

# Οι πίστες: (εκστρατεία, n, σπόρος, ο παίκτης, ο αντίπαλος, θάλασσα,
# λίμνες, στόχος, όρισμα, πρώτο κύμα s, πόροι, κείμενο)
LEVELS = [
    ('G', 1, 11, (24, 62), (62, 24), 'ne', [(70, 70, 6, 4)],
     'survive', 240, 60, (300, 300, 100, 200), 'SURVIVE 4 MINUTES'),
    ('G', 2, 12, (60, 66), (26, 22), 'sw', [(50, 40, 5, 6)],
     'gold', 400, 300, (200, 200, 0, 100), 'GATHER 400 GOLD'),
    ('G', 3, 13, (28, 30), (64, 64), 'se', [(20, 70, 6, 4), (70, 25, 4, 5)],
     'age', 4, 300, (2000, 400, 1000, 200), 'REACH THE IRON AGE'),
    ('G', 4, 14, (64, 30), (26, 66), 'nw', [(48, 48, 5, 5)],
     'destroy', 0, 150, (400, 400, 200, 200), 'DESTROY THE CITY'),
    ('E', 1, 21, (30, 60), (60, 26), 'ne', [(45, 75, 5, 4)],
     'gold', 300, 360, (200, 200, 0, 100), 'GATHER 300 GOLD'),
    ('E', 2, 22, (62, 62), (26, 28), 'sw', [(72, 30, 5, 4)],
     'survive', 300, 45, (300, 400, 100, 300), 'SURVIVE 5 MINUTES'),
    ('E', 3, 23, (24, 40), (66, 50), 'se', [(46, 22, 6, 4)],
     'destroy', 0, 180, (300, 300, 200, 200), 'DESTROY THE CITY'),
    ('E', 4, 24, (40, 66), (40, 24), 'nw', [(70, 45, 4, 6)],
     'age', 4, 240, (2400, 500, 1200, 300), 'REACH THE IRON AGE'),
]
CAMP_NAMES = {'G': 'GREEKS', 'E': 'EGYPTIANS'}
CAMP_CULT = {'G': 'G', 'E': 'E'}


# ------------------------------------------------------------ γεωμετρία

def tile_xy(i, j):
    """Το πλακίδιο -> τα πόδια του σε συντεταγμένες κόσμου (όπως ο Z80)."""
    return 2 * (i - j) + 192, 4 * (i + j) + 4


def feet_tile(fx, fy):
    return (2 * fx + fy - 383) >> 3, (fy - 2 * fx + 383) >> 3


def grid_tiles(x, y):
    """Οι 12 μονάδες της διάταξης 4 x 3 (units_init) -> τα πλακίδιά τους."""
    return [feet_tile(x + 16 * (k & 3) + 2, y + 32 * (k >> 2) + 14)
            for k in range(12)]


def footprint(i0, j0, n):
    return [(i, j) for j in range(j0, j0 + n) for i in range(i0, i0 + n)]


def camera(tc):
    fx, fy = tile_xy(*tc)
    cx = max(0, min(304, (fx - 38) & ~1))
    cy = fy - 53
    cy = max(-1, min(623, cy))
    cy = ((cy - 7) // 8) * 8 + 7
    return cx, cy


def seg(a, b):
    """Τα πλακίδια της ευθείας a -> b (κατά μήκος του i ή του j)."""
    (i0, j0), (i1, j1) = a, b
    if i0 == i1:
        s = 1 if j1 >= j0 else -1
        return [(i0, j) for j in range(j0, j1 + s, s)]
    s = 1 if i1 >= i0 else -1
    return [(i, j0) for i in range(i0, i1 + s, s)]


# ------------------------------------------------------------ ο χάρτης

def gen(seed, pt, at, sea, lakes, route, extra):
    """Ένας χάρτης στο ύφος του mockup.make_map, με τις πόλεις στα pt, at
    (η πίσω γωνία της κάτοψης του Κέντρου) και τον δρόμο στη διαδρομή."""
    rnd = random.Random(seed)
    coast = mockup._noise(seed + 1, 9)
    woods = mockup._noise(seed + 2, 6)
    dry = mockup._noise(seed + 3, 14)
    grd = [[None] * N for _ in range(N)]
    res = [[None] * N for _ in range(N)]
    water = [[False] * N for _ in range(N)]
    edge = {'ne': lambda i, j: j, 'sw': lambda i, j: N - 1 - j,
            'nw': lambda i, j: i, 'se': lambda i, j: N - 1 - i}[sea]
    for j in range(N):
        for i in range(N):
            if edge(i, j) < 5 + 7 * coast(i, j):
                water[j][i] = True
    for (ci, cj, ri, rj) in lakes:
        for j in range(N):
            for i in range(N):
                if ((i - ci) / ri) ** 2 + ((j - cj) / rj) ** 2 < 1:
                    water[j][i] = True
    # στεριά σίγουρα: γύρω από τις πόλεις και κατά μήκος του δρόμου
    keep = set()
    for (ci, cj) in (pt, at):
        keep.update((i, j) for j in range(cj - 9, cj + 13)
                    for i in range(ci - 9, ci + 13))
    keep.update(extra)
    road = set()
    pts = [(at[0] - 1, at[1] + 2)] + route + [(pt[0] + 4, pt[1] + 1)]
    for a, b in zip(pts, pts[1:]):
        road.update(seg(a, (b[0], a[1])) + seg((b[0], a[1]), b))
    for (i, j) in road:
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                keep.add((i + a, j + b))
    for (i, j) in keep:
        if 0 <= i < N and 0 <= j < N:
            water[j][i] = False

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
            if dry(i, j) > .7 and (i, j) not in keep:
                t = 'sand_dune' if r < .2 else 'sand'
            grd[j][i] = t
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
    for (i, j) in road:
        if 0 <= i < N and 0 <= j < N:
            grd[j][i] = 'road'
    for (ci, cj) in (pt, at):
        for j in range(cj - 6, cj + 10):
            for i in range(ci - 6, ci + 10):
                if grd[j][i] in LAND and rnd.random() < .3:
                    grd[j][i] = 'dirt' if rnd.random() < .7 else 'dirt_rough'
    calm = set()
    for (ci, cj) in (pt, at):
        calm.update((i, j) for j in range(cj - 11, cj + 15)
                    for i in range(ci - 11, ci + 15))
    for (i, j) in road:
        calm.update((i + a, j + b) for a in (-2, -1, 0, 1, 2)
                    for b in (-2, -1, 0, 1, 2))

    def free(i, j):
        return (0 <= i < N and 0 <= j < N and res[j][i] is None and
                grd[j][i] in LAND)

    for j in range(N):
        for i in range(N):
            w = woods(i, j)
            if free(i, j) and (i, j) not in calm and w > .56 and \
                    rnd.random() < (w - .48) * 2.4:
                res[j][i] = 'tree' if rnd.random() < .7 else 'tree_pine'
    for j in range(N):
        for i in range(N):
            if grd[j][i] in ('sand', 'sand_dune') and rnd.random() < .03 \
                    and (i, j) not in calm:
                res[j][i] = 'tree_palm'

    def cluster(kind, ci, cj, n):
        k = 0
        for (a, b) in ((0, 0), (1, 0), (0, 1), (1, 1), (2, 0), (0, 2),
                       (2, 1), (-1, 1)):
            if k < n and free(ci + a, cj + b):
                res[cj + b][ci + a] = kind
                k += 1

    # σε κάθε πόλη: μούρα, χρυσός, πέτρα, ένα μικρό δάσος — έξω από τη ζώνη
    # της πόλης αλλά κοντά
    for (ci, cj) in (pt, at):
        cluster('berry_bush', ci - 6, cj + 2, 5)
        cluster('gold_rock', ci + 10, cj - 6, 4)
        cluster('stone_rock', ci - 7, cj + 9, 4)
        for (a, b) in ((-10, -8), (12, 10)):
            for k in range(14):
                i = ci + a + rnd.randrange(-3, 4)
                j = cj + b + rnd.randrange(-3, 4)
                if free(i, j):
                    res[j][i] = 'tree'
    # και στη μέση του χάρτη, για όποιον απλωθεί
    for _ in range(4):
        cluster('gold_rock', rnd.randrange(10, 86), rnd.randrange(10, 86), 4)
        cluster('stone_rock', rnd.randrange(10, 86), rnd.randrange(10, 86), 4)
    for j in range(N):
        for i in range(N):
            g = grd[j][i]
            if g == 'water_deep' and rnd.random() < .006:
                res[j][i] = 'whale'
            elif g == 'water_shallow' and rnd.random() < .02:
                res[j][i] = 'fish'
    return grd, res


def clear(grd, res, tiles):
    """Βατά: στεριά χωρίς πόρο."""
    for (i, j) in tiles:
        if 0 <= i < N and 0 <= j < N:
            res[j][i] = None
            if grd[j][i] not in LAND and grd[j][i] not in (
                    'dirt', 'dirt_rough', 'road', 'sand'):
                grd[j][i] = 'grass'


def walkable(grd, res, i, j):
    return 0 <= i < N and 0 <= j < N and not MM.blocked_byte(
        MM.TER[grd[j][i]] << 4 | MM.RES[res[j][i] or 'none'])


def connected(grd, res, a, b, busy):
    seen = {a}
    q = collections.deque([a])
    while q:
        i, j = q.popleft()
        if (i, j) == b:
            return True
        for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            t = (i + di, j + dj)
            if t not in seen and t not in busy and walkable(grd, res, *t):
                seen.add(t)
                q.append(t)
    return False


def town_grid(grd, res, tc, busy):
    """Το πάνω-αριστερό της διάταξης 4 x 3 των μονάδων: η πρώτη θέση κοντά
    στο Κέντρο όπου και τα 12 πλακίδια είναι βατά και έξω από την κάτοψη."""
    fx, fy = tile_xy(*tc)
    for r in range(0, 60, 2):
        for dx in range(-r, r + 1, 2):
            for dy in (-r, r) if abs(dx) != r else range(-r, r + 1, 2):
                x, y = fx - 30 + dx, fy - 26 + dy
                ts = grid_tiles(x, y)
                if all(walkable(grd, res, *t) and t not in busy for t in ts):
                    return x & ~1, y
    raise AssertionError('καμία θέση για τις μονάδες γύρω από %s' % (tc,))


def build(lv):
    (camp, n, seed, pt, at, sea, lakes, obj, arg, cool, res0, text) = lv
    # η διαδρομή: από το Κέντρο του αντιπάλου στο σημείο ανάμεσα, μετά
    # στη στήλη του παίκτη, και κάτω/πάνω ως δίπλα στο Κέντρο του
    mid_j = (pt[1] + at[1]) // 2
    route = [(at[0] - 1, mid_j), (pt[0] + 14 if pt[0] < at[0] else pt[0] - 10,
                                  mid_j)]
    route.append((route[1][0], pt[1] - 2 if pt[1] > mid_j else pt[1] + 6))
    spots = [(at[0] + a, at[1] + b) for a, b in SPOT_OFF]
    grd, res = gen(seed, pt, at, sea, lakes, route,
                   {t for (i, j) in spots for t in footprint(i - 2, j - 2, 7)})
    busy = set(footprint(pt[0], pt[1], 4)) | set(footprint(at[0], at[1], 4))
    clear(grd, res, busy)
    for (i, j) in spots:                    # 3 x 3 με 1 γύρω (το ai_spots)
        clear(grd, res, footprint(i - 1, j - 1, 5))
        assert not (set(footprint(i, j, 3)) & busy), (camp, n, (i, j))
    town = town_grid(grd, res, pt, busy)
    aiu = town_grid(grd, res, at, busy)
    for a, b in zip([(at[0] - 1, at[1] + 2)] + route, route):
        for t in seg(a, (b[0], a[1])) + seg((b[0], a[1]), b):
            assert walkable(grd, res, *t), (camp, n, 'διαδρομή', t)
    assert connected(grd, res, (pt[0] + 4, pt[1] + 1), (at[0] - 1, at[1] + 2),
                     busy), (camp, n, 'οι πόλεις δεν ενώνονται')
    hdr = header(obj=OBJ[obj], arg=arg, tc=pt, aitc=at, town=town, aiu=aiu,
                 cam=camera(pt), res=res0, route=route, spots=spots,
                 home=(at[0] + 2, at[1] + 2), cool=cool, cult=CAMP_CULT[camp],
                 camp=0, num=n, text=[
                     (60, None, MN.PEN_HI, '%s %d/4' % (CAMP_NAMES[camp], n)),
                     (100, None, MN.PEN_TEXT, text)])
    return grd, res, hdr


def header(obj, arg, tc, aitc, town, aiu, cam, res, route, spots, home, cool,
           cult, camp, num, text):
    """Τα H_LEN bytes της κεφαλίδας (το CAMP και το PROG τα γράφει το
    μενού όταν φορτώνει την πίστα)."""
    def w(v):
        return [v & 255, (v >> 8) & 255]
    out = list(MAGIC) + [tc[1], tc[0], aitc[1], aitc[0]]  # ld de,(): D = i
    out += w(town[0]) + w(town[1]) + w(aiu[0]) + w(aiu[1])
    out += w(cam[0]) + w(cam[1] & 0xFFFF)
    for v in res:
        out += w(v)
    for p in route:
        out += list(p)
    for p in spots:
        out += list(p)
    out += list(home) + w(cool)
    out += [ord(cult) if cult else 0, camp, num, 0, 0, obj] + w(arg)
    lines = [(y, (80 - MN.CELL * len(t)) // 2 if x is None else x, pen, t)
             for y, x, pen, t in text]
    txt = MN.encode_lines(lines)
    assert len(txt) <= 50, text
    out += list(txt) + [0] * (50 - len(txt))
    assert len(out) == H_LEN
    return bytes(out)


def main():
    import make_menu  # noqa: F401  (η γραμματοσειρά: ίδια σειρά γλύφων)
    with open(os.path.join(DATA, 'level.asm'), 'w') as f:
        f.write('; level.asm — ΠΑΡΑΓΕΤΑΙ από src/make_levels.py. Η κεφαλίδα '
                'της πίστας (M13):\n; οι θέσεις των πεδίων, και οι στόχοι.\n\n'
                + ''.join('H_%-9s equ %d\n' % (k, OFF[k]) for k, _ in FIELDS)
                + 'H_LEN       equ %d\nLV_MAGIC    equ #%02X%02X\n'
                % (H_LEN, MAGIC[1], MAGIC[0])
                + ''.join('OBJ_%-8s equ %d\n' % (k.upper(), v)
                          for k, v in OBJ.items()))
    d = DEFAULT
    hdr = header(obj=0, arg=0, tc=d['tc'], aitc=d['aitc'], town=d['town'],
                 aiu=d['aiu'], cam=d['cam'], res=d['res'], route=d['route'],
                 spots=d['spots'], home=d['home'], cool=d['cool'], cult=None,
                 camp=0, num=0, text=[])
    with open(os.path.join(DATA, 'lvdef.asm'), 'w') as f:
        f.write('; lvdef.asm — ΠΑΡΑΓΕΤΑΙ από src/make_levels.py: η κεφαλίδα '
                'της παρτίδας χωρίς\n; εκστρατεία (ο χάρτης του mockup, οι '
                'θέσεις ως το M12).\nlv_def:\n%s'
                % ''.join('        db %s\n' % ','.join(str(b) for b in
                                                     hdr[k:min(k + 16, OFF['TEXT'])])
                          for k in range(0, OFF['TEXT'], 16)))
    from PIL import Image
    sheet = Image.new('RGB', (4 * 196, 2 * 196), (0, 0, 0))
    for k, lv in enumerate(LEVELS):
        grd, res, hdr = build(lv)
        blob = MM.encode(grd, res) + hdr
        name = 'l%s%d.bin' % (lv[0].lower(), lv[1])
        open(os.path.join(DATA, name), 'wb').write(blob)
        img = Image.new('RGB', (N, N))
        for j in range(N):
            for i in range(N):
                g, r = grd[j][i], res[j][i]
                c = ((30, 60, 160) if g.startswith('water') else
                     (200, 180, 120) if g in ('sand', 'sand_dune', 'road')
                     else (60, 140, 60))
                if r and r.startswith('tree'):
                    c = (20, 80, 20)
                elif r in ('gold_rock',):
                    c = (240, 220, 0)
                elif r in ('stone_rock',):
                    c = (160, 160, 160)
                img.putpixel((i, j), c)
        for (i, j), c in ((lv[3], (0, 120, 255)), (lv[4], (255, 40, 40))):
            for t in footprint(i, j, 4):
                img.putpixel(t, c)
        sheet.paste(img.resize((192, 192)), ((k % 4) * 196, (k // 4) * 196))
        print('data/%s  %s %d: %s %s, πρώτο κύμα %d s' % (
            name, CAMP_NAMES[lv[0]], lv[1], lv[7], lv[8], lv[9]))
    sheet.save(os.path.join(gfx.OUT, 'preview', 'levels.png'))
    print('data/level.asm, data/lvdef.asm, preview/levels.png')


if __name__ == '__main__':
    main()
