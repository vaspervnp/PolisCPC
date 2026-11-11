"""Η ισομετρική γεωμετρία του Polis: ο ρόμβος, η προβολή, και ένας μικρός
ραστεροποιητής που ζωγραφίζει κουτιά, στέγες και κώνους σε pixels Mode 0.

Η ΠΡΟΒΟΛΗ ΕΙΝΑΙ 2:1 ΣΤΗΝ ΟΘΟΝΗ — ΚΑΙ 1:1 ΣΤΑ PIXELS

Το pixel του Mode 0 είναι διπλάσια φαρδύ από ψηλό. Μια ακμή που πάει «ένα
pixel δεξιά, μία γραμμή κάτω» είναι στην οθόνη 2 μονάδες δεξιά, 1 κάτω: η
κλίση 26,6° της κλασικής ισομετρικής του Age of Empires. Άρα εδώ οι ακμές
του ρόμβου είναι ΚΑΘΑΡΕΣ ΔΙΑΓΩΝΙΕΣ στο πλέγμα των pixels — χωρίς σκαλοπάτια
1-2-1-2 που θα ήθελε ένα PC με τετράγωνα pixels.

    i (ΝΑ):  +4 pixels δεξιά, +4 γραμμές κάτω
    j (ΝΔ):  -4 pixels δεξιά, +4 γραμμές κάτω

Ένα πλακίδιο είναι ρόμβος 8 pixels x 8 γραμμές = 16x8 μονάδες οθόνης.

ΔΥΟ ΡΟΜΒΟΙ: ΤΟΥ ΕΔΑΦΟΥΣ ΚΑΙ ΤΩΝ ΚΤΙΡΙΩΝ

Ο ακριβής ρόμβος έχει γραμμές 2,4,6,8,6,4,2 pixels. Το 2 και το 6 ξεκινούν
σε ΜΟΝΟ pixel, δηλαδή στη μέση ενός byte — το έδαφος θα ήθελε μάσκα.

Το έδαφος παίρνει λοιπόν τον ΡΟΜΒΟ ΤΩΝ BYTES: κάθε byte (ζευγάρι pixels)
ανήκει στο πλακίδιο που περιέχει το κέντρο του. Βγαίνουν γραμμές 0,4,4,8,8,
4,4,0 pixels — 2,2,4,4,2,2 bytes, όλες στοιχισμένες. Τα πλακίδια ΣΥΝΕΧΙΖΟΥΝ
να καλύπτουν το επίπεδο χωρίς κενά και επικαλύψεις (το ελέγχει το
`_check_tiling`), και κάθε γραμμή μπαίνει με `LDI` χωρίς AND/OR: 16 bytes
ανά πλακίδιο, όσα ακριβώς pixels έχει.

Τα κτίρια, οι πόροι και οι μονάδες έχουν μάσκα ούτως ή άλλως· αυτά
χρησιμοποιούν την ακριβή γεωμετρία.

Ο ΡΑΣΤΕΡΟΠΟΙΗΤΗΣ

Κάθε επιφάνεια είναι ένα κυρτό πολύγωνο σε συντεταγμένες κόσμου (u, v, z):

    u  κατά μήκος του i, σε «βήματα» (4 βήματα = 1 πλακίδιο)
    v  κατά μήκος του j
    z  ύψος, σε γραμμές οθόνης

    x = ox + u - v          y = oy + u + v - z

Ένα pixel ανήκει στο πολύγωνο αν ανήκει το ΚΕΝΤΡΟ του, με τον κανόνα
πάνω-αριστερά για τις ισοπαλίες: δύο επιφάνειες που μοιράζονται ακμή δεν
αφήνουν ούτε κενό ούτε διπλό pixel ανάμεσά τους.

Η ΣΚΙΑ ΒΓΑΙΝΕΙ ΑΠΟ ΤΟ ΚΑΝΟΝΙΚΟ ΔΙΑΝΥΣΜΑ

Το φως έρχεται από αριστερά-πάνω, όπως στο Age of Empires: ο αριστερός
τοίχος (κοιτάει ΝΔ) φωτεινός, ο δεξιός (ΝΑ) σκιά, η στέγη που βλέπει
αριστερά φωτεινή. Η ρουτίνα `shade` διαλέγει pen από το κανονικό της
επιφάνειας· έτσι μια κωνική στέγη με 8 έδρες σκιάζεται μόνη της.

Η κάμερα κοιτάει προς τη διεύθυνση -(1,1,2). Μια έδρα κυρτού σώματος
φαίνεται μόνο αν το κανονικό της έχει θετικό γινόμενο με το (1,1,2) — αυτή
είναι όλη η ταξινόμηση που χρειάζεται ένα κυρτό σχήμα.
"""
import math

