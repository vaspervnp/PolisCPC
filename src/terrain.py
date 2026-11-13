"""Το έδαφος και οι πόροι του χάρτη.

ΔΥΟ ΔΙΑΦΟΡΕΤΙΚΑ ΠΡΑΓΜΑΤΑ

    έδαφος   ρόμβος 8x8, ΑΔΙΑΦΑΝΟ   16 τύποι, 4 bits του byte πλακιδίου
    πόροι    8x16 pixels, ΜΕ ΜΑΣΚΑ  16 τύποι, τα άλλα 4 bits

Το έδαφος είναι αδιαφανές επίτηδες, ΚΑΙ ΣΤΗΝ ΙΣΟΜΕΤΡΙΚΗ. Ο ρόμβος του
κόβεται σε όρια BYTE (`iso.DIAMOND`): γραμμές των 2, 2, 4, 4, 2, 2 bytes,
όλες στοιχισμένες. Οι γειτονικοί ρόμβοι κουμπώνουν χωρίς κενό και χωρίς
επικάλυψη, άρα δεν υπάρχει τίποτα να μασκαριστεί: κάθε γραμμή μπαίνει με
`LDI` από τον πίνακα `iso.SPANS`. 16 bytes ανά πλακίδιο — μισά από το
τετράγωνο 8x8 που υπήρχε πριν.

Οι πόροι έχουν μάσκα γιατί κάθονται ΠΑΝΩ στο έδαφος και είναι ψηλότεροι από
το πλακίδιο τους — ένα δέντρο πατάει σε ένα πλακίδιο αλλά σκεπάζει και το από
πάνω. Ζωγραφίζονται μία φορά όταν χτίζεται το φόντο, όχι κάθε καρέ.

ΤΟ ΠΛΑΚΙΔΙΟ ΕΙΝΑΙ ΡΟΜΒΟΣ 16x8 ΜΟΝΑΔΩΝ ΟΘΟΝΗΣ

8 pixels επί 2 μονάδες το καθένα = 16 μονάδες πλάτος, 8 γραμμές ύψος: η
αναλογία 2:1 της ισομετρικής του Age of Empires. Τα πλακίδια μπαίνουν σε
διάταξη ρόμβων: το (i, j) πάει στο x = (i-j)*4, y = (i+j)*4.

Οι υφές γράφονται ακόμα ως τετράγωνα 8x8 και κόβονται στον ρόμβο από το
`tile`. Οι ακτές ΔΕΝ είναι ASCII: είναι διαγώνιες, και βγαίνουν από τη
γεωμετρία (`shore`).

ΤΑ ΠΛΑΚΙΔΙΑ ΕΝΩΝΟΝΤΑΙ

Οι κουκκίδες μένουν ΜΑΚΡΙΑ από τις ακμές. Μια κουκκίδα στην ακμή γίνεται
γραμμή όταν το πλακίδιο επαναληφθεί δίπλα στον εαυτό του, και το μάτι πιάνει
αμέσως το πλέγμα.
"""
import iso
from gfx import PEN, blank, parse_art

TILE_W, TILE_H = iso.TW, iso.TH
RES_W, RES_H = 8, 16


def texture(text):
    rows = parse_art(text)
    assert len(rows) == TILE_H and all(len(r) == TILE_W for r in rows), \
        'υφή %dx%d' % (len(rows[0]), len(rows))
    assert all(p is not None for r in rows for p in r), \
        'η υφή είναι ΑΔΙΑΦΑΝΗ — χωρίς διάφανα'
    return rows


def tile(art):
    """Υφή 8x8 (ASCII) ή ήδη έτοιμη εικόνα -> πλακίδιο-ρόμβος. Ό,τι πέφτει
    έξω από τον ρόμβο των bytes γίνεται διάφανο."""
    if isinstance(art, str) and art.startswith('shore:'):
        img = shore(art[6:])
    else:
        img = texture(art) if isinstance(art, str) else art
    return iso.clip(img, iso.DIAMOND)


def _uv(x, y):
    """Το κέντρο του pixel σε συντεταγμένες κάτοψης του πλακιδίου, [0,4)."""
    X, Y = x + 0.5 - 4, y + 0.5
    return (X + Y) / 2, (Y - X) / 2


