"""Το ιππικό σε 8x16 pixels (2026-11-17): για τη θέση 3 της C5, που τη
μοιράζεται με τον οπλίτη (src/make_edges.py).

Το src/mounts.py ζωγραφίζει τα έφιππα σε 12x16, που η μηχανή δεν τα
ζωγραφίζει (ο blitter, τα περιγράμματα και ο πίνακας της ομάδας 1 είναι για
8x16). Εδώ το άλογο είναι ΜΑΖΕΜΕΝΟ: ο αναβάτης κάθεται ψηλά (κεφάλι στις
γραμμές 0-2, κορμός 3-7, ο ίδιος της `figures.upper`, με κάλυμμα και
δόρυ), και το ζώο πιάνει τις γραμμές 7-14, με τη σκιά στη 15 — τα πόδια
πατάνε στην ίδια γραμμή με τους πεζούς. Στην όψη E το κεφάλι του αλόγου
βγαίνει δεξιά από τον αναβάτη (x 6-7), στην S μπροστά του, στην N η ουρά.

21 καρέ, με τη σειρά του src/units.py: βάδισμα S E N x 4, επίθεση S E N x
2, θάνατος x 3.
"""
import figures
import gear
from gfx import SpriteSet, blank, parse_art, shift, stamp

W, H = 8, 16
FACINGS = figures.FACINGS
RIDER_Y = -2                    # ο αναβάτης 2 γραμμές ψηλότερα από τον πεζό

# Το ζώο, γραμμές 6-15, ανά όψη και ανά στάση των ποδιών (0 ανοιχτά, 1
# μαζεμένα).
BODY = {
    'e': """
         ------Dd
         -----DDS
         .DDDDDd.
         dDDDDDd.
         .dddddd.
         """,
    's': """
         ---DD---
         --DddD--
         --DSSD--
         .DdDDdD.
         .DDDDDD.
         """,
    'n': """
         --------
         --------
         ..DDDD..
         .DDDDDD.
         .DDDDDD.
         """,
}
LEGS = {
    'e': ("""
         .d...d..
         d.d.d.d.
         K..KK..K
         KK.....K
         """, """
         ..d.d...
         ..d.d...
         ..KdKd..
         .KK.KK..
         """),
    's': ("""
         .d....d.
         .d....d.
         .K....K.
         KK....KK
         """, """
         ..d..d..
         ..d..d..
         ..K..K..
         .KK..KK.
         """),
    'n': ("""
         .d.dd.d.
         .d.dd.d.
         .K....K.
         KK....KK
         """, """
         ..ddd...
         ..dKd...
         ..K..K..
         .KK..KK.
         """),
}
SHADOW = '.KKKKKK.'
GAIT = (0, -1, 0, -1)           # το σώμα (ζώο και αναβάτης) στο τροχάδην

DIE = ["""
       --------
       --------
       --------
       --------
       --------
       --------
       ---ss---
       ..TTTT..
       .sTTTTs.
       .DDDDDDd
       dDDDDDD.
       .dddddd.
       .d.d.d..
       .K.K.K..
       KK.KK.K.
       .KKKKKK.
       """, """
       --------
       --------
       --------
       --------
       --------
       --------
       --------
       --------
       --------
       -ss-----
       .TTTT-Dd
       .DDDDDDd
       dDDDDDD.
       .dddddd.
       .KdKdK..
       KKKKKKKK
       """, """
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
       --------
       -ss-----
       TTTDDDDd
       dDDDDDDS
       KdddddKK
       KKKKKKKK
       """]


def rider(facing, attack):
    up = figures.upper(facing, hair=False)
    stamp(up, gear.art(gear.HEADGEAR, 'helm'))
    a = gear.art(gear.WEAPONS, 'spear', 1 if attack else 0)
    if facing == 'n':
        a = [list(reversed(r)) for r in a]
    stamp(up, a)
    return shift(up, 0, RIDER_Y)


def horse(facing, phase, attack=False):
    img = blank(W, H, None)
    stamp(img, parse_art(LEGS[facing][phase & 1]), 0, 11)
    beast = blank(W, H, None)
    stamp(beast, parse_art(BODY[facing]), 0, 6)
    stamp(beast, rider(facing, attack))
    if GAIT[phase]:
        beast = shift(beast, 0, GAIT[phase])
    stamp(img, beast)
    stamp(img, parse_art(SHADOW), 0, 15)
    return img


def build(name='cavalry'):
    s = SpriteSet(name, W, H, note='ιππικό (8x16)')
    for f in FACINGS:
        for ph in range(4):
            s.add(horse(f, ph), '%s_walk_%s%d' % (name, f, ph), 'walk_' + f)
    for f in FACINGS:
        for ph in range(2):
            s.add(horse(f, 0, attack=ph == 1), '%s_atk_%s%d' % (name, f, ph),
                  'atk_' + f)
    for i, art in enumerate(DIE):
        s.add(parse_art(art), '%s_die%d' % (name, i), 'die')
    return s
