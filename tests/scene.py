"""Η αναμενόμενη οθόνη με τις μονάδες, από τους πίνακες του Z80 (M3/M4).

Ο Z80 κρατάει τη σειρά σχεδίασης στο ORDER (δείκτες εγγραφών των 32 bytes)
και τη θέση οθόνης κάθε μονάδας στην εγγραφή της. Εδώ η ίδια εικόνα
συντίθεται στην Python, ανεξάρτητα: το φόντο του mockup, και από πάνω, με
τη σειρά του ORDER, το καρέ κάθε μονάδας όπως το ορίζουν σετ, όψη και
βήμα (οι όψεις W καθρεφτισμένες εδώ), οι αγκύλες των επιλεγμένων, η γωνία
του κουτιού και ο κέρσορας.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import gfx                                      # noqa: E402

UNITS, U_SIZE = 128, 32
UNIT_TAB = 0xAE00
ORDER = 0xA680
ACT_TAB = 0xA600
ANCHOR_REC = UNIT_TAB + UNITS * U_SIZE
CURSOR_REC = ANCHOR_REC + U_SIZE
SETS = ['villager_m', 'swordsman', 'archer', 'villager_carry']
F_MOVE, F_SEL, F_WANDER, F_FIXED = 1, 2, 4, 16
FACES = 'SENW'


def frames(name):
    blob = open(os.path.join(M.ROOT, 'data', name + '.bin'), 'rb').read()
    return [gfx.decode_masked(blob[k:k + 128], 8, 16)
            for k in range(0, len(blob), 128)]


# όπως στην C5 (src/make_edges.py): τα σετ 0-2 με το καρέ 12 = το W της
# επίθεσης· το 3 (με φορτίο) = ο χωρικός με το δέμα από πάνω (carry_ov)· το
# 4 = ο οπλίτης (HOPL.BIN, στη θέση 3)
import make_carry as MC                         # noqa: E402
_C5 = [frames('c5_set%d' % k) for k in range(3)]
SPRITES = _C5 + [[MC.carry(f) for f in _C5[0]], frames('c5_slot3')]
BASE = {3: 0}                                   # τα καρέ χωρίς το δέμα
CURSOR, MARK, ANCHOR = frames('cursor')[:3]
ARROWS, PR_N = 0xA5E0, 4                       # τα βέλη (game/bank7.asm)


def rec(c, addr):
    b = c.read_ram(addr, U_SIZE)
    w = lambda o: b[o] | b[o + 1] << 8                     # noqa: E731
    return dict(addr=addr, wx=w(0), wy=w(2), tx=w(4), ty=w(6), set=b[8],
                step=b[9], face=b[10], fl=b[11], sx=b[12], sy=b[13],
                drawn=b[14], frame=w(16), idx=b[22], team=b[28])


def bank_ram(c, b):
    """Η τράπεζα b της επέκτασης (4-7: C4-C7), 16 KB, όσο τρέχει (M10)."""
    from cpc import _lib
    return _lib.cpcemu_ram_ptr(c._h, b)


FOG = 0x5F80                    # game/fog.asm: στην C6, 1 bit ανά πλακίδιο


def fog_seen(c):
    """Ο εξερευνημένος χάρτης (M11): seen[j][i]."""
    p = bank_ram(c, 6)
    b = bytes(p[FOG - 0x4000 + k] for k in range(96 * 12))
    return [[bool(b[j * 12 + i // 8] >> (i & 7) & 1) for i in range(96)]
            for j in range(96)]


def c7_read(c, addr, n=1):
    p = bank_ram(c, 7)
    return bytes(p[addr - 0x4000 + k] for k in range(n))


def c7_write(c, addr, data):
    p = bank_ram(c, 7)
    for k, v in enumerate(data):
        p[addr - 0x4000 + k] = v


def unit(c, i):
    return rec(c, UNIT_TAB + i * U_SIZE)


def units(c):
    return [unit(c, i) for i in range(UNITS)]


def sprite_of(u, bare=False):
    if u['addr'] == CURSOR_REC:
        return CURSOR
    if u['addr'] == ANCHOR_REC:            # η γωνία του κουτιού, ή το σημάδι
        return MARK if u['frame'] == 0x7280 else ANCHOR    # του κτιρίου (M7)
    s = SPRITES[BASE.get(u['set'], u['set']) if bare else u['set']]
    if u['set'] == 3 and u['team'] & 0x80:  # πεθαίνει: χωρίς δέμα
        s = SPRITES[0]
    if u['face'] & 0x80:                   # πόζα (M8): το U_STEP είναι το καρέ
        f = u['step']
        return gfx.mirror(s[4 + f - 21]) if f >= 21 else s[f]
    anim = (u['step'] >> 1) & 3
    face = FACES[u['face']]
    if face == 'W':
        return gfx.mirror(s[4 + anim])
    return s[{'S': 0, 'E': 4, 'N': 8}[face] + anim]


def order(c, sym):
    n = c.peek(sym['ORD_TOT'])
    o = c.read_ram(ORDER, 2 * n)
    return [rec(c, o[k] | o[k + 1] << 8) for k in range(0, 2 * n, 2)]


def stamp(img, spr, x, y):
    for j in range(16):
        for i in range(8):
            p = spr[j][i]
            if p is not None:
                img[y + j][x * 2 + i] = p


# ---------------------------------------------- πίσω από κτίριο (M7)
BLD_SLOTS = [0xA400 + k * 16 for k in range(16)] + \
    [0xBE40 + k * 16 for k in range(12)]
BANK6 = open(os.path.join(M.ROOT, 'data', 'bank6.bin'), 'rb').read()
import make_bank6 as MB                         # noqa: E402
import make_map as MM                           # noqa: E402
OUTLINE = gfx.PEN[MM.OUTLINE_PEN]
HUD_AGE = M.symbols()['HUD_VAL'] + 10             # η εποχή (main.asm, hud_val)
_, RED_HI, RED_LO = gfx.TEAMS[1]
RED = {gfx.TEAM_HI: RED_HI, gfx.TEAM_LO: RED_LO}


def painted(u, spr):
    """Η ομάδα 1 (και όταν πεθαίνει): τα pens της ομάδας κόκκινα."""
    if u['addr'] < ANCHOR_REC and u['team'] & 0x7F == 1:
        return gfx.recolour(spr, RED)
    return spr


CULTURE = 'G'                   # το γράμμα του πολιτισμού (M12, make_bank6)


def bank6(age=None, culture=None):
    """Η C6 όπως είναι στην εποχή: από τη Χαλκού (3) με το αρχείο της εποχής
    του πολιτισμού (AGE3G.BIN κλπ., χωρίς κεφαλίδα) στο AGE_AT (M12)."""
    if age not in (3, 4):
        return BANK6
    a3 = open(os.path.join(M.ROOT, 'data', 'age%d%s.bin'
                           % (age, culture or CULTURE)),
              'rb').read()
    k = MB.AGE_AT - 0x4000
    return BANK6[:k] + a3 + BANK6[k + len(a3):]


def buildings(c, age=None):
    """Τα έτοιμα κτίρια του Z80, με την εικόνα τους από την C6."""
    if age is None:
        age = c.peek(HUD_AGE)
    c6 = bank6(age)
    out = []
    for a in BLD_SLOTS:
        b = c.read_ram(a, 16)
        if b[0] == 255 or b[4] == 0:
            continue
        w, h, img = b[10], b[11], b[12] | b[13] << 8
        k = img - 0x4000
        if not 0 <= k <= len(c6) - w * h:          # (εγγραφές των ελέγχων
            continue                                # χωρίς εικόνα)
        n = MB.footprint(MB.KEYS[b[0]])
        out.append(dict(i1=b[2] + n - 1, j1=b[3] + n - 1,
                        x=2 * (b[6] | b[7] << 8), y=(b[8] | b[9] << 8) - h,
                        img=MB.decode(c6[k:k + w * h], w, h)))
    return out


def hidden(u, blds):
    """Η μονάδα κρύβεται πίσω από κτίριο (game/occlude.asm): το πλακίδιο των
    ποδιών της δεν είναι μπροστά από την κάτοψη ούτε στο i ούτε στο j, και η
    εικόνα του έχει pixel στο byte WX + 2 της γραμμής WY + 14 (τα πόδια)."""
    fx, fy = u['wx'] + 2, u['wy'] + 14
    ti, tj = (2 * fx + fy - 383) >> 3, (fy - 2 * fx + 383) >> 3
    for b in blds:
        if ti > b['i1'] or tj > b['j1']:
            continue
        by = u['wy'] + 14 - b['y']
        bx = 2 * (u['wx'] + 2) - b['x']
        if 0 <= by < len(b['img']) and 0 <= bx < len(b['img'][0]):
            if any(p is not None for p in b['img'][by][bx:bx + 2]):
                return True
    return False


def occluded(spr, pen=OUTLINE):
    """Μόνο το περίγραμμα: τα pixels της σιλουέτας με διάφανο γείτονα, στο
    pen OUTLINE (της ομάδας)· όλα τα άλλα διάφανα."""
    def on(i, j):
        return 0 <= i < 8 and 0 <= j < 16 and spr[j][i] is not None
    return [[pen if on(i, j) and not (on(i - 1, j) and on(i + 1, j) and
                                           on(i, j - 1) and on(i, j + 1))
             else None for i in range(8)] for j in range(16)]


def expected(c, sym, ref):
    img = [list(r) for r in ref]
    blds = buildings(c)
    for u in order(c, sym):
        spr = sprite_of(u)
        if not u['fl'] & F_FIXED and u['addr'] < ANCHOR_REC and blds and \
                hidden(u, blds):
            spr = occluded(sprite_of(u, True),
                           RED_HI if u['team'] & 1 else OUTLINE)
        else:
            spr = painted(u, spr)
        stamp(img, spr, u['sx'], u['sy'])
        if u['fl'] & F_SEL:
            stamp(img, MARK, u['sx'], u['sy'])
    for sx, sy in arrows(c):               # τα βέλη: XOR #FF, πάνω από όλα
        for y in (sy, sy + 1):
            for x in (2 * sx, 2 * sx + 1):
                img[y][x] ^= 15
    return img


def arrows(c):
    """(sx, sy) των βελών που είναι ζωγραφισμένα (game/bank7.asm)."""
    b = c.read_ram(ARROWS, PR_N * 8)
    return [(b[k + 6], b[k + 7]) for k in range(0, PR_N * 8, 8)
            if b[k + 7] != 255]
