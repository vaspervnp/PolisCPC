"""Τα κτίρια: ποια υπάρχουν σε κάθε εποχή, και πώς ζωγραφίζονται — ΙΣΟΜΕΤΡΙΚΑ.

Ο ΠΙΝΑΚΑΣ ΕΠΟΧΩΝ ΕΙΝΑΙ Ο ΚΑΝΟΝΑΣ

Κάθε κτίριο έχει `ages`: τις εποχές στις οποίες **αλλάζει όψη**. Αυτές και
μόνο αυτές ζωγραφίζονται.

* Αν ένα κτίριο δεν υπάρχει σε μια εποχή, δεν μπαίνει καθόλου — ο ναός
  ξεκινάει στη Χαλκού, οπότε δεν υπάρχει `temple` Λίθινης ή Εργαλείων.
* Αν υπάρχει αλλά **δεν αλλάζει**, δεν ξαναζωγραφίζεται — το σπίτι αλλάζει
  στη Λίθινη και στη Χαλκού, άρα δύο αρχεία: το πρώτο ισχύει για τις εποχές
  1-2 και το δεύτερο για τις 3-4.

Το `buildings.json` γράφει για κάθε κτίριο ποιο αρχείο ισχύει σε ποια εποχή,
ώστε το παιχνίδι να μη χρειάζεται να ξέρει αυτόν τον κανόνα.

ΤΑ ΜΕΓΕΘΗ ΕΙΝΑΙ ΚΑΤΟΨΕΙΣ ΣΕ ΠΛΑΚΙΔΙΑ

    T  1x1   8 pixels πλάτος   τείχος (κομμάτια που ενώνονται)
    S  2x2  16                 σπίτι, αποθήκη, πύργος
    M  3x3  24                 στρατώνας, σιταποθήκη, χωράφι, ναός, ...
    L  4x4  32                 κέντρο πόλης, κυβερνείο, ακαδημία, θαύμα

Το πλάτος είναι ΑΚΡΙΒΩΣ η κάτοψη: ένα κτίριο 3x3 πιάνει 24 pixels, όσο τρία
πλακίδια στη σειρά. Το ύψος δεν είναι σταθερό — ο καμβάς είναι γενναιόδωρος
και ΚΟΒΕΤΑΙ από πάνω ώστε να μένουν μόνο οι γραμμές που έχουν κάτι
(`trim_top`). Το παιχνίδι τα τοποθετεί από τη ΒΑΣΗ: η κάτω γραμμή του
κτιρίου είναι η κάτω γραμμή του κουτιού του μπροστινού πλακιδίου, άρα το
ύψος ανά εικόνα (που ο πίνακας έχει ήδη) αρκεί.

ΚΑΘΕ ΚΤΙΡΙΟ ΕΙΝΑΙ ΜΙΚΡΟ ΜΟΝΤΕΛΟ

Δεν ζωγραφίζονται pixel-pixel: κάθε σχέδιο στήνει κουτιά, στέγες, κώνους
και τρούλους στον χώρο, και το `iso.Scene` τα προβάλλει και τα σκιάζει. Έτσι
οκτώ πολιτισμοί x τέσσερις εποχές βγαίνουν με την ίδια προοπτική και το ίδιο
φως — που ζωγραφισμένα με το χέρι δεν θα έβγαιναν ποτέ.
"""
import iso
from bstyle import (AGE_NAMES, CULTURES, Style, banner, columns, door,
                    foundation, ramp_roof, ramp_wall, roof, trim_band, walls,
                    window)
from gfx import PEN, blank

# μέγεθος -> (κάτοψη σε πλακίδια, πλάτος pixels, ύψος καμβά πριν το κόψιμο)
SIZES = {'T': (1, 8, 24), 'S': (2, 16, 44), 'M': (3, 24, 48), 'L': (4, 32, 64)}


def _scene(size):
    n, w, h = SIZES[size]
    img = blank(w, h, None)
    return iso.Scene(img, 4 * n, h - 8 * n), n


def trim_top(img):
    """Κόβει τις άδειες γραμμές από πάνω. Από κάτω ΔΕΝ κόβει: η βάση είναι
    το σημείο αναφοράς."""
    k = 0
    while k < len(img) - 1 and all(p is None for p in img[k]):
        k += 1
    return img[k:]


# ------------------------------------------------------ κοινά κομμάτια