def shore(side):
    """Ακτή: ΣΤΕΡΙΑ με το νερό στη μεριά `side` (ne, se, sw, nw).

    Οι τέσσερις μεριές είναι οι τέσσερις ΔΙΑΓΩΝΙΕΣ ακμές του ρόμβου — στον
    ισομετρικό χάρτη δεν υπάρχει «πάνω» ακμή. Η ακτή ζωγραφίζεται στο
    πλακίδιο της στεριάς: μια λίμνη ορθογώνια σε (i, j) είναι ρόμβος στην
    οθόνη, και κάθε πλακίδιο στεριάς δίπλα της αγγίζει το νερό σε ΜΙΑ ακμή.
    """
    base = texture(GRASS)
    img = [list(r) for r in base]
    for y in range(TILE_H):
        for x in range(TILE_W):
            u, v = _uv(x, y)
            d = {'nw': u, 'se': 4 - u, 'ne': v, 'sw': 4 - v}[side]
            if d < 0.5:
                img[y][x] = PEN['I']
            elif d < 1.6:
                img[y][x] = PEN['S'] if (x * 3 + y) % 7 else PEN['o']
            elif d < 2.1:
                img[y][x] = PEN['S'] if (x + y) % 2 else PEN['n']
    return img


def res(text):
    rows = parse_art(text)
    assert len(rows) == RES_H and all(len(r) == RES_W for r in rows), \
        'πόρος %dx%d' % (len(rows[0]), len(rows))
    return rows


# ------------------------------------------------------------- έδαφος

GRASS = """
nnnnnnnn
nngnnnnn
nnnnnnnn
nnnnngnn
nnnnnnnn
nngnnnnn
nnnnnnnn
nnnnnnnn
"""

GRASS_TUFT = """
nnnnnnnn
nnngnnnn
nngggnnn
nnngnnnn
nnnnnnnn
nnnnnggn
nnnnnnnn
nnnnnnnn
"""

GRASS_FLOWER = """
nnnnnnnn
nngnnnnn
nnnnnrnn
nnnnngnn
nnnnnnnn
nnynnnnn
nngnnnnn
nnnnnnnn
"""

DIRT = """
oooooooo
oooDoooo
oooooooo
ooooooDo
oooooooo
oDoooooo
oooooooo
oooooooo
"""

DIRT_ROUGH = """
oooooooo
ooddoooo
oooooooo
ooooiooo
oooooddo
oooooooo
odoooooo
oooooooo
"""

SAND = """
SSSSSSSS
SSSoSSSS
SSSSSSSS
SSSSSSoS
SSSSSSSS
SSoSSSSS
SSSSSSSS
SSSSSSSS
"""

SAND_DUNE = """
SSSSSSSS
SSSooSSS
SSoSSoSS
SSSSSSSS
SSSSSSSS
SSSooSSS
SSSSSSSS
SSSSSSSS
"""

ROCK_FLOOR = """
iiiiiiii
iiKiiiii
iiiiiiii
iiiiiKii
iiiiiiii
iKiiiiii
iiiiiiii
iiiiiiii
"""

# Το νερό: pen 1 βαθύ, pen 15 ρηχό, pen 9 αφρός. Η ράμπα που ξεκλείδωσε η
# ανταλλαγή του μωβ με το κυανό.
WATER_DEEP = """
KKKKKKKK
KKcKKKKK
KKKKKKKK
KKKKKKcK
KKKKKKKK
KcKKKKKK
KKKKKKKK
KKKKKKKK
"""

WATER_SHALLOW = """
cccccccc
ccIccccc
cccccccc
ccccccIc
cccccccc
cIcccccc
cccccccc
cccccccc
"""

CLIFF = """
iiiiiiii
IIIiIIii
iKiiiiKi
iiiiiiii
iKiiiKii
iiiiiiii
KiiiKiii
iiiiiiii
"""

# Ήταν λαδί με χλωμές κουκκίδες, δηλαδή σχεδόν ίδιο με το `dirt`. Τώρα είναι
# ανοιχτό πατημένο χώμα με σκούρες πατημασιές: ξεχωρίζει με μια ματιά.
ROAD = """
DDDDDDDD
DoDDDoDD
DDDDDDDD
DDoDDDDo
DDDDDDDD
DoDDoDDD
DDDDDDDD
DDDDoDDD
"""

