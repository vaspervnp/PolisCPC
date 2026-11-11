"""Ο κατάλογος των μονάδων και οι κινήσεις τους.

ΤΙ ΕΧΕΙ ΚΑΘΕ ΜΟΝΑΔΑ

    walk    4 καρέ x 3 όψεις  = 12
    attack  2 καρέ x 3 όψεις  =  6
    die     3 καρέ (μία όψη)  =  3
                               ---
                                21 καρέ

Η όψη W ΔΕΝ αποθηκεύεται: είναι καθρέφτισμα της E. Στο CPC το καθρέφτισμα σε
χρόνο εκτέλεσης θέλει έναν πίνακα 256 bytes που ανταλλάσσει τα δύο pixels μέσα
στο byte, και αντιστροφή της σειράς των bytes της γραμμής. Αν προτιμάς κύκλους
από μνήμη, φτιάξε τα W στο build με το `--mirror`.

Το `die` έχει μία μόνο όψη επειδή ένα σώμα στο έδαφος δεν έχει κατεύθυνση που
να αξίζει 3x τη μνήμη.

ΤΟ ΧΡΩΜΑ ΤΗΣ ΟΜΑΔΑΣ ΕΙΝΑΙ ΠΑΝΤΑ Ο ΧΙΤΩΝΑΣ

Όλες οι μονάδες, και οι χωρικοί, φοράνε T/t στον κορμό. Σε παιχνίδι
στρατηγικής το πρώτο που πρέπει να διαβάσεις είναι ΤΙΝΟΣ είναι η μονάδα, και
μετά τι είναι. Ό,τι αλλάζει ανά μονάδα είναι τα υπόλοιπα: πόδια, κράνος, όπλο.
"""
import figures
import gear
from gfx import SpriteSet, blank, parse_art, recolour, stamp, PEN

FACINGS = figures.FACINGS
W, H = figures.W, figures.H

# (όνομα, κατηγορία, κάλυμμα, όπλο, ασπίδα, βαφές)
# Οι βαφές αλλάζουν χαρακτήρες της ΒΑΣΙΚΗΣ φιγούρας: 'd' είναι τα πόδια/βρακί.
FOOT = [
    ('villager_m', 'χωρικοί',  'cap',   'tool',  None,    {}),
    ('villager_f', 'χωρικοί',  'scarf', 'tool',  None,    {'d': 'o'}),
    ('clubman',    'πεζικό',   None,    'club',  None,    {}),
    ('axeman',     'πεζικό',   'helm',  'axe',   'small', {}),
    ('swordsman',  'πεζικό',   'helm',  'sword', 'small', {'d': 'i'}),
    ('spearman',   'πεζικό',   'helm',  'spear', 'big',   {}),
    ('hoplite',    'πεζικό',   'crest', 'pike',  'round', {'d': 'i'}),
    ('archer',     'βαλλιστές', None,   'bow',   None,    {'d': 'n'}),
    ('slinger',    'βαλλιστές', 'cap',  'sling', None,    {'d': 'o'}),
    ('priest',     'ειδικοί',  'hood',  'staff', None,    {'d': 'I'}),
]


def tint(img, mapping):
    """Αλλάζει χαρακτήρες παλέτας σε ολόκληρη εικόνα."""
    if not mapping:
        return img
    m = {PEN[a]: PEN[b] for a, b in mapping.items()}
    return recolour(img, m)


def dress(facing, phase, spec, attack_phase=None):
    """Φιγούρα + κάλυμμα + όπλο + ασπίδα, στη σωστή σειρά στρώσεων."""
    _, _, head, weapon, shield, paint = spec
    hair = head is None
    img = tint(figures.walking(facing, phase, hair=hair), paint)

    # Η ασπίδα πρώτη: είναι στο πίσω χέρι, κάτω από το σώμα.
    if shield:
        a = gear.art(gear.SHIELDS, shield)
        if facing == 'n':                 # από πίσω η ασπίδα φαίνεται δεξιά
            a = [list(reversed(r)) for r in a]
        img = stamp(img, a)
    if head:
        img = stamp(img, gear.art(gear.HEADGEAR, head))
    if weapon:
        ph = 1 if attack_phase else 0
        a = gear.art(gear.WEAPONS, weapon, ph)
        if facing == 'n':                 # πίσω όψη: το όπλο στο άλλο χέρι
            a = [list(reversed(r)) for r in a]
        img = stamp(img, a)
    return img


# ----------------------------------------------------------------- θάνατος
# Τρία καρέ: λυγίζει, πέφτει στα γόνατα, μένει κάτω. Το σώμα χαμηλώνει και
# πλαταίνει — σε 8 pixels αυτό είναι όλη η αφήγηση που χωράει.
DIE = ["""
       --------
       --------
       --------
       ---ss---
       ---ss---
       ..TTTT..
       .sTTTTs.
       .sTTTT..
       ..KttK..
       ..d..d..
       ..d..d..
       ..K..K..
       .KK..KK.
       --------
       --------
       .KKKKKK.
       """, """
       --------
       --------
       --------
       --------
       --------
       --------
       ---ss---
       ..TTTT..
       .sTTTTs.
       ..TTTT..
       ..KttK..
       ..dd.d..
       ..KK.K..
       .KKK.KK.
       --------
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
       --------
       --------
       -ss-----
       .TTTTd..
       .TTTTdd.
       .KttKKK.
       KKKKKKKK
       """]


def die_frames(spec):
    _, _, head, _, _, paint = spec
    out = []
    for i, art in enumerate(DIE):
        img = tint(parse_art(art), paint)
        if head and i < 2:               # το κράνος πέφτει στο τελευταίο καρέ
            hg = gear.art(gear.HEADGEAR, head)
            img = stamp(img, [r[:] for r in hg[:]], 0, 1 + i * 4)
        out.append(img)
    return out


# ------------------------------------------------------------------- σετ

def build(spec):
    name = spec[0]
    s = SpriteSet(name, W, H, note=spec[1])
    for f in FACINGS:
        for ph in range(4):
            s.add(dress(f, ph, spec), '%s_walk_%s%d' % (name, f, ph),
                  'walk_' + f)
    for f in FACINGS:
        for ph in range(2):
            s.add(dress(f, 0 if ph == 0 else 1, spec, attack_phase=ph),
                  '%s_atk_%s%d' % (name, f, ph), 'atk_' + f)
    for i, img in enumerate(die_frames(spec)):
        s.add(img, '%s_die%d' % (name, i), 'die')
    return s


def all_sets():
    return [build(sp) for sp in FOOT]