def body(sc, st, u0, v0, u1, v1, h):
    """Το σώμα του κτιρίου: στρογγυλή καλύβα όταν η στέγη είναι κωνική
    (Λίθινη, Κέλτες), αλλιώς ορθογώνιο. Επιστρέφει τους δύο ορατούς τοίχους
    ως (πλευρά, θέση, από, ώς) για πόρτες και παράθυρα."""
    if st.shape == 'cone':
        cu, cv = (u0 + u1) / 2, (v0 + v1) / 2
        r = min(u1 - u0, v1 - v0) / 2
        sc.prism(cu, cv, r, 0, h, ramp_wall(st))
        k = r * 0.924                       # cos 22,5°: η απόσταση της έδρας
        a = r * 0.383
        return ('L', cv + k, cu - a, cu + a), ('R', cu + k, cv - a, cv + a)
    walls(sc, st, u0, v0, u1, v1, h)
    return ('L', v1, u0, u1), ('R', u1, v0, v1)


def hall(sc, st, u0, v0, u1, v1, h, rh, axis='u'):
    """Σώμα + στέγη του πολιτισμού + στολίδι. Το πιο κοινό σχέδιο."""
    L, R = body(sc, st, u0, v0, u1, v1, h)
    if st.shape != 'cone':
        trim_band(sc, st, u0, v0, u1, v1, h)
    roof(sc, st, u0, v0, u1, v1, h, rh, axis)
    return L, R


def mid(span, w):
    _, _, a0, a1 = span
    return (a0 + a1) / 2 - w / 2


def crate(sc, u, v, s, top, side):
    sc.box(u, v, u + s, v + s, 0, s, side, PEN['K'], top)


# ----------------------------------------------------------- τα σχέδια
# Κάθε σχέδιο παίρνει (sc, st, n). Κάτοψη u, v σε [0, 4n).

def bp_house(sc, st, n):
    foundation(sc, n)
    L, R = hall(sc, st, 1.5, 2, 6.5, 6.5, 5, 4)
    door(sc, L[0], L[1], mid(L, 1.5), 1.5, 4)
    if st.age >= 3:
        window(sc, R[0], R[1], mid(R, 1), 2)


def bp_town_center(sc, st, n):
    foundation(sc, n)
    if st.age >= 3:
        # πλαϊνή πτέρυγα πίσω-δεξιά: το κέντρο πόλης μεγαλώνει με την εποχή
        walls(sc, st, 9, 1, 15, 6, 6)
        roof(sc, st, 9, 1, 15, 6, 6, 3)
    h = 6 + st.age
    L, R = hall(sc, st, 2, 4, 13, 14, h, 6)
    door(sc, L[0], L[1], mid(L, 3), 3, 5)
    if st.shape != 'cone':
        for a in (L[2] + 1.5, L[3] - 2.5):
            window(sc, 'L', L[1], a, h - 4, 1, 2)
        window(sc, 'R', R[1], mid(R, 1), h - 4, 1, 2)
    if st.age >= 2:
        banner(sc, 2.5, 4.5, h + 6, 6)


def bp_granary(sc, st, n):
    foundation(sc, n)
    L, R = hall(sc, st, 1.5, 1.5, 10, 7, 5, 3)
    door(sc, L[0], L[1], mid(L, 2), 2, 4)
    # σωροί σταριού μπροστά
    for (u, v) in ((2, 9), (5, 9.5), (8, 9)):
        sc.cone(u + 1, v + 1, 1.3, 0, 3, (PEN['o'], PEN['y']), sides=6)


def bp_storage_pit(sc, st, n):
    """Αποθήκη: ανοιχτό υπόστεγο με στύλους και εμπορεύματα."""
    foundation(sc, n, PEN['d'])
    sc.floor(1, 1, 7, 7, PEN['D'])
    crate(sc, 2, 2, 2, PEN['i'], PEN['I'])
    crate(sc, 4, 3, 1.5, PEN['D'], PEN['D'])
    for (u, v) in ((1, 1), (6.5, 1), (1, 6.5), (6.5, 6.5)):
        sc.box(u, v, u + 0.6, v + 0.6, 0, 5, PEN['D'], PEN['d'])
    crate(sc, 3, 5, 1.5, PEN['S'], PEN['o'])
    roof(sc, st, 0.5, 0.5, 7.5, 7.5, 5, 3)