TERRAIN = [
    ('grass',         'γρασίδι',        GRASS,         True),
    ('grass_tuft',    'γρασίδι θάμνος', GRASS_TUFT,    True),
    ('grass_flower',  'γρασίδι άνθη',   GRASS_FLOWER,  True),
    ('dirt',          'χώμα',           DIRT,          True),
    ('dirt_rough',    'χώμα τραχύ',     DIRT_ROUGH,    True),
    ('sand',          'άμμος',          SAND,          True),
    ('sand_dune',     'αμμόλοφος',      SAND_DUNE,     True),
    ('rock_floor',    'βράχος',         ROCK_FLOOR,    True),
    ('water_deep',    'βαθύ νερό',      WATER_DEEP,    False),
    ('water_shallow', 'ρηχό νερό',      WATER_SHALLOW, False),
    ('shore_ne',      'ακτή, νερό ΒΑ',  'shore:ne',    True),
    ('shore_se',      'ακτή, νερό ΝΑ',  'shore:se',    True),
    ('shore_sw',      'ακτή, νερό ΝΔ',  'shore:sw',    True),
    ('shore_nw',      'ακτή, νερό ΒΔ',  'shore:nw',    True),
    ('cliff',         'γκρεμός',        CLIFF,         False),
    ('road',          'δρόμος',         ROAD,          True),
]
assert len(TERRAIN) == 16, 'τα 4 bits του πλακιδίου χωράνε ακριβώς 16'


# -------------------------------------------------------------- πόροι
# Βάση στη γραμμή 15, ύψος όσο θέλει το καθένα. Το '-' είναι διάφανο.

# ΤΟ ΦΥΛΛΩΜΑ ΕΙΝΑΙ ΦΩΤΕΙΝΟ ΠΡΑΣΙΝΟ, ΤΟ ΓΡΑΣΙΔΙ ΣΚΟΥΡΟ
#
# Η πρώτη γραφή τα είχε και τα δύο στο 'n' και τα δέντρα ΕΞΑΦΑΝΙΖΟΝΤΑΝ: έμενε
# μόνο ο κορμός να αιωρείται πάνω στο γρασίδι. Το φύλλωμα παίρνει 'g' με 'n'
# για σκιά στη μία πλευρά — η αντίθεση είναι το μόνο που το ξεχωρίζει, αφού
# και τα δύο είναι πράσινα.
TREE = """
--------
--gggg--
-gggggn-
-gggggn-
ggggggnn
-gggggn-
-ggggnn-
--ggnn--
---dd---
---dd---
---dd---
---dd---
---dd---
--dddd--
--dKKd--
-KKKKKK-
"""

TREE_PINE = """
---gg---
---gn---
--gggn--
--gggn--
-gggggn-
-ggggnn-
gggggggn
-ggggnn-
ggggggnn
---dd---
---dd---
---dd---
---dd---
---dd---
--dKKd--
-KKKKKK-
"""

TREE_PALM = """
--------
-g-gg-g-
gggnnggg
-gggggn-
--ggnn--
---Dn---
---dD---
---Dd---
---dD---
---Dd---
---dD---
---Dd---
---dD---
--dddd--
--dKKd--
-KKKKKK-
"""

STUMP = """
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
--DDDD--
-DDDDDD-
-dDDDDd-
-dddddd-
-dKddKd-
--KKKK--
"""

BERRY_BUSH = """
--------
--------
--------
--------
--------
---gg---
--gggn--
-gggggn-
grgggrgn
-ggrggnn
gggggrn-
-grgggn-
--ggnn--
---dd---
--dKKd--
-KKKKKK-
"""

BUSH_EMPTY = """
--------
--------
--------
--------
--------
---gg---
--gggn--
-gggggn-
gggggggn
-gggggn-
ggggggn-
-ggggnn-
--ggnn--
---dd---
--dKKd--
-KKKKKK-
"""

GOLD_ROCK = """
--------
--------
--------
--------
--------
---ii---
--iyii--
-iiyyii-
iiyiiyii
iiiyyiii
-iiiyii-
-iKiiKi-
iiiiiiii
iiiiiiii
-iiiiii-
--KKKK--
"""

STONE_ROCK = """
--------
--------
--------
--------
--------
---ii---
--iIii--
-iiiiii-
iiIiiiii
iiiiiIii
-iiiiii-
-iKiiKi-
iiiiiiii
iiiiiiii
-iiiiii-
--KKKK--
"""

ROCK_SMALL = """
--------
--------
--------
--------
--------
--------
--------
--------
--------
--------
---ii---
--iiii--
-iiKiii-
-iiiiii-
--KKKK--
--------
"""