TW, TH = 8, 8           # το κουτί του πλακιδίου σε pixels/γραμμές
STEP = 4                # βήματα u/v ανά πλακίδιο
VIEW = (1.0, 1.0, 2.0)  # προς την κάμερα
LIGHT = (0.35, 1.0, 1.25)


# ------------------------------------------------------------ προβολή

def tile_xy(i, j, x0=0, y0=0):
    """Πλακίδιο (i, j) -> πάνω αριστερή γωνία του κουτιού του στην οθόνη."""
    return x0 + (i - j) * 4, y0 + (i + j) * 4


def project(p, ox, oy):
    u, v, z = p
    return ox + u - v, oy + u + v - z


# ------------------------------------------------------ οι δύο ρόμβοι

def _exact_inside(x, y):
    """Ακριβής ρόμβος: το κέντρο του pixel στην κάτοψη [0,4)x[0,4)."""
    X, Y = x + 0.5 - 4, y + 0.5
    u, v = (X + Y) / 2, (Y - X) / 2
    return 0 <= u < 4 and 0 <= v < 4


def _byte_inside(x, y):
    """Ρόμβος των bytes: το ΚΕΝΤΡΟ ΤΟΥ BYTE (όχι του pixel) αποφασίζει."""
    X, Y = (x // 2) * 2 + 1 - 4, y + 0.5
    u, v = (X + Y) / 2, (Y - X) / 2
    return 0 <= u < 4 and 0 <= v < 4


EXACT = [[_exact_inside(x, y) for x in range(TW)] for y in range(TH)]
DIAMOND = [[_byte_inside(x, y) for x in range(TW)] for y in range(TH)]

# Οι γραμμές του ρόμβου των bytes ως (πρώτο byte, πλήθος bytes) — ο πίνακας
# που χρειάζεται ο blitter του εδάφους.
SPANS = []
for _row in DIAMOND:
    _xs = [x for x, b in enumerate(_row) if b]
    SPANS.append((_xs[0] // 2, len(_xs) // 2) if _xs else (0, 0))
DIAMOND_BYTES = sum(n for _, n in SPANS)


def _check_tiling(mask):
    """Κάθε pixel ενός μεγάλου πεδίου ανήκει σε ΑΚΡΙΒΩΣ ένα πλακίδιο."""
    W = H = 48
    cnt = [[0] * W for _ in range(H)]
    for i in range(-12, 12):
        for j in range(-12, 12):
            tx, ty = tile_xy(i, j, 20, 4)
            for y in range(TH):
                for x in range(TW):
                    if mask[y][x]:
                        X, Y = tx + x, ty + y
                        if 0 <= X < W and 0 <= Y < H:
                            cnt[Y][X] += 1
    assert all(c == 1 for row in cnt[8:40] for c in row[8:40]), \
        'ο ρόμβος δεν στρώνει το επίπεδο'


_check_tiling(EXACT)
_check_tiling(DIAMOND)
assert DIAMOND_BYTES == 16


def clip(img, mask=DIAMOND):
    """Κρατάει μόνο ό,τι πέφτει μέσα στον ρόμβο (8x8 κουτί)."""
    return [[p if mask[y][x] else None for x, p in enumerate(row)]
            for y, row in enumerate(img)]


# ----------------------------------------------------- ραστεροποίηση

def _cross(a, b, p):
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])


def fill_poly(img, pts, pen):
    """Κυρτό πολύγωνο σε συντεταγμένες οθόνης, κέντρα pixels, κανόνας
    πάνω-αριστερά. Πολύγωνο με μηδενικό εμβαδόν δεν ζωγραφίζει τίποτα."""
    if pen is None or len(pts) < 3:
        return
    area = sum(_cross(pts[0], pts[k], pts[k + 1]) for k in range(1, len(pts) - 1))
    if abs(area) < 1e-9:
        return
    if area < 0:
        pts = pts[::-1]
    edges = []
    for k in range(len(pts)):
        a, b = pts[k], pts[(k + 1) % len(pts)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        # Με θετικό εμβαδόν (y προς τα κάτω) το εσωτερικό είναι δεξιά της
        # ακμής. «Πάνω» ακμή: οριζόντια με το εσωτερικό από κάτω. «Αριστερή»:
        # ανεβαίνει.
        topleft = (dy == 0 and dx > 0) or dy < 0
        edges.append((a, b, topleft))
    h, w = len(img), len(img[0])
    y0 = max(0, int(math.floor(min(p[1] for p in pts))))
    y1 = min(h - 1, int(math.ceil(max(p[1] for p in pts))))
    x0 = max(0, int(math.floor(min(p[0] for p in pts))))
    x1 = min(w - 1, int(math.ceil(max(p[0] for p in pts))))
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = (x + 0.5, y + 0.5)
            ok = True
            for a, b, tl in edges:
                e = _cross(a, b, c)
                if e < -1e-9 or (abs(e) <= 1e-9 and not tl):
                    ok = False
                    break
            if ok:
                img[y][x] = pen


def normal(pts):
    """Κανονικό διάνυσμα επιπέδου από τρία σημεία κόσμου (μοναδιαίο)."""
    a, b, c = pts[0], pts[1], pts[2]
    u = [b[k] - a[k] for k in range(3)]
    v = [c[k] - a[k] for k in range(3)]
    n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2],
         u[0] * v[1] - u[1] * v[0]]
    m = math.sqrt(sum(t * t for t in n)) or 1.0
    return [t / m for t in n]