def bp_barracks(sc, st, n):
    """Στρατώνας: ασπίδα στον τοίχο και ρατσέλι με δόρατα."""
    foundation(sc, n)
    L, R = hall(sc, st, 1, 1.5, 10.5, 8.5, 6, 4)
    door(sc, L[0], L[1], L[2] + 5.5, 2, 5)
    a = L[2] + 1.5
    sc.on_wall('L', L[1], a, a + 2, 2, 5, PEN['T'])
    sc.on_wall('L', L[1], a + 0.5, a + 1.5, 3, 4, PEN['y'])
    if st.age >= 3:
        for k in range(3):
            sc.box(2 + 2 * k, 10, 2.5 + 2 * k, 10.5, 0, 7, PEN['i'], PEN['d'])
        sc.box(1.5, 10, 7.5, 10.5, 3, 4, PEN['d'], PEN['d'], PEN['D'])


def bp_archery(sc, st, n):
    """Σκοπευτήριο: στόχος μπροστά από το κτίριο."""
    foundation(sc, n)
    L, R = hall(sc, st, 1, 1, 8, 8, 6, 4)
    door(sc, L[0], L[1], mid(L, 2), 2, 5)
    # ο στόχος, όρθιος πάνω σε δύο πόδια, στραμμένος προς τα ΝΑ
    sc.box(10, 3, 10.5, 3.5, 0, 3, PEN['d'], PEN['d'])
    sc.box(10, 7, 10.5, 7.5, 0, 3, PEN['d'], PEN['d'])
    sc.on_wall('R', 10.5, 3, 7.5, 3, 7, PEN['I'])
    sc.on_wall('R', 10.5, 4, 6.5, 4, 6, PEN['r'])
    sc.on_wall('R', 10.5, 5, 5.5, 4.5, 5.5, PEN['y'])


def bp_stable(sc, st, n):
    """Στάβλος: μάντρα με φράχτη μπροστά."""
    foundation(sc, n)
    L, R = hall(sc, st, 1, 1, 10, 6, 5, 4)
    door(sc, L[0], L[1], L[2] + 2, 3, 5)
    door(sc, L[0], L[1], L[2] + 6, 2, 4)
    # φράχτης γύρω από τη μάντρα
    for u in (1, 4, 7, 10.5):
        sc.box(u, 10.5, u + 0.5, 11, 0, 3, PEN['D'], PEN['d'])
    for v in (7, 9):
        sc.box(10.5, v, 11, v + 0.5, 0, 3, PEN['D'], PEN['d'])
    sc.on_wall('L', 11, 1, 11, 2, 3, PEN['D'])
    sc.on_wall('R', 11, 7, 11, 2, 3, PEN['d'])


def bp_market(sc, st, n):
    """Αγορά: ανοιχτοί πάγκοι με ριγέ τέντες, όχι κλειστοί τοίχοι."""
    foundation(sc, n, PEN['D'])
    L, R = hall(sc, st, 1, 1, 6, 6, 5, 3)
    door(sc, L[0], L[1], mid(L, 2), 2, 4)
    stalls = ((7, 2, PEN['y']), (7, 7, PEN['g']), (2, 7.5, PEN['r']))
    for u, v, goods in stalls:
        sc.box(u, v, u + 3.5, v + 3, 0, 2, PEN['d'], PEN['d'], goods)
        for a in range(0, 4):
            pen = PEN['r'] if a % 2 == 0 else PEN['I']
            sc.poly([(u + a, v - 0.5, 5), (u + a + 1, v - 0.5, 5),
                     (u + a + 1, v + 3.5, 3.5), (u + a, v + 3.5, 3.5)], pen)


def bp_dock(sc, st, n):
    """Λιμάνι: προβλήτα πάνω σε νερό, με αποθήκη και κατάρτι."""
    sc.floor(0, 0, 12, 12, PEN['c'])
    sc.floor(0, 0, 12, 4, PEN['o'])
    sc.box(0, 4, 12, 11, 0, 1, PEN['D'], PEN['d'], PEN['D'])
    for u in range(1, 12, 3):
        sc.box(u, 10.5, u + 0.6, 11.1, -2, 1, PEN['d'], PEN['K'])
    L, R = hall(sc, st, 1, 1, 7, 6, 5, 3)
    door(sc, L[0], L[1], mid(L, 2), 2, 4)
    # κατάρτι και πανί
    sc.box(9, 7, 9.6, 7.6, 1, 12, PEN['D'], PEN['d'])
    sc.on_wall('L', 7.6, 9.6, 12, 6, 11, PEN['I'])