# Ήταν κυανό — αόρατο πάνω στο ρηχό νερό, που είναι κι αυτό κυανό. Και η
# φάλαινα ήταν navy, δηλαδή αόρατη στο βαθύ. Οι πόροι του νερού κάθονται σε
# ΔΥΟ διαφορετικά πλακίδια· το μόνο που διαβάζεται και στα δύο είναι ασήμι με
# navy περίγραμμα.
FISH = """
--------
--------
--------
--------
--------
--------
--------
--------
---KK---
--KiiK--
-KiKii-i
KiiiiiiK
-Kiiii-i
--KiiK--
---KK---
--------
"""

GAZELLE = """
--------
--------
--------
------dd
-----ddd
------D-
--ddddd-
-ddddddd
-dddddd-
-dSddSd-
-d-dd-d-
-d-dd-d-
-K-KK-K-
KK-KK-KK
--------
-KKKKKK-
"""

FARM_PLOT = """
--------
--------
--------
--------
--------
--------
--DDDDDD
DgDgDgDg
DDDDDDDD
DgDgDgDg
DDDDDDDD
DgDgDgDg
DDDDDDDD
DgDgDgDg
DDDDDDDD
-KKKKKK-
"""

RUINS = """
--------
--------
--------
--------
--iI----
--ii--ii
--ii--iI
--ii--ii
--ii--ii
iiiiiiii
--------
--------
--iiii--
-iiiiii-
-iKiiKi-
--KKKK--
"""

REEDS = """
--------
-D------
-g--D---
-g--g---
-g--g-D-
-g--g-g-
-g--g-g-
-g--g-g-
-g--g-g-
-g--g-g-
-g--g-g-
-g--g-g-
-gggggg-
--gggg--
--nnnn--
--KKKK--
"""

WHALE = """
--------
--------
--------
--------
--------
--------
---I----
--I-I---
------ii
-----iii
--iiiiii
-iiiiiii
iiKiiiii
-iiiiii-
--iiii--
--KKKK--
"""

RESOURCES = [
    ('none',        'τίποτα',        None,        None,   0),
    ('tree',        'δέντρο',        TREE,        'ξύλο', 120),
    ('tree_pine',   'πεύκο',         TREE_PINE,   'ξύλο', 120),
    ('tree_palm',   'φοίνικας',      TREE_PALM,   'ξύλο', 100),
    ('stump',       'κούτσουρο',     STUMP,       None,   0),
    ('berry_bush',  'θάμνος μούρων', BERRY_BUSH,  'τροφή', 150),
    ('bush_empty',  'θάμνος άδειος', BUSH_EMPTY,  None,   0),
    ('gold_rock',   'χρυσός',        GOLD_ROCK,   'χρυσό', 200),
    ('stone_rock',  'πέτρα',         STONE_ROCK,  'πέτρα', 250),
    ('rock_small',  'πετρούλες',     ROCK_SMALL,  None,   0),
    ('fish',        'ψάρια',         FISH,        'τροφή', 200),
    ('whale',       'φάλαινα',       WHALE,       'τροφή', 450),
    ('gazelle',     'γαζέλα',        GAZELLE,     'τροφή', 100),
    ('reeds',       'καλάμια',       REEDS,       None,   0),
    ('farm_plot',   'χωράφι',        FARM_PLOT,   'τροφή', 40),
    ('ruins',       'ερείπια',       RUINS,       None,   0),
]
assert len(RESOURCES) == 16, 'τα άλλα 4 bits χωράνε ακριβώς 16'


