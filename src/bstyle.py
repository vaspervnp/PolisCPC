"""Οι οκτώ πολιτισμοί και τα σχήματα από τα οποία χτίζονται τα κτίρια.

ΓΙΑΤΙ ΠΑΡΑΜΕΤΡΙΚΑ ΚΑΙ ΟΧΙ ΖΩΓΡΑΦΙΣΜΕΝΑ ΕΝΑ-ΕΝΑ

Οκτώ πολιτισμοί επί δεκαεπτά κτίρια επί τέσσερις εποχές είναι εκατοντάδες
εικόνες. Ζωγραφισμένες μία-μία θα ήταν και ασυνεπείς και αδύνατο να
διορθωθούν. Εδώ υπάρχει ΕΝΑ σχέδιο ανά κτίριο — πού πάει η στέγη, πού η
πόρτα, πόσο ψηλός ο τοίχος — και ο πολιτισμός δίνει μόνο ΥΛΙΚΑ και ΣΧΗΜΑ
ΣΤΕΓΗΣ. Αλλάζοντας μία γραμμή στον πολιτισμό αλλάζουν και τα δεκαεπτά κτίριά
του μαζί.

Η ΕΠΟΧΗ ΑΛΛΑΖΕΙ ΥΛΙΚΟ ΚΑΙ ΟΓΚΟ

    1 Λίθινη   ξύλο και αχυρένια στέγη, χαμηλό, χωρίς στολίδια
    2 Εργαλείων  ίδιο υλικό, πιο ψηλό, μια λεπτομέρεια
    3 Χαλκού   το υλικό του πολιτισμού, κανονική στέγη, στολίδι
    4 Σιδήρου  πέτρα/μάρμαρο, ψηλότερο, σημαία

Στη Λίθινη ΟΛΟΙ οι πολιτισμοί μοιάζουν — καλύβες είναι. Η ταυτότητα
εμφανίζεται από τη Χαλκού και μετά, που είναι και ιστορικά το σωστό.
"""
import iso
from gfx import PEN

# (κλειδί, όνομα, τοίχος σκιά/φως, στέγη σκιά/φως, σχήμα στέγης, στολίδι)
CULTURES = [
    ('egypt',     'Αιγύπτιοι',   ('o', 'S'), ('o', 'S'), 'pylon',  'y'),
    ('greek',     'Έλληνες',     ('i', 'I'), ('d', 'r'), 'gable',  'r'),
    ('babylon',   'Βαβυλώνιοι',  ('d', 'D'), ('d', 'D'), 'step',   'T'),
    ('asia',      'Ασιάτες',     ('d', 'D'), ('n', 'g'), 'pagoda', 'r'),
    ('rome',      'Ρωμαίοι',     ('i', 'I'), ('d', 'r'), 'gable',  'T'),
    ('persia',    'Πέρσες',      ('D', 'o'), ('T', 't'), 'dome',   'y'),
    ('phoenicia', 'Φοίνικες',    ('i', 'o'), ('i', 'o'), 'flat',   'c'),
    ('celt',      'Κέλτες',      ('d', 'D'), ('o', 'S'), 'cone',   'n'),
]

BY_KEY = {c[0]: c for c in CULTURES}

# Τα υλικά της εποχής. Στη Λίθινη και στην Εργαλείων ο πολιτισμός ΔΕΝ φαίνεται:
# όλοι χτίζουν με ξύλο και άχυρο. Το None σημαίνει «πάρε το υλικό του
# πολιτισμού».
AGE_WALL = {1: ('d', 'D'), 2: ('d', 'D'), 3: None, 4: None}
AGE_ROOF = {1: ('o', 'S'), 2: ('o', 'S'), 3: None, 4: None}
AGE_SHAPE = {1: 'cone', 2: 'gable', 3: None, 4: None}

AGE_NAMES = {1: 'stone', 2: 'tool', 3: 'bronze', 4: 'iron'}


class Style:
    """Τα χρώματα και τα σχήματα ενός πολιτισμού σε μια συγκεκριμένη εποχή."""

    def __init__(self, culture, age):
        key, name, wall, roof, shape, trim = BY_KEY[culture]
        self.culture, self.name, self.age = key, name, age
        self.wall = AGE_WALL[age] or wall
        self.roof = AGE_ROOF[age] or roof
        self.shape = AGE_SHAPE[age] or shape
        self.trim = trim if age >= 3 else None
        # ΔΕΝ γίνονται όλοι πέτρα στη Σιδήρου. Το δοκίμασα και έσβηνε το υλικό
        # τεσσάρων πολιτισμών (Αίγυπτος, Βαβυλώνα, Ασία, Κέλτες) ακριβώς στην
        # εποχή που θα έπρεπε να ξεχωρίζουν περισσότερο: όλα τα κτίρια
        # κατέληγαν άσπρα και οι οκτώ σειρές έμοιαζαν μεταξύ τους. Η εποχή
        # αλλάζει ήδη σχήμα, στολίδι και σημαία — το υλικό μένει του
        # πολιτισμού.

    def p(self, ch):
        return PEN[ch]

    @property
    def wall_dark(self):
        return PEN[self.wall[0]]

    @property
    def wall_light(self):
        return PEN[self.wall[1]]

    @property
    def roof_dark(self):
        return PEN[self.roof[0]]

    @property
    def roof_light(self):
        return PEN[self.roof[1]]

    @property
    def trim_pen(self):
        return PEN[self.trim] if self.trim else None


# ------------------------------------------------------------- σχήματα
#
# Όλα δουλεύουν σε συντεταγμένες κόσμου (u, v, z) πάνω σε `iso.Scene`: u, v
# σε βήματα (4 = ένα πλακίδιο), z σε γραμμές. Ο αριστερός τοίχος («L», κοιτάει
# ΝΔ) είναι ο φωτεινός, ο δεξιός («R», ΝΑ) η σκιά.