def bp_farm(sc, st, n):
    """Χωράφι: αυλάκια σε όργωμα, με φράχτη. Δεν αλλάζει με την εποχή."""
    sc.floor(0, 0, 12, 12, PEN['d'])
    sc.floor(0.5, 0.5, 11.5, 11.5, PEN['D'])
    for u in range(1, 11, 2):
        sc.floor(u + 0.5, 1, u + 1.2, 11, PEN['g'])
    sc.box(11.5, 0, 12, 12, 0, 1, None, PEN['d'], PEN['D'])
    sc.box(0, 11.5, 12, 12, 0, 1, PEN['D'], None, PEN['D'])


def bp_tower(sc, st, n):
    """Πύργος σκοπιάς: ψηλός και στενός, ψηλώνει με την αναβάθμιση."""
    foundation(sc, n, inset=1)
    tall = 10 + 3 * (st.age - 2)
    if st.age == 2:
        # ξύλινη σκοπιά: τέσσερα πόδια και πλατφόρμα
        for (u, v) in ((2, 2), (5.5, 2), (2, 5.5), (5.5, 5.5)):
            sc.box(u, v, u + 0.6, v + 0.6, 0, tall, PEN['D'], PEN['d'])
        sc.box(1.5, 1.5, 6.5, 6.5, tall, tall + 3, PEN['D'], PEN['d'],
               PEN['o'])
        roof(sc, st, 1.5, 1.5, 6.5, 6.5, tall + 3, 3)
        return
    walls(sc, st, 2, 2, 6, 6, tall)
    sc.box(1.5, 1.5, 6.5, 6.5, tall, tall + 2, st.wall_light, st.wall_dark,
           st.wall_dark)
    for a in (1.5, 3.5, 5.5):
        sc.box(a, 5.5, a + 1, 6.5, tall + 2, tall + 3, st.wall_light,
               st.wall_dark, st.wall_light)
        sc.box(5.5, a, 6.5, a + 1, tall + 2, tall + 3, st.wall_light,
               st.wall_dark, st.wall_light)
    door(sc, 'L', 6, 3.5, 1.5, 4)
    window(sc, 'L', 6, 3.5, tall - 4, 1, 2)
    if st.age >= 4:
        window(sc, 'R', 6, 3.5, tall - 4, 1, 2)
        banner(sc, 2, 2, tall + 3, 5)


def bp_wall(sc, st, n):
    """Τείχος: ΕΝΑΣ κύβος που πιάνει όλο το πλακίδιο, ώστε δύο γειτονικοί να
    ενώνονται σε συνεχές τείχος προς ΟΠΟΙΑΔΗΠΟΤΕ από τις δύο διαγώνιες. Μία
    εικόνα αντί για δύο (ΒΑ-ΝΔ και ΒΔ-ΝΑ) ή για δεκαέξι γωνίες."""
    tall = 4 + 2 * (st.age - 2)
    if st.age == 2:
        # ξύλινη περίφραξη από κορμούς
        for (u, v) in ((0.5, 0.5), (2, 2), (0.5, 2.5), (2.5, 0.5), (1.5, 1.5)):
            sc.box(u, v, u + 1.2, v + 1.2, 0, tall + 1, PEN['D'], PEN['d'],
                   PEN['o'])
        return
    sc.box(0, 0, 4, 4, 0, tall, st.wall_light, st.wall_dark, st.wall_dark)
    sc.on_wall('L', 4, 0, 4, 0, 1, PEN['K'])
    sc.on_wall('R', 4, 0, 4, 0, 1, PEN['K'])
    for (u, v) in ((0, 0), (2.5, 0), (0, 2.5), (2.5, 2.5)):
        sc.box(u, v, u + 1.5, v + 1.5, tall, tall + 1.5, st.wall_light,
               st.wall_dark, st.wall_light)