# --------------------------------------------------------- εικονίδια HUD
#
# ΔΥΟ ΣΕΤ, ΕΝΑ ΜΕΓΕΘΟΣ
#
#     κατάσταση  8 μετρητές και ειδοποιήσεις — δείχνουν
#     εντολές   16 κουμπιά — πατιούνται
#
# Όλα 8x16 με μάσκα. Δύο ρόλοι, μία ρουτίνα.
#
# ΤΟ ΚΟΥΜΠΙ ΕΙΝΑΙ ΤΕΤΡΑΓΩΝΟ, ΤΟ ΣΧΕΔΙΟ ΟΧΙ
#
# Στο Mode 0 το pixel είναι διπλάσια φαρδύ. Ένα σχέδιο 8 στηλών x 16 γραμμών
# βγαίνει 16x16 ΜΟΝΑΔΕΣ ΟΘΟΝΗΣ — τετράγωνο. Άρα ζωγραφίζουμε σε πλέγμα όπου
# κάθε κελί είναι διπλάσια φαρδύ: ένα σχήμα που θέλεις στρογγυλό στην οθόνη
# το ζωγραφίζεις ΔΙΠΛΑΣΙΑ ΨΗΛΟ εδώ. Η έλλειψη 8x16 είναι κύκλος.
#
# Είναι ακριβώς το μέγεθος της μονάδας — ίδιο blit, ίδιο μήκος γραμμής.
#
# ΤΑ ΕΙΚΟΝΙΔΙΑ ΔΕΝ ΑΓΓΙΖΟΥΝ ΤΑ PENS 2 ΚΑΙ 3
#
# Είναι της ομάδας και τα ανταλλάσσει ο πίνακας παίκτη. Ένα εικονίδιο που τα
# χρησιμοποιεί αλλάζει χρώμα αν τύχει να περάσει από τη διαδρομή με πίνακα —
# και κάποτε θα τύχει. Κρατώντας τα έξω, το HUD ζωγραφίζεται με ΟΠΟΙΑΔΗΠΟΤΕ
# από τις δύο διαδρομές και βγαίνει πάντα ίδιο. (Το `pop` ζωγραφιζόταν στο
# χρώμα του παίκτη· δεν άξιζε την παγίδα.)
#
# ΤΟ ΦΟΝΤΟ ΔΕΝ ΕΙΝΑΙ ΕΛΕΥΘΕΡΗ ΕΠΙΛΟΓΗ
#
# Τα εικονίδια εντολών κάθονται σε ΚΟΥΜΠΙ, τα εικονίδια κατάστασης στον
# ΠΙΝΑΚΑ. Τα δύο δεν έχουν το ίδιο χρώμα, και ό,τι χρώμα έχουν δεν επιτρέπεται
# να το ξαναχρησιμοποιεί το εικονίδιο:
#
#     κουμπί   pen 11 (t, γαλάζιο)  — τα σώματα των εικονιδίων είναι πράσινα,
#                                     λευκά, κόκκινα, καφέ, χρυσά· κανένα
#                                     γαλάζιο, άρα όλα ξεχωρίζουν
#     πίνακας  pen 1  (K, navy)     — που είναι ΚΑΙ το χρώμα περιγράμματος
#
# Γι' αυτό το νόμισμα έχει καφέ περίγραμμα και όχι navy: με navy, πάνω στον
# navy πίνακα, το περίγραμμα εξαφανιζόταν και ο χρυσός γινόταν ένας λεκές
# χωρίς σχήμα. Στα εικονίδια κατάστασης το navy επιτρέπεται μόνο ΜΕΣΑ στο
# σχήμα (η σκιά της πέτρας, το θαυμαστικό του idle) — ποτέ στο περίγραμμα.
#
# ΟΛΑ ΕΧΟΥΝ ΜΑΣΚΑ
#
# Το κουμπί έχει δύο καταστάσεις, κανονική και πατημένη. Με μάσκα το ίδιο
# εικονίδιο κάθεται και στις δύο· αδιαφανές θα χρειαζόταν δεύτερο αντίγραφο.
# 128 bytes το ένα — φθηνότερο από 2x64 και χωρίς δεύτερο σετ να συντηρείς.

HUD_W, HUD_H = 8, 16

TEAM_PENS = {PEN['T'], PEN['t']}


def hud(text):
    """Εικονίδιο HUD — ένα μέγεθος για όλα, με μάσκα, χωρίς pens ομάδας."""
    rows = parse_art(text)
    assert len(rows) == HUD_H and all(len(r) == HUD_W for r in rows), \
        'εικονίδιο %dx%d, περίμενα %dx%d' % (len(rows[0]), len(rows),
                                             HUD_W, HUD_H)
    assert not any(p in TEAM_PENS for r in rows for p in r if p is not None), \
        'τα pens της ομάδας δεν μπαίνουν στο HUD'
    return rows