def _dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def facing(pts):
    """Το κανονικό, γυρισμένο ώστε να κοιτάει προς την κάμερα, και αν
    ήταν ήδη έτσι (True = η έδρα φαίνεται, για κυρτά σώματα)."""
    n = normal(pts)
    return n, _dot(n, VIEW) > 1e-9


def light(n):
    m = math.sqrt(_dot(LIGHT, LIGHT))
    return _dot(n, LIGHT) / m


class Scene:
    """Καμβάς κτιρίου. Η αρχή (ox, oy) είναι η ΠΙΣΩ γωνία της κάτοψης,
    u=v=z=0· η κάτοψη n x n πλακίδια πιάνει u,v σε [0, 4n)."""

    def __init__(self, img, ox, oy):
        self.img, self.ox, self.oy = img, ox, oy

    def poly(self, pts3, pen):
        fill_poly(self.img, [project(p, self.ox, self.oy) for p in pts3], pen)

    # Μια έδρα με pen που διαλέγεται από το φως: ramp = (σκιά, φως) ή
    # (σκιά, μέσο, φως). Οι έδρες που δεν φαίνονται προσπερνιούνται.
    def face(self, pts3, ramp, cull=True):
        n, vis = facing(pts3)
        if cull and not vis:
            return
        if not vis:
            n = [-t for t in n]
        self.poly(pts3, shade(n, ramp))

    def box(self, u0, v0, u1, v1, z0, z1, left, right=None, top=None):
        """Ορθογώνιο κουτί. `left` = ο τοίχος που κοιτάει ΝΔ (φως), `right` =
        ΝΑ (σκιά), `top` = η οροφή. Pens ή None για να μη ζωγραφιστεί."""
        right = left if right is None else right
        if left is not None:
            self.poly([(u0, v1, z0), (u1, v1, z0), (u1, v1, z1), (u0, v1, z1)],
                      left)
        if right is not None:
            self.poly([(u1, v1, z0), (u1, v0, z0), (u1, v0, z1), (u1, v1, z1)],
                      right)
        if top is not None:
            self.poly([(u0, v0, z1), (u1, v0, z1), (u1, v1, z1), (u0, v1, z1)],
                      top)

    def floor(self, u0, v0, u1, v1, pen, z=0):
        self.poly([(u0, v0, z), (u1, v0, z), (u1, v1, z), (u0, v1, z)], pen)

    # ----------------------------------------------- σχέδια πάνω σε τοίχο
    # «L» είναι ο τοίχος v=σταθ. (κοιτάει ΝΔ, αριστερά στην οθόνη), «R» ο
    # τοίχος u=σταθ. (ΝΑ, δεξιά). Το `a` μετράει κατά μήκος του τοίχου.

    def on_wall(self, side, k, a0, a1, z0, z1, pen):
        if side == 'L':
            pts = [(a0, k, z0), (a1, k, z0), (a1, k, z1), (a0, k, z1)]
        else:
            pts = [(k, a1, z0), (k, a0, z0), (k, a0, z1), (k, a1, z1)]
        self.poly(pts, pen)

    def prism(self, cu, cv, r, z0, z1, ramp, sides=8, top=None):
        """Κατακόρυφο πολυγωνικό πρίσμα (στρογγυλή καλύβα, πύργος, κολόνα)."""
        ring = _ring(cu, cv, r, sides)
        for k in range(sides):
            a, b = ring[k], ring[(k + 1) % sides]
            self.face([(a[0], a[1], z0), (b[0], b[1], z0),
                       (b[0], b[1], z1), (a[0], a[1], z1)], ramp)
        if top is not None:
            self.poly([(p[0], p[1], z1) for p in ring], top)

    def cone(self, cu, cv, r, z0, h, ramp, sides=8):
        """Κώνος/πυραμίδα με κορυφή στο (cu, cv, z0+h)."""
        ring = _ring(cu, cv, r, sides)
        apex = (cu, cv, z0 + h)
        for k in range(sides):
            a, b = ring[k], ring[(k + 1) % sides]
            self.face([(a[0], a[1], z0), (b[0], b[1], z0), apex], ramp)

    def dome(self, cu, cv, r, z0, h, ramp, sides=8, bands=3):
        """Τρούλος: στοίβα από κόλουρους κώνους."""
        prev_r, prev_z = r, z0
        for k in range(1, bands + 1):
            t = k / bands
            nr = r * math.cos(t * math.pi / 2)
            nz = z0 + h * math.sin(t * math.pi / 2)
            ra, rb = _ring(cu, cv, prev_r, sides), _ring(cu, cv, nr, sides)
            for s in range(sides):
                a, b = ra[s], ra[(s + 1) % sides]
                c, d = rb[(s + 1) % sides], rb[s]
                pts = [(a[0], a[1], prev_z), (b[0], b[1], prev_z),
                       (c[0], c[1], nz), (d[0], d[1], nz)]
                if nr < 1e-6:
                    pts = pts[:3]
                self.face(pts, ramp)
            prev_r, prev_z = nr, nz

    def hip(self, u0, v0, u1, v1, z0, h, ramp, ridge=0.0, over=0.0):
        """Τετράριχτη στέγη (ή πυραμίδα αν ridge=0). Ο κορφιάς πάει κατά
        μήκος του μακρύτερου άξονα. `over` = προεξοχή γείσου."""
        u0, v0, u1, v1 = u0 - over, v0 - over, u1 + over, v1 + over
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        zt = z0 + h
        if (u1 - u0) >= (v1 - v0):
            half = max(0.0, (u1 - u0) / 2 - (v1 - v0) / 2) if ridge is None \
                else ridge / 2
            r0, r1 = (cu - half, cv, zt), (cu + half, cv, zt)
        else:
            half = max(0.0, (v1 - v0) / 2 - (u1 - u0) / 2) if ridge is None \
                else ridge / 2
            r0, r1 = (cu, cv - half, zt), (cu, cv + half, zt)
        A, B, C, D = (u0, v0, z0), (u1, v0, z0), (u1, v1, z0), (u0, v1, z0)
        faces = []
        if (u1 - u0) >= (v1 - v0):
            faces = [[A, B, r1, r0], [B, C, r1], [C, D, r0, r1], [D, A, r0]]
        else:
            faces = [[A, B, r0], [B, C, r1, r0], [C, D, r1], [D, A, r0, r1]]
        for f in faces:
            f = [p for k, p in enumerate(f) if p not in f[:k]]
            if len(f) >= 3:
                self.face(f, ramp)

    def gable(self, u0, v0, u1, v1, z0, h, ramp, end, axis='u', over=0.0):
        """Δίριχτη στέγη με κορφιά κατά μήκος του `axis`. `end` = το pen του
        αετώματος (το τρίγωνο στο ορατό άκρο) — ή None αν είναι ίδιο με τον
        τοίχο από κάτω."""
        if axis == 'u':
            cv = (v0 + v1) / 2
            a0, a1 = u0 - over, u1 + over
            b0, b1 = v0 - over, v1 + over
            r0, r1 = (a0, cv, z0 + h), (a1, cv, z0 + h)
            back = [(a0, b0, z0), (a1, b0, z0), r1, r0]
            front = [(a1, b1, z0), (a0, b1, z0), r0, r1]
            tri = [(u1, v1, z0), (u1, v0, z0), (u1, cv, z0 + h)]
            self.face(back, ramp)
            if end is not None:
                self.poly(tri, end)
            self.face(front, ramp)
        else:
            cu = (u0 + u1) / 2
            a0, a1 = v0 - over, v1 + over
            b0, b1 = u0 - over, u1 + over
            r0, r1 = (cu, a0, z0 + h), (cu, a1, z0 + h)
            back = [(b0, a1, z0), (b0, a0, z0), r0, r1]
            front = [(b1, a0, z0), (b1, a1, z0), r1, r0]
            tri = [(u0, v1, z0), (u1, v1, z0), (cu, v1, z0 + h)]
            self.face(back, ramp)
            if end is not None:
                self.poly(tri, end)
            self.face(front, ramp)


def _ring(cu, cv, r, sides):
    # Ξεκινάει μισή έδρα στραμμένο, ώστε οι έδρες να κοιτάνε ΝΔ/ΝΑ όπως οι
    # τοίχοι των κουτιών και όχι κατευθείαν στην κάμερα.
    out = []
    for k in range(sides):
        a = 2 * math.pi * (k + 0.5) / sides
        out.append((cu + r * math.cos(a), cv + r * math.sin(a)))
    return out


def shade(n, ramp):
    """Pen από το φως: ramp = (σκιά, φως) ή (σκιά, μέσο, φως)."""
    t = light(n)
    if len(ramp) == 2:
        return ramp[1] if t > 0.72 else ramp[0]
    if t > 0.85:
        return ramp[2]
    if t > 0.50:
        return ramp[1]
    return ramp[0]