def bp_temple(sc, st, n):
    """Ναός: κρηπίδωμα, περίστυλο και αέτωμα — το πιο επίσημο κτίριο."""
    foundation(sc, n)
    sc.box(0.5, 1, 11.5, 11, 0, 1, st.wall_light, st.wall_dark, st.wall_light)
    sc.box(1.5, 2, 10.5, 10, 1, 2, st.wall_light, st.wall_dark, st.wall_light)
    h = 8
    sc.box(3, 3.5, 9, 8.5, 2, h, PEN['K'], PEN['K'], None)
    columns(sc, st, 'L', 9.5, 2, 10.5, 2, h)
    columns(sc, st, 'R', 10.5, 2, 9.5, 2, h)
    sc.box(1.5, 2, 10.5, 10, h, h + 1, st.wall_light, st.wall_dark,
           st.wall_light)
    trim_band(sc, st, 1.5, 2, 10.5, 10, h + 1)
    if st.shape in ('gable', 'cone', 'pagoda'):
        sc.gable(1.5, 2, 10.5, 10, h + 1, 4, ramp_roof(st), st.wall_light,
                 axis='u', over=0.5)
    else:
        roof(sc, st, 1.5, 2, 10.5, 10, h + 1, 3)
    if st.age >= 4:
        banner(sc, 1.5, 2, h + 6, 5)


def bp_gov_center(sc, st, n):
    """Κυβερνείο: μεγάλο σώμα με στοά κιόνων μπροστά."""
    foundation(sc, n)
    L, R = hall(sc, st, 1.5, 1.5, 11, 10, 10, 5)
    # στοά μπροστά από τον αριστερό τοίχο
    sc.box(1.5, 10, 11, 14, 0, 1, st.wall_light, st.wall_dark, st.wall_light)
    columns(sc, st, 'L', 13.5, 2, 11, 1, 8)
    sc.box(1.5, 10, 11, 14, 8, 9, st.wall_light, st.wall_dark, st.wall_dark)
    door(sc, 'L', 10, 5, 2, 5)
    banner(sc, 2, 2, 17, 6)


def bp_academy(sc, st, n):
    """Ακαδημία: περίστυλη αυλή με τρούλο ή πύργο στη μέση."""
    foundation(sc, n)
    sc.box(1, 1, 15, 15, 0, 1, st.wall_light, st.wall_dark, st.wall_light)
    walls(sc, st, 2, 2, 7, 14, 9)
    walls(sc, st, 7, 2, 14, 7, 9)
    sc.box(7, 7, 14, 14, 0, 1, PEN['o'], PEN['o'], PEN['g'])
    columns(sc, st, 'L', 14, 7, 14, 1, 7)
    columns(sc, st, 'R', 14, 7, 14, 1, 7)
    sc.box(7, 7, 14, 14, 7, 8, st.wall_light, st.wall_dark, None)
    roof(sc, st, 2, 2, 7, 14, 9, 3, axis='v')
    roof(sc, st, 7, 2, 14, 7, 9, 3)
    sc.dome(5, 5, 2.5, 12, 4, (PEN['i'], PEN['I']))


def bp_siege_works(sc, st, n):
    """Πολιορκητικά: υπόστεγο, και ένας καταπέλτης απ' έξω."""
    foundation(sc, n, PEN['d'])
    L, R = hall(sc, st, 1, 1, 7, 9, 6, 3)
    door(sc, L[0], L[1], mid(L, 3), 3, 5)
    # καταπέλτης: πλαίσιο, ρόδες, βραχίονας
    sc.box(8.5, 5, 11, 9.5, 1, 2, PEN['D'], PEN['d'], PEN['D'])
    sc.box(8.5, 9.5, 9.5, 10, 0, 2, PEN['K'], PEN['K'])
    sc.box(10, 9.5, 11, 10, 0, 2, PEN['K'], PEN['K'])
    sc.poly([(9.5, 7, 2), (10, 7, 2), (10, 5, 9), (9.5, 5, 9)], PEN['d'])
    sc.box(9.5, 4.5, 10.5, 5.5, 8, 9, PEN['i'], PEN['i'], PEN['I'])


