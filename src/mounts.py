"""Έφιππες και πολιορκητικές μονάδες, 12x16 pixels.

ΓΙΑΤΙ ΑΛΛΟ ΜΕΓΕΘΟΣ

Ένα άλογο από το πλάι είναι μακρύ: σώμα, λαιμός και κεφάλι δεν χωράνε σε 8
pixels χωρίς να γίνει σκύλος. Τα 12 pixels δίνουν 24 μονάδες οθόνης πλάτος σε
16 γραμμές — αναλογία 3:2, που είναι περίπου η σιλουέτα ενός αλόγου.

Το ύψος μένει 16 ώστε όλες οι μονάδες να πατάνε στην ΙΔΙΑ γραμμή εδάφους: ο
χάρτης τις τοποθετεί από τα πόδια, όχι από την κορυφή.

Ο ΑΝΑΒΑΤΗΣ ΞΑΝΑΧΡΗΣΙΜΟΠΟΙΕΙΤΑΙ

Ο κορμός και το κεφάλι είναι ακριβώς η πεζή φιγούρα (`figures.upper`),
κολλημένα ψηλότερα. Τα πόδια του δεν ζωγραφίζονται — τα κρύβει το ζώο. Έτσι
ένας ιππότης και ένας πεζός του ίδιου παίκτη έχουν το ίδιο κεφάλι και τον ίδιο
χιτώνα, που είναι αυτό που θέλει ένα παιχνίδι στρατηγικής.
"""
import figures
import gear
from gfx import PEN, blank, parse_art, recolour, shift, stamp

W, H = 12, 16
FACINGS = figures.FACINGS


def _a(text):
    return parse_art(text)


# ---------------------------------------------------------------- άλογο
# Όψη E: σώμα x=1..8, λαιμός ανεβαίνει δεξιά, κεφάλι x=9..11.
HORSE_E = """
          ------------
          ------------
          --------Dd--
          -------DDdd-
          ------DDdS--
          -----DDd----
          --DDDDDd----
          -dDDDDDDd---
          -dddddddd---
          -dKdddddK---
          --d--d-d----
          --d--d-d----
          --K--K-K----
          -KK-KK-KK---
          ------------
          -KKKKKKKKK--
          """

# Όψη S: το ζώο κοιτάει τον παίκτη — βραχύ, φαίνεται στήθος και κεφάλι.
HORSE_S = """
          ------------
          ------------
          ------------
          ----DDDD----
          ----DssD----
          ----dddd----
          ---DDDDDD---
          --DDDDDDDD--
          --dddddddd--
          --dKddddKd--
          ---d-dd-d---
          ---d-dd-d---
          ---K-KK-K---
          --KK-KK-KK--
          ------------
          --KKKKKKKK--
          """

HORSE_N = """
          ------------
          ------------
          ------------
          ----dddd----
          ----dddd----
          ----dddd----
          ---dddddd---
          --dddddddd--
          --dddddddd--
          --dddddddd--
          ---d-dd-d---
          ---d-dd-d---
          ---K-KK-K---
          --KK-KK-KK--
          ------------
          --KKKKKKKK--
          """

HORSE = {'s': HORSE_S, 'e': HORSE_E, 'n': HORSE_N}

# Καμήλα: ψηλότερη, με καμπούρα, σε άχυρο αντί για καφέ.
CAMEL_E = """
          ------------
          ------------
          ------oo----
          -----oooo-SS
          ------------
          ------oo-SS-
          --oooooooS--
          -ooooooooo--
          -ooooooooo--
          -oooooooo---
          --o--o-o----
          --o--o-o----
          --o--o-o----
          -oo-oo-oo---
          ------------
          -KKKKKKKKK--
          """

CAMEL = {'s': HORSE_S.replace('d', 'o'), 'e': CAMEL_E,
         'n': HORSE_N.replace('d', 'o')}

# Ελέφαντας: γεμίζει το κουτί, προβοσκίδα και χαυλιόδοντες μπροστά.
ELEPHANT_E = """
          ------------
          ------------
          ----IIIII---
          ---IIIIIii--
          --IIIiiiiii-
          --IIiiiiiiK-
          --IiiiiiiIIi
          --iiiiiiii-i
          --iiiiiiii-i
          --iKiiiiiK--
          ---i--ii-i--
          ---i--ii-i--
          ---i--ii-i--
          --KK-KKK-KK-
          ------------
          --KKKKKKKKK-
          """