# ------------------------------------------------ κατάσταση
# ΗΤΑΝ 8x8 ΚΑΙ ΗΤΑΝ ΛΑΘΟΣ
#
# Οκτώ στήλες επί οκτώ γραμμές βγάζουν 16x8 μονάδες οθόνης: πλακουτσωτό.
# Το μήλο γινόταν φακή, το θαυμαστικό του `idle` γινόταν τρύπα, η φιγούρα του
# `pop` ήταν κεφάλι χωρίς σώμα. Δεν ήταν θέμα σχεδίου — δεν υπάρχει σχέδιο
# που να διαβάζεται όταν το μισό ύψος το τρώει η αναλογία.
#
# Τώρα είναι 8x16, όσο και τα κουμπιά: τετράγωνο στην οθόνη, μία ρουτίνα blit,
# ένα μήκος γραμμής. Η λωρίδα πόρων γίνεται 16 γραμμές από τις 56 του HUD και
# χωράει έξι μετρητές: εικονίδιο 8 + 4 ψηφία x 4 = 24 pixels, x6 = 144 από 160.

ICON_FOOD = """
--------
---nn---
--nn----
--rrrr--
-rrrrrr-
rrIrrrrr
rrrrrrrr
rrrrrrrr
rrrrrrrr
rrrrrrrr
rrrrrrrr
-rrrrrr-
-rrrrrr-
--rrrr--
---rr---
--------
"""

ICON_WOOD = """
--------
--DDDD--
-DDDDDD-
-DdDDdD-
-DDddDD-
-DDDDDD-
--DDDD--
-dddddd-
dddddddd
dDddddDd
dddddddd
dDddddDd
dddddddd
-dddddd-
--KKKK--
--------
"""

ICON_GOLD = """
---dd---
--dyyd--
-dyyyyd-
dyIIyyyd
dyIyyyyd
dyyyyyyd
dyyyyyyd
dyyyyyyd
dyyyyyyd
dyyyyyyd
dyyyyyyd
dyyyyyyd
-dyyyyd-
--dyyd--
---dd---
--------
"""

ICON_STONE = """
--------
--------
--------
---ii---
--iIii--
-iiiiii-
iiIiiiii
iiiiiiii
iiiiiiii
iiiiiiii
-iiiiii-
-iKiiKi-
--iiii--
--KKKK--
--------
--------
"""

# Ήταν στο χρώμα του παίκτη. Τώρα λευκός χιτώνας: το HUD δεν εξαρτάται από
# το ποιος παίζει.
ICON_POP = """
--------
--------
---ss---
---ss---
--IIII--
-sIIIIs-
-sIIIIs-
--IIII--
--IIII--
--d--d--
--d--d--
--d--d--
--K--K--
--------
--------
--------
"""

# Η εποχή: οβελίσκος με χρυσή κορυφή. Ανεβαίνει ένα σκαλί ανά εποχή.
ICON_AGE = """
--------
---yy---
--yyyy--
-yyyyyy-
--KIIK--
--KIIK--
--KIIK--
--KIIK--
--KIIK--
--KIIK--
--KIIK--
--KIIK--
-KIIIIK-
KIIIIIIK
KIIIIIIK
KKKKKKKK
"""

# Αδρανής χωρικός: θαυμαστικό. Το σκούρο είναι το σημάδι, όχι το φόντο.
ICON_IDLE = """
--------
--KKKK--
-KyyyyK-
KyyyyyyK
KyyKKyyK
KyyKKyyK
KyyKKyyK
KyyKKyyK
KyyKKyyK
KyyyyyyK
KyyyyyyK
KyyKKyyK
KyyKKyyK
KyyyyyyK
-KyyyyK-
--KKKK--
"""

# Δέχεσαι επίθεση. Τρίγωνο προειδοποίησης — αναβοσβήνει.
ICON_ALERT = """
---rr---
---rr---
--rrrr--
--rrrr--
--rKKr--
--rKKr--
-rrKKrr-
-rrKKrr-
-rrKKrr-
-rrKKrr-
rrrKKrrr
rrrrrrrr
rrrKKrrr
rrrKKrrr
rrrrrrrr
KKKKKKKK
"""

ICONS = [
    ('food',  'τροφή',            ICON_FOOD),
    ('wood',  'ξύλο',             ICON_WOOD),
    ('gold',  'χρυσό',            ICON_GOLD),
    ('stone', 'πέτρα',            ICON_STONE),
    ('pop',   'πληθυσμός',        ICON_POP),
    ('age',   'εποχή',            ICON_AGE),
    ('idle',  'αδρανής χωρικός',  ICON_IDLE),
    ('alert', 'δέχεσαι επίθεση',  ICON_ALERT),
]
assert len(ICONS) == 8