def ramp_wall(st):
    return (st.wall_dark, st.wall_light)


def ramp_roof(st):
    return (st.roof_dark, st.roof_light)


def foundation(sc, n, pen=None, inset=0.0):
    """Το πατημένο χώμα κάτω από το κτίριο — αυτό το «γειώνει» πάνω στο
    γρασίδι, όπως στο Age of Empires. Πιάνει όλη την κάτοψη."""
    e = 4 * n - inset
    sc.floor(inset, inset, e, e, PEN['o'] if pen is None else pen)


def walls(sc, st, u0, v0, u1, v1, h, z0=0):
    """Το σώμα: δύο ορατοί τοίχοι, φωτεινός αριστερά, σκιά δεξιά, και μια
    σκοτεινή γραμμή στη βάση που το κολλάει στο έδαφος."""
    sc.box(u0, v0, u1, v1, z0, z0 + h, st.wall_light, st.wall_dark,
           st.wall_light)
    if z0 == 0:
        sc.on_wall('L', v1, u0, u1, 0, 1, PEN['K'])
        sc.on_wall('R', u1, v0, v1, 0, 1, PEN['K'])


def door(sc, side, k, a, w, h, pen=None):
    sc.on_wall(side, k, a, a + w, 1 if h > 2 else 0, h,
               PEN['K'] if pen is None else pen)


def window(sc, side, k, a, z, w=1, h=2, pen=None):
    sc.on_wall(side, k, a, a + w, z, z + h, PEN['K'] if pen is None else pen)


def trim_band(sc, st, u0, v0, u1, v1, z):
    """Στολίδι του πολιτισμού: μια λωρίδα στην κορυφή των δύο τοίχων."""
    if st.trim_pen is None:
        return
    sc.on_wall('L', v1, u0, u1, z - 1, z, st.trim_pen)
    sc.on_wall('R', u1, v0, v1, z - 1, z, st.trim_pen)


def roof(sc, st, u0, v0, u1, v1, z, h, axis='u'):
    """Η στέγη, στο σχήμα του πολιτισμού. Το σχήμα ξεχωρίζει έναν ναό από
    έναν άλλο από μακριά — πιο πολύ κι από το χρώμα."""
    s = st.shape
    rr = ramp_roof(st)
    if s == 'gable':
        sc.gable(u0, v0, u1, v1, z, h, rr, st.wall_dark, axis=axis, over=0.5)
    elif s == 'cone':
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        r = max(u1 - u0, v1 - v0) / 2 * 1.15
        sc.cone(cu, cv, r, z, h + 2, rr)
    elif s == 'pagoda':
        sc.hip(u0, v0, u1, v1, z, max(2, h - 1), rr, ridge=None, over=1.5)
    elif s == 'dome':
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        r = min(u1 - u0, v1 - v0) / 2
        sc.dome(cu, cv, r * 0.9, z, h + 1, rr)
        sc.poly([(cu, cv, z + h + 1), (cu, cv, z + h + 3),
                 (cu + 0.5, cv + 0.5, z + h + 3)], st.roof_dark)
    elif s == 'flat':
        sc.box(u0, v0, u1, v1, z, z + 1, st.roof_light, st.roof_dark,
               st.roof_dark)
        sc.box(u0 + 1, v0 + 1, u1 - 1, v1 - 1, z + 1, z + 1, None, None,
               st.roof_light)
    elif s == 'step':
        k, uu0, vv0, uu1, vv1, zz = 0, u0, v0, u1, v1, z
        while uu1 - uu0 > 1.5 and vv1 - vv0 > 1.5 and k < max(1, h // 2):
            sc.box(uu0, vv0, uu1, vv1, zz, zz + 2, st.roof_light,
                   st.roof_dark, st.roof_light)
            uu0, vv0, uu1, vv1, zz, k = uu0 + 1, vv0 + 1, uu1 - 1, vv1 - 1, \
                zz + 2, k + 1
    elif s == 'pylon':
        # Αιγυπτιακό: επίπεδη στέγη με φαρδύ γείσο (κοίλο κορνίζωμα).
        sc.box(u0 - 0.5, v0 - 0.5, u1 + 0.5, v1 + 0.5, z, z + 2,
               st.roof_dark, st.roof_dark, st.roof_light)


def banner(sc, u, v, z, h):
    """Σημαία στο χρώμα του παίκτη — ποιος ελέγχει το κτίριο. Ο ιστός είναι
    στο σημείο (u, v, z) του κόσμου· το πανί ανεμίζει δεξιά στην οθόνη."""
    x, y = iso.project((u, v, z), sc.ox, sc.oy)
    x, y = int(round(x)), int(round(y))
    img = sc.img
    def put(xx, yy, p):
        if 0 <= yy < len(img) and 0 <= xx < len(img[0]):
            img[yy][xx] = p
    for k in range(h):
        put(x, y - 1 - k, PEN['d'])
    for yy in range(y - h, y - h + 2):
        put(x + 1, yy, PEN['T'])
        put(x + 2, yy, PEN['T'])
    put(x + 1, y - h + 2, PEN['t'])


def columns(sc, st, side, k, a0, a1, z0, z1, step=2):
    """Κιονοστοιχία πάνω σε τοίχο: κολόνες φωτεινές, κενά σκοτεινά — το σήμα
    του ελληνικού και του ρωμαϊκού ναού."""
    sc.on_wall(side, k, a0, a1, z0, z1, PEN['K'])
    a = a0
    pen = st.wall_light if side == 'L' else st.wall_dark
    while a < a1:
        sc.on_wall(side, k, a, min(a + 1, a1), z0, z1, pen)
        a += step
