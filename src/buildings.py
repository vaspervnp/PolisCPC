"""Τα κτίρια: ποια υπάρχουν σε κάθε εποχή, και πώς ζωγραφίζονται.

Ο ΠΙΝΑΚΑΣ ΕΠΟΧΩΝ ΕΙΝΑΙ Ο ΚΑΝΟΝΑΣ

Κάθε κτίριο έχει `ages`: τις εποχές στις οποίες **αλλάζει όψη**. Αυτές και
μόνο αυτές ζωγραφίζονται.

* Αν ένα κτίριο δεν υπάρχει σε μια εποχή, δεν μπαίνει καθόλου — ο ναός
  ξεκινάει στη Χαλκού, οπότε δεν υπάρχει `temple` Λίθινης ή Εργαλείων.
* Αν υπάρχει αλλά **δεν αλλάζει**, δεν ξαναζωγραφίζεται — το σπίτι αλλάζει
  στη Λίθινη και στη Χαλκού, άρα δύο αρχεία: το πρώτο ισχύει για τις εποχές
  1-2 και το δεύτερο για τις 3-4.

Το `sprites.json` γράφει για κάθε κτίριο ποιο αρχείο ισχύει σε ποια εποχή,
ώστε το παιχνίδι να μη χρειάζεται να ξέρει αυτόν τον κανόνα.

ΤΑ ΜΕΓΕΘΗ

    S  12x16   σπίτι, αποθήκη, χωράφι, πύργος, τείχος
    M  16x20   στρατώνας, αγορά, ναός, λιμάνι, στάβλος, σκοπευτήριο
    L  24x24   κέντρο πόλης, κυβερνείο, ακαδημία, θαύμα

Όλα πατάνε στην ΚΑΤΩ γραμμή του καμβά: ο χάρτης τα τοποθετεί από τη βάση,
όπως και τις μονάδες.
"""
from bstyle import (AGE_NAMES, CULTURES, Style, banner, columns, door, ground,
                    rect, roof, trim_line, wall)
from gfx import PEN, blank

SIZES = {'S': (12, 16), 'M': (16, 20), 'L': (24, 24)}


def _canvas(size):
    w, h = SIZES[size]
    return blank(w, h, None), w, h


# ----------------------------------------------------------- τα σχέδια
# Κάθε σχέδιο παίρνει (img, st, w, h) και ζωγραφίζει με βάση το κάτω μέρος.

