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

def rect(img, x, y, w, h, pen):
    for j in range(y, min(y + h, len(img))):
        for i in range(x, min(x + w, len(img[0]))):
            if i >= 0 and j >= 0:
                img[j][i] = pen


def wall(img, x, y, w, h, st):
    """Τοίχος: φωτεινός, με μια σκοτεινή στήλη αριστερά για όγκο.

    Ένα κτίριο σε ένα μόνο χρώμα διαβάζεται ως πλακάκι, όχι ως όγκος. Μία
    στήλη σκιάς είναι το φθηνότερο που δίνει τρίτη διάσταση σε 16 pixels.
    """
    rect(img, x, y, w, h, st.wall_light)
    rect(img, x, y, 1, h, st.wall_dark)
    rect(img, x, y + h - 1, w, 1, st.wall_dark)


def door(img, x, y, w, h, pen=None):
    rect(img, x, y, w, h, pen if pen is not None else PEN['K'])


def roof(img, x, y, w, h, st):
    """Η στέγη, στο σχήμα του πολιτισμού. Το σχήμα είναι ό,τι ξεχωρίζει έναν
    ναό από έναν άλλο από μακριά — πιο πολύ κι από το χρώμα."""
    s = st.shape
    if s == 'flat':
        rect(img, x, y + h - 2, w, 2, st.roof_light)
        rect(img, x, y + h - 2, w, 1, st.roof_dark)
    elif s == 'gable':
        for j in range(h):
            inset = (h - 1 - j) * w // (2 * h)
            rect(img, x + inset, y + j, w - 2 * inset, 1,
                 st.roof_light if j else st.roof_dark)
    elif s == 'cone':
        for j in range(h):
            inset = (h - 1 - j) * (w // 2) // max(1, h - 1)
            rect(img, x + inset, y + j, w - 2 * inset, 1,
                 st.roof_light if j % 2 else st.roof_dark)
    elif s == 'dome':
        for j in range(h):
            inset = max(0, (h - 1 - j) * w // (3 * h))
            rect(img, x + inset, y + j, w - 2 * inset, 1,
                 st.roof_dark if j == 0 else st.roof_light)
        rect(img, x + w // 2, y, 1, 1, st.roof_dark)
    elif s == 'pagoda':
        for j in range(h):
            out = j
            rect(img, x - out, y + j, w + 2 * out, 1,
                 st.roof_dark if j == h - 1 else st.roof_light)
    elif s == 'step':
        for j in range(h):
            inset = (h - 1 - j)
            rect(img, x + inset, y + j, w - 2 * inset, 1,
                 st.roof_light if j % 2 else st.roof_dark)
    elif s == 'pylon':
        rect(img, x, y, w, h, st.wall_light)
        rect(img, x, y, 1, h, st.wall_dark)
        rect(img, x + w - 1, y, 1, h, st.wall_dark)
        rect(img, x, y, w, 1, st.roof_dark)


def banner(img, x, y, h, st):
    """Σημαία στο χρώμα του παίκτη — ποιος ελέγχει το κτίριο."""
    rect(img, x, y, 1, h, PEN['d'])
    rect(img, x + 1, y, 2, 2, PEN['T'])
    rect(img, x + 1, y + 2, 2, 1, PEN['t'])


def trim_line(img, x, y, w, st):
    if st.trim_pen is not None:
        rect(img, x, y, w, 1, st.trim_pen)


def columns(img, x, y, w, h, st, step=2):
    """Κιονοστοιχία — το σήμα του ελληνικού και του ρωμαϊκού ναού."""
    for i in range(x, x + w, step):
        rect(img, i, y, 1, h, st.wall_light)
        rect(img, i + 1, y, 1, h, st.wall_dark) if step > 1 else None


def ground(img, x, y, w, pen=None):
    rect(img, x, y, w, 1, pen if pen is not None else PEN['K'])