ELEPHANT = {'s': ELEPHANT_E, 'e': ELEPHANT_E, 'n': ELEPHANT_E}


# -------------------------------------------------------------- μηχανές
CHARIOT_E = """
          ------------
          ------------
          ------------
          ---------dd-
          --------ddd-
          -------dd---
          ---dddddd---
          -KKdddddd---
          -KTTKdddd---
          -KTTKd-d----
          -KKKKd-d----
          -yKKy-K-K---
          -yKKy-KKK---
          --yy--------
          ------------
          -KKKKKKKKK--
          """

CATAPULT_E = """
          ------------
          -----i------
          -----i------
          -----i------
          ----dddd----
          ---dddddd---
          --dd----dd--
          --d------d--
          -ddddddddd--
          -d-------d--
          -ddddddddd--
          -yKy---yKy--
          -yKy---yKy--
          --y-----y---
          ------------
          -KKKKKKKKK--
          """

BALLISTA_E = """
          ------------
          ------------
          ------------
          ----i---i---
          -----i-i----
          ------i-----
          ---dddddd---
          --dddddddd--
          ---dddddd---
          ----d--d----
          -ddddddddd--
          -yKy---yKy--
          -yKy---yKy--
          --y-----y---
          ------------
          -KKKKKKKKK--
          """

MACHINES = {
    'chariot': CHARIOT_E,
    'catapult': CATAPULT_E,
    'ballista': BALLISTA_E,
}


# ------------------------------------------------------------- σύνθεση

# (όνομα, κατηγορία, ζώο, κάλυμμα, όπλο, βαφές ζώου)
MOUNTED = [
    ('scout',    'ιππικό',       HORSE,    None,    'spear', {}),
    ('cavalry',  'ιππικό',       HORSE,    'helm',  'spear', {}),
    ('knight',   'ιππικό',       HORSE,    'full',  'pike',  {'d': 'i'}),
    ('camel',    'ιππικό',       CAMEL,    'cap',   'sword', {}),
    ('elephant', 'ιππικό',       ELEPHANT, 'crest', 'pike',  {}),
]

SIEGE = [
    ('chariot',  'πολιορκητικά', 'chariot'),
    ('catapult', 'πολιορκητικά', 'catapult'),
    ('ballista', 'πολιορκητικά', 'ballista'),
]

# Πόσο ανεβοκατεβαίνει το ζώο στο τροχάδην. Δύο γραμμές, όχι μία: ένα άλογο
# που καλπάζει κουνιέται πιο πολύ από έναν άνθρωπο που περπατάει.
GAIT = (0, -1, 0, 1)

RIDER_X = 2       # ο 8άρης καμβάς του αναβάτη μέσα στον 12άρη
# Στο -4 το κεφάλι έβγαινε ΕΞΩ από τον καμβά και έμενε μόνο ο κορμός. Η
# `figures.upper` έχει κεφάλι στις γραμμές 2-4 και κορμό στις 5-9· με -2 το
# κεφάλι πάει στις 0-2 και ο κορμός στις 3-7, που ακουμπάει τη ράχη του ζώου
# στη γραμμή 6. Ο αναβάτης ΚΑΘΕΤΑΙ, δεν αιωρείται.
RIDER_Y = -2


def tint(img, mapping):
    if not mapping:
        return img
    m = {PEN[a]: PEN[b] for a, b in mapping.items()}
    return recolour(img, m)


def mounted(spec, facing, phase, attack=False):
    name, _, animal, head, weapon, paint = spec
    img = blank(W, H, None)
    beast = tint(_a(animal[facing]), paint)
    if GAIT[phase]:
        beast = shift(beast, 0, GAIT[phase])
    stamp(img, beast)

    # ο αναβάτης: μόνο κεφάλι και κορμός, τα πόδια τα κρύβει το ζώο
    up = figures.upper(facing, hair=head is None)
    if head:
        stamp(up, gear.art(gear.HEADGEAR, head))
    if weapon:
        stamp(up, gear.art(gear.WEAPONS, weapon, 1 if attack else 0))
    stamp(img, up, RIDER_X, RIDER_Y + (GAIT[phase] or 0))
    return img


def machine(spec, facing, phase):
    _, _, art = spec
    img = blank(W, H, None)
    base = _a(MACHINES[art])
    if facing == 'n':
        base = [list(reversed(r)) for r in base]
    stamp(img, base)
    return img