def bp_house(img, st, w, h):
    b = h - 1
    wall(img, 2, b - 6, w - 4, 6, st)
    roof(img, 1, b - 10, w - 2, 4, st)
    door(img, w // 2 - 1, b - 3, 2, 3)
    ground(img, 1, b, w - 2)


def bp_town_center(img, st, w, h):
    b = h - 1
    wall(img, 2, b - 10, w - 4, 10, st)
    roof(img, 0, b - 16, w, 6, st)
    door(img, w // 2 - 2, b - 5, 4, 5)
    trim_line(img, 3, b - 11, w - 6, st)
    if st.age >= 3:
        rect(img, 4, b - 8, 2, 2, PEN['K'])
        rect(img, w - 6, b - 8, 2, 2, PEN['K'])
    if st.age >= 2:
        banner(img, 1, b - 20, 5, st)
    ground(img, 1, b, w - 2)


def bp_granary(img, st, w, h):
    """Σιταποθήκη: χαμηλή και πλατιά, με σωρούς σταριού μπροστά."""
    b = h - 1
    wall(img, 1, b - 7, w - 2, 7, st)
    roof(img, 0, b - 11, w, 4, st)
    door(img, w // 2 - 1, b - 3, 2, 3)
    rect(img, 2, b - 2, 2, 2, PEN['y'])
    rect(img, w - 4, b - 2, 2, 2, PEN['o'])
    ground(img, 0, b, w)


def bp_storage_pit(img, st, w, h):
    """Αποθήκη: ανοιχτός χώρος με στύλους και εμπορεύματα, όχι κλειστό κτίριο."""
    b = h - 1
    rect(img, 1, b - 2, w - 2, 2, PEN['d'])
    rect(img, 2, b - 7, 1, 5, PEN['d'])
    rect(img, w - 3, b - 7, 1, 5, PEN['d'])
    roof(img, 1, b - 10, w - 2, 3, st)
    rect(img, 4, b - 4, 2, 2, PEN['i'])
    rect(img, 7, b - 4, 2, 2, PEN['D'])
    ground(img, 0, b, w)


def bp_barracks(img, st, w, h):
    """Στρατώνας: ασπίδα στον τοίχο — το σήμα που ξεχωρίζει από μακριά."""
    b = h - 1
    wall(img, 1, b - 9, w - 2, 9, st)
    roof(img, 0, b - 14, w, 5, st)
    door(img, w // 2 - 1, b - 4, 3, 4)
    rect(img, 3, b - 7, 3, 3, PEN['T'])
    rect(img, 4, b - 6, 1, 1, PEN['y'])
    if st.age >= 3:
        rect(img, w - 5, b - 8, 1, 5, PEN['i'])
    ground(img, 0, b, w)


def bp_archery(img, st, w, h):
    """Σκοπευτήριο: στόχος στον τοίχο."""
    b = h - 1
    wall(img, 1, b - 8, w - 2, 8, st)
    roof(img, 0, b - 13, w, 5, st)
    door(img, 2, b - 4, 2, 4)
    cx, cy = w - 5, b - 6
    rect(img, cx, cy, 4, 4, PEN['I'])
    rect(img, cx + 1, cy + 1, 2, 2, PEN['r'])
    ground(img, 0, b, w)


def bp_stable(img, st, w, h):
    """Στάβλος: φράχτης μπροστά και ανοιχτή πόρτα."""
    b = h - 1
    wall(img, 1, b - 8, w - 2, 8, st)
    roof(img, 0, b - 13, w, 5, st)
    door(img, w // 2 - 2, b - 5, 4, 5)
    for i in range(1, w - 1, 3):
        rect(img, i, b - 2, 1, 2, PEN['d'])
    rect(img, 1, b - 2, w - 2, 1, PEN['D'])
    ground(img, 0, b, w)


def bp_market(img, st, w, h):
    """Αγορά: ανοιχτοί πάγκοι με τέντα, όχι κλειστοί τοίχοι."""
    b = h - 1
    rect(img, 2, b - 6, 1, 6, PEN['d'])
    rect(img, w - 3, b - 6, 1, 6, PEN['d'])
    wall(img, 3, b - 5, w - 6, 5, st)
    for i in range(1, w - 1, 2):
        rect(img, i, b - 9, 1, 3, PEN['r'])
        rect(img, i + 1, b - 9, 1, 3, PEN['I'])
    rect(img, 4, b - 3, 2, 2, PEN['y'])
    rect(img, w - 6, b - 3, 2, 2, PEN['g'])
    ground(img, 0, b, w)


def bp_dock(img, st, w, h):
    """Λιμάνι: προβλήτα πάνω από νερό."""
    b = h - 1
    rect(img, 0, b - 1, w, 2, PEN['t'])
    rect(img, 1, b - 3, w - 2, 2, PEN['d'])
    for i in range(2, w - 2, 3):
        rect(img, i, b - 2, 1, 2, PEN['K'])
    wall(img, 2, b - 9, w - 7, 6, st)
    roof(img, 1, b - 13, w - 5, 4, st)
    rect(img, w - 4, b - 11, 1, 8, PEN['D'])
    rect(img, w - 4, b - 11, 3, 4, PEN['I'])


def bp_farm(img, st, w, h):
    """Χωράφι: αυλάκια, όχι κτίριο. Δεν αλλάζει ποτέ με την εποχή."""
    b = h - 1
    rect(img, 0, b - 7, w, 8, PEN['D'])
    for j in range(b - 6, b, 2):
        rect(img, 1, j, w - 2, 1, PEN['g'])
    rect(img, 0, b - 8, w, 1, PEN['d'])
    ground(img, 0, b, w)


def bp_tower(img, st, w, h):
    """Πύργος: ψηλός και στενός. Μεγαλώνει με την αναβάθμιση."""
    b = h - 1
    tall = 8 + 2 * (st.age - 2)
    x = w // 2 - 2
    wall(img, x, b - tall, 4, tall, st)
    rect(img, x - 1, b - tall - 2, 6, 2, st.wall_light)
    for i in range(x - 1, x + 5, 2):
        rect(img, i, b - tall - 3, 1, 1, st.wall_dark)
    door(img, x + 1, b - 3, 2, 3)
    if st.age >= 4:
        rect(img, x, b - tall + 2, 1, 2, PEN['K'])
        rect(img, x + 3, b - tall + 2, 1, 2, PEN['K'])
    ground(img, x - 1, b, 6)


def bp_wall(img, st, w, h):
    """Τείχος: τμήμα με επάλξεις. Παχαίνει με την αναβάθμιση."""
    b = h - 1
    tall = 4 + 2 * (st.age - 2)
    wall(img, 0, b - tall, w, tall, st)
    for i in range(0, w, 2):
        rect(img, i, b - tall - 1, 1, 1, st.wall_light)
    ground(img, 0, b, w)


def bp_temple(img, st, w, h):
    """Ναός: κιονοστοιχία και μεγάλη στέγη — το πιο επίσημο κτίριο."""
    b = h - 1
    rect(img, 0, b - 2, w, 2, st.wall_dark)
    rect(img, 1, b - 3, w - 2, 1, st.wall_light)
    columns(img, 2, b - 10, w - 4, 7, st)
    roof(img, 0, b - 15, w, 5, st)
    trim_line(img, 1, b - 11, w - 2, st)
    door(img, w // 2 - 1, b - 6, 2, 3)
    if st.age >= 4:
        banner(img, w - 2, b - 19, 4, st)
    ground(img, 0, b, w)


def bp_gov_center(img, st, w, h):
    b = h - 1
    rect(img, 1, b - 2, w - 2, 2, st.wall_dark)
    wall(img, 3, b - 11, w - 6, 9, st)
    columns(img, 4, b - 9, w - 8, 7, st)
    roof(img, 1, b - 17, w - 2, 6, st)
    trim_line(img, 3, b - 12, w - 6, st)
    door(img, w // 2 - 2, b - 6, 4, 4)
    banner(img, 2, b - 21, 5, st)
    ground(img, 0, b, w)


def bp_academy(img, st, w, h):
    b = h - 1
    rect(img, 1, b - 2, w - 2, 2, st.wall_dark)
    columns(img, 2, b - 12, w - 4, 10, st)
    roof(img, 0, b - 18, w, 6, st)
    trim_line(img, 2, b - 13, w - 4, st)
    door(img, w // 2 - 2, b - 7, 4, 5)
    rect(img, w // 2 - 1, b - 21, 2, 3, PEN['i'])
    ground(img, 0, b, w)


def bp_siege_works(img, st, w, h):
    """Πολιορκητικά: ανοιχτό υπόστεγο με βραχίονα καταπέλτη απ' έξω."""
    b = h - 1
    wall(img, 1, b - 7, w - 4, 7, st)
    roof(img, 0, b - 11, w - 2, 4, st)
    door(img, 3, b - 5, 4, 5)
    rect(img, w - 4, b - 10, 1, 7, PEN['d'])
    rect(img, w - 5, b - 11, 3, 1, PEN['d'])
    rect(img, w - 3, b - 3, 2, 2, PEN['y'])
    ground(img, 0, b, w)


def bp_wonder(img, st, w, h):
    """Θαύμα: το σχήμα του πολιτισμού, όχι κοινό κτίριο.

    Είναι το μόνο κτίριο που ΔΕΝ βγαίνει από το ίδιο σχέδιο για όλους: μια
    πυραμίδα και ένας Παρθενώνας δεν έχουν κοινή κάτοψη. Εδώ ο πολιτισμός
    διαλέγει σιλουέτα, όχι μόνο υλικό.
    """
    b = h - 1
    c = st.culture
    if c in ('egypt',):
        for j in range(h - 2):
            inset = j * w // (2 * (h - 2))
            rect(img, inset, b - 1 - j, w - 2 * inset, 1,
                 st.wall_light if j % 3 else st.wall_dark)
    elif c in ('babylon', 'persia'):
        for k in range(4):
            y = b - 4 - k * 4
            inset = 1 + k * 2
            rect(img, inset, y, w - 2 * inset, 4, st.wall_light)
            rect(img, inset, y, 1, 4, st.wall_dark)
            rect(img, inset, y + 3, w - 2 * inset, 1, st.wall_dark)
    elif c in ('asia',):
        for k in range(4):
            y = b - 4 - k * 5
            inset = 2 + k
            wall(img, inset + 1, y, w - 2 * inset - 2, 4, st)
            rect(img, inset - 1, y - 1, w - 2 * inset + 2, 1, st.roof_light)
            rect(img, inset - 1, y, w - 2 * inset + 2, 1, st.roof_dark)
    elif c in ('celt',):
        # Κωνική αχυρένια στέγη. Το `j` μετράει ΑΠΟ ΚΑΤΩ προς τα πάνω, άρα το
        # στένεμα πρέπει να ΜΕΓΑΛΩΝΕΙ με το j — η πρώτη γραφή το είχε
        # ανάποδα και το θαύμα έβγαινε ανεστραμμένο χωνί.
        for j in range(h - 4):
            inset = j * w // (2 * (h - 4))
            rect(img, inset, b - 3 - j, w - 2 * inset, 1,
                 st.roof_light if j % 2 else st.roof_dark)
        rect(img, 2, b - 3, w - 4, 3, st.wall_light)
    else:                                   # greek, rome, phoenicia
        rect(img, 0, b - 3, w, 3, st.wall_dark)
        rect(img, 1, b - 4, w - 2, 1, st.wall_light)
        columns(img, 2, b - 15, w - 4, 11, st)
        roof(img, 0, b - 21, w, 6, st)
        trim_line(img, 2, b - 16, w - 4, st)
    if st.trim_pen is not None:
        rect(img, w // 2 - 1, 0, 2, 2, st.trim_pen)
    ground(img, 0, b, w)


# ------------------------------------------------------------- ο πίνακας
# (κλειδί, όνομα, μέγεθος, εποχές που ΑΛΛΑΖΕΙ όψη, σχέδιο)
#
# Οι εποχές: 1 Λίθινη, 2 Εργαλείων, 3 Χαλκού, 4 Σιδήρου.
BUILDINGS = [
    ('town_center', 'Κέντρο Πόλης',   'L', [1, 2, 3, 4], bp_town_center),
    ('house',       'Σπίτι',          'S', [1, 3],       bp_house),
    ('granary',     'Σιταποθήκη',     'M', [1, 3],       bp_granary),
    ('storage_pit', 'Αποθήκη',        'S', [1, 3],       bp_storage_pit),
    ('barracks',    'Στρατώνας',      'M', [2, 3],       bp_barracks),
    ('dock',        'Λιμάνι',         'M', [2, 3],       bp_dock),
    ('market',      'Αγορά',          'M', [2, 3],       bp_market),
    ('archery',     'Σκοπευτήριο',    'M', [2, 3],       bp_archery),
    ('stable',      'Στάβλος',        'M', [2, 3],       bp_stable),
    ('farm',        'Χωράφι',         'S', [2],          bp_farm),
    ('tower',       'Πύργος',         'S', [2, 3, 4],    bp_tower),
    ('wall',        'Τείχος',         'S', [2, 3, 4],    bp_wall),
    ('temple',      'Ναός',           'M', [3, 4],       bp_temple),
    ('gov_center',  'Κυβερνείο',      'L', [3],          bp_gov_center),
    ('academy',     'Ακαδημία',       'L', [3],          bp_academy),
    ('siege_works', 'Πολιορκητικά',   'M', [3],          bp_siege_works),
    ('wonder',      'Θαύμα',          'L', [4],          bp_wonder),
]

BY_KEY = {b[0]: b for b in BUILDINGS}


def covers(ages):
    """-> {εποχή: ποια παραλλαγή ισχύει}. Μια παραλλαγή κρατάει ώσπου να
    έρθει η επόμενη· πριν την πρώτη το κτίριο δεν υπάρχει."""
    out = {}
    for age in (1, 2, 3, 4):
        valid = [a for a in ages if a <= age]
        if valid:
            out[age] = max(valid)
    return out


def render(key, culture, age):
    _, _, size, _, blueprint = BY_KEY[key]
    img, w, h = _canvas(size)
    blueprint(img, Style(culture, age), w, h)
    return img


def variants(key):
    """-> [(εποχή, όνομα εποχής)] μόνο για τις εποχές που ζωγραφίζονται."""
    return [(a, AGE_NAMES[a]) for a in BY_KEY[key][3]]