# ------------------------------------------------ εντολές 8x16
# Δεκαέξι κουμπιά: 4 bits, όπως και το έδαφος και οι πόροι. Σε πλέγμα 4x2
# πιάνουν 64x32 μονάδες οθόνης και αφήνουν τόπο για μίνι χάρτη και κάρτα.
#
# ΔΕΝ ΥΠΑΡΧΕΙ ΚΟΥΜΠΙ «ΧΤΙΣΕ ΣΠΙΤΙ» ή «ΒΓΑΛΕ ΣΠΑΘΟΦΟΡΟ»
#
# Αυτά τα κουμπιά δείχνουν ΤΟ ΙΔΙΟ ΤΟ ΚΤΙΡΙΟ ή ΤΗ ΜΟΝΑΔΑ, που τα έχουμε ήδη
# ζωγραφίσει. Το `build` ανοίγει το μενού· τα περιεχόμενά του είναι τα sprites
# των κτιρίων. Δεκαέξι εικονίδια που θα διπλασίαζαν ό,τι υπάρχει ήδη θα ήταν
# δύο σετ να συντηρείς και ένα να ξεχάσεις να ενημερώσεις.

CMD_MOVE = """
--------
KK------
KgK-----
KggK----
KgggK---
KggggK--
KgggggK-
KggggggK
KgggggK-
KggggK--
KgggK---
KggK----
KgK-----
KK------
--------
--------
"""

# ΟΧΙ ΔΙΑΣΤΑΥΡΩΜΕΝΑ ΣΠΑΘΙΑ
#
# Ήταν, και έβγαιναν ένα Χ. Το `cancel` είναι ΚΙ ΑΥΤΟ ένα Χ: δύο κουμπιά με
# το ίδιο περίγραμμα, που τα χώριζε μόνο το χρώμα — και σε κουμπί 16x16
# μονάδων το σχήμα το πιάνεις πριν το χρώμα. Ένα όρθιο σπαθί δεν μοιάζει με
# τίποτε άλλο στο σετ.
CMD_ATTACK = """
---I----
---Ii---
--IIii--
--IIii--
--IIii--
--IIii--
--IIii--
--IIii--
--IIii--
--IIii--
-yyyyyy-
-yyyyyy-
---dd---
---dd---
---dd---
---yy---
"""

CMD_STOP = """
--------
--KKKK--
-KrrrrK-
KrrrrrrK
KrrrrrrK
KrrrrrrK
KrrrrrrK
KIIIIIIK
KIIIIIIK
KrrrrrrK
KrrrrrrK
KrrrrrrK
-KrrrrK-
--KKKK--
--------
--------
"""

CMD_STAND = """
--------
-KKKKKK-
KiIIIIiK
KiIiiIiK
KiIiiIiK
KiIIIIiK
KiiiiiiK
KiiiiiiK
KiiiiiiK
-KiiiiK-
-KiiiiK-
--KiiK--
--KiiK--
---KK---
--------
--------
"""

CMD_PATROL = """
--------
--------
----g---
----gg--
ggggggg-
----gg--
----g---
--------
--------
---g----
--gg----
-ggggggg
--gg----
---g----
--------
--------
"""

CMD_BUILD = """
--------
-KKKKKK-
KiIIIIiK
KiiiiiiK
-KKiiKK-
---dd---
---dD---
---dD---
---dD---
---dD---
---dD---
---dD---
---dD---
---dD---
---KK---
--------
"""

# Σφυρί ΠΑΝΩ σε τοίχο: ξεχωρίζει από το σκέτο σφυρί του `build` με μια ματιά,
# που είναι το μόνο που έχεις όταν τα κουμπιά είναι 16x16 μονάδες.
CMD_REPAIR = """
--------
-KKKKKK-
KIIIIIIK
KiiiiiiK
-KKiiKK-
---dd---
---dd---
---KK---
--------
KKKKKKKK
KDDKDDDK
KDDKDDDK
KKKKKKKK
KDDDKDDK
KDDDKDDK
KKKKKKKK
"""

CMD_GARRISON = """
---gg---
---gg---
---gg---
---gg---
-gggggg-
--gggg--
---gg---
--------
-KKKKKK-
KiiiiiiK
KiKKKKiK
KiKddKiK
KiKddKiK
KiKddKiK
KiKddKiK
KKKKKKKK
"""