def bp_wonder(sc, st, n):
    """Θαύμα: το σχήμα του πολιτισμού, όχι κοινό κτίριο.

    Είναι το μόνο κτίριο που ΔΕΝ βγαίνει από το ίδιο σχέδιο για όλους: μια
    πυραμίδα και ένας Παρθενώνας δεν έχουν κοινή κάτοψη. Εδώ ο πολιτισμός
    διαλέγει σιλουέτα, όχι μόνο υλικό.
    """
    c = st.culture
    rw = ramp_wall(st)
    foundation(sc, n, PEN['D'] if c == 'egypt' else None)
    if c == 'egypt':
        sc.hip(1, 1, 15, 15, 0, 18, rw, ridge=0)
        sc.hip(7, 7, 9, 9, 15.4, 2.6, (PEN['o'], PEN['y']), ridge=0)
    elif c in ('babylon', 'persia'):
        for k in range(5):
            e = 1 + 1.4 * k
            sc.box(e, e, 16 - e, 16 - e, 4 * k, 4 * k + 4, st.wall_light,
                   st.wall_dark, st.wall_light)
            sc.on_wall('L', 16 - e, e, 16 - e, 4 * k + 3, 4 * k + 4,
                       st.wall_dark)
        sc.on_wall('L', 15, 7, 9, 0, 16, PEN['K'])   # η μεγάλη σκάλα
        if c == 'persia':
            sc.dome(8, 8, 2.5, 20, 4, ramp_roof(st))
    elif c == 'asia':
        for k in range(4):
            e = 2.5 + 1.2 * k
            z = 6 * k
            walls(sc, st, e, e, 16 - e, 16 - e, 4) if k == 0 else \
                sc.box(e, e, 16 - e, 16 - e, z, z + 4, st.wall_light,
                       st.wall_dark, None)
            sc.hip(e, e, 16 - e, 16 - e, z + 4, 2, ramp_roof(st), ridge=None,
                   over=1.5)
        sc.box(7.6, 7.6, 8.4, 8.4, 26, 31, PEN['y'], PEN['o'])
    elif c == 'celt':
        # κύκλος από μεγαλίθους γύρω από μια μεγάλη αχυρένια καλύβα
        sc.prism(8, 8, 4.5, 0, 6, rw)
        sc.cone(8, 8, 6, 6, 14, ramp_roof(st))
        import math
        for k in range(10):
            a = 2 * math.pi * k / 10 + 0.3
            u, v = 8 + 7 * math.cos(a), 8 + 7 * math.sin(a)
            if u + v < 15:
                continue                    # οι πίσω κρύβονται από την καλύβα
            sc.box(u - 0.5, v - 0.5, u + 0.5, v + 0.5, 0, 5, PEN['I'],
                   PEN['i'], PEN['I'])
    else:                                   # greek, rome, phoenicia
        sc.box(0.5, 0.5, 15.5, 15.5, 0, 2, st.wall_light, st.wall_dark,
               st.wall_light)
        sc.box(1.5, 1.5, 14.5, 14.5, 2, 3, st.wall_light, st.wall_dark,
               st.wall_light)
        h = 13
        sc.box(4, 4, 12, 12, 3, h, PEN['K'], PEN['K'], None)
        columns(sc, st, 'L', 14.5, 1.5, 14.5, 3, h)
        columns(sc, st, 'R', 14.5, 1.5, 14.5, 3, h)
        sc.box(1.5, 1.5, 14.5, 14.5, h, h + 2, st.wall_light, st.wall_dark,
               st.wall_light)
        trim_band(sc, st, 1.5, 1.5, 14.5, 14.5, h + 2)
        if c == 'phoenicia':
            sc.box(4, 4, 12, 12, h + 2, h + 4, st.wall_light, st.wall_dark,
                   st.wall_light)
            sc.box(6, 6, 10, 10, h + 4, h + 9, st.wall_light, st.wall_dark,
                   st.wall_light)
            sc.prism(8, 8, 1.2, h + 9, h + 12, (PEN['r'], PEN['y']))
        else:
            sc.gable(1.5, 1.5, 14.5, 14.5, h + 2, 6, ramp_roof(st),
                     st.wall_light, axis='u', over=0.5)
    if st.trim_pen is not None:
        banner(sc, 1, 1, 24, 6)


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
    ('farm',        'Χωράφι',         'M', [2],          bp_farm),
    ('tower',       'Πύργος',         'S', [2, 3, 4],    bp_tower),
    ('wall',        'Τείχος',         'T', [2, 3, 4],    bp_wall),
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


def render(key, culture, age, crop=True):
    _, _, size, _, blueprint = BY_KEY[key]
    sc, n = _scene(size)
    blueprint(sc, Style(culture, age), n)
    assert all(p is None for p in sc.img[0]), \
        '%s/%s/%d: ο καμβάς %s δεν φτάνει σε ύψος' % (key, culture, age, size)
    return trim_top(sc.img) if crop else sc.img


def footprint(key):
    return SIZES[BY_KEY[key][2]][0]


def variants(key):
    """-> [(εποχή, όνομα εποχής)] μόνο για τις εποχές που ζωγραφίζονται."""
    return [(a, AGE_NAMES[a]) for a in BY_KEY[key][3]]