CMD_EJECT = """
---gg---
--gggg--
-gggggg-
---gg---
---gg---
---gg---
---gg---
--------
-KKKKKK-
KiiiiiiK
KiKKKKiK
KiKddKiK
KiKddKiK
KiKddKiK
KiKddKiK
KKKKKKKK
"""

CMD_HEAL = """
--------
--KKKK--
-KIIIIK-
-KI--IK-
-KI--IK-
-KIIIIK-
--KIIK--
KKKIIKKK
KIIIIIIK
KKKIIKKK
---II---
---II---
---II---
---II---
---KK---
--------
"""

# Μισός μπλε, μισός κόκκινος: άλλαξε πλευρά. Το μπλε είναι το κυανό pen 15,
# ΟΧΙ της ομάδας — δες τον κανόνα παραπάνω.
CMD_CONVERT = """
--yyyy--
-y----y-
--------
---ss---
---ss---
--ccrr--
-cccrrr-
-cccrrr-
-cccrrr-
-cccrrr-
--ccrr--
--c--r--
--c--r--
--c--r--
--K--K--
--------
"""

CMD_RESEARCH = """
--------
-dddddd-
dDDDDDDd
-SSSSSS-
-SKKKKS-
-SSSSSS-
-SKKKKS-
-SSSSSS-
-SKKKKS-
-SSSSSS-
-SKKKKS-
-SSSSSS-
dDDDDDDd
-dddddd-
--------
--------
"""

CMD_AGE_UP = """
---yy---
--yyyy--
-yy--yy-
yy----yy
--------
--yyyy--
-yIIIIy-
-yIIIIy-
--KIIK--
--KIIK--
--KIIK--
--KIIK--
--KIIK--
-KIIIIK-
KIIIIIIK
KKKKKKKK
"""

CMD_RALLY = """
-DKKKKK-
-DrrrrrK
-DrrrrrK
-DrrrrK-
-DrrrK--
-DrrK---
-DK-----
-D------
-D------
-D------
-D------
-D------
-D------
-D------
-D------
DDDD----
"""

CMD_DELETE = """
--------
--KKKK--
-KIIIIK-
KIIIIIIK
KIKIIKIK
KIKIIKIK
KIIIIIIK
KIIKKIIK
-KIIIIK-
--KIIK--
-KIIIIK-
-KIKIKI-
-KKKKKK-
--------
--------
--------
"""

CMD_CANCEL = """
rr----rr
rr----rr
-rr--rr-
-rr--rr-
--rrrr--
--rrrr--
---rr---
---rr---
--rrrr--
--rrrr--
-rr--rr-
-rr--rr-
rr----rr
rr----rr
--------
--------
"""

COMMANDS = [
    ('move',     'κίνηση',            CMD_MOVE,     'μονάδα'),
    ('attack',   'επίθεση',           CMD_ATTACK,   'μονάδα'),
    ('stop',     'στάση',             CMD_STOP,     'μονάδα'),
    ('stand',    'κράτα τη θέση',     CMD_STAND,    'μονάδα'),
    ('patrol',   'περιπολία',         CMD_PATROL,   'μονάδα'),
    ('build',    'χτίσε',             CMD_BUILD,    'χωρικός'),
    ('repair',   'επισκευή',          CMD_REPAIR,   'χωρικός'),
    ('garrison', 'μπες μέσα',         CMD_GARRISON, 'μονάδα'),
    ('eject',    'βγάλε τους έξω',    CMD_EJECT,    'κτίριο'),
    ('heal',     'θεραπεία',          CMD_HEAL,     'ιερέας'),
    ('convert',  'προσηλύτιση',       CMD_CONVERT,  'ιερέας'),
    ('research', 'τεχνολογία',        CMD_RESEARCH, 'κτίριο'),
    ('age_up',   'επόμενη εποχή',     CMD_AGE_UP,   'κέντρο πόλης'),
    ('rally',    'σημείο συγκέντρωσης', CMD_RALLY,  'κτίριο'),
    ('delete',   'γκρέμισμα',         CMD_DELETE,   'μονάδα/κτίριο'),
    ('cancel',   'άκυρο',             CMD_CANCEL,   'παντού'),
]
assert len(COMMANDS) == 16, 'τέσσερα bits, όπως το έδαφος και οι πόροι'
