"""Η τράπεζα C6 και τα κτίρια του παιχνιδιού (M7).

    python3 src/make_bank6.py

-> data/bank6.bin   ό,τι μπαίνει στην C6 στο #4000: οι πόροι (resources.bin,
                    15 x 128, στοιχισμένοι), τα πλακίδια εδάφους στο #4800
                    (terrain.bin, μία σελίδα), στο #4900 η ΣΕΛΙΔΑ ΜΑΣΚΑΣ των
                    κτιρίων (byte δεδομένων -> μάσκα: το pen 0 είναι το
                    διάφανο, άρα η μάσκα βγαίνει από τα δεδομένα), και από
                    το IMG0 (#4A80) οι εικόνες των κτιρίων της αρχικής
                    εποχής ΧΩΡΙΣ μάσκα (ένα byte ανά 2 pixels, γραμμή προς
                    γραμμή — οι μισές από το mask,data του M7). Στο τέλος οι
                    κόκκινοι μεταγλωττισμένοι (make_compiled.py).
-> data/age3.bin    οι εικόνες της Εποχής του Χαλκού (M9), όλων των τύπων,
                    από το IMG0: το AGE3.BIN της δισκέτας, που το φορτώνει
                    το game/disk.asm στην C6 στο IMG0 - 128 (η κεφαλίδα
                    AMSDOS πέφτει στο #4A00-#4A7F).
-> data/age3.asm    ανά τύπο το ύψος και η εικόνα του στην Εποχή του Χαλκού
                    (game/bank7.asm, age_up)
-> data/bld.asm     ο πίνακας των τύπων κτιρίων για τον Z80

ΕΝΑΣ ΟΡΙΣΜΟΣ: ο πίνακας TYPES εδώ είναι και των ελέγχων (tests/m7_check.py),
και η εικόνα κάθε κτιρίου (`image`) είναι η ίδια που ζωγραφίζει η αναφορά
των ελέγχων.

ΤΟ ΔΕΝΤΡΟ (M7). Κάθε τύπος έχει ελάχιστη εποχή — την πρώτη στην οποία
υπάρχει εικόνα του (buildings.json: «κτίριο που δεν υπάρχει ακόμα σε μια
εποχή δεν έχει καθόλου εικόνα») — και, προαιρετικά, ένα κτίριο που πρέπει
να έχει ήδη ο παίκτης (ολοκληρωμένο). Το παιχνίδι αρχίζει στην Εποχή
Εργαλείων (2), όπως το mockup.
"""
import json
import os

import buildings as B
import gfx

DATA = os.path.join(gfx.OUT, 'data')
ORG = 0x4000
MASK_PG = 0x4900                # η σελίδα μάσκας των κτιρίων
IMG0 = 0x4A80                   # οι εικόνες (και πριν, 128 bytes κεφαλίδα)
CULTURE = 'greek'               # των εικόνων της εκκίνησης και των ελέγχων
START_AGE = 2
# Οι πολιτισμοί του μενού (M12), με το γράμμα των αρχείων τους στη δισκέτα
# (AGE3<γράμμα>.BIN, AGE4<γράμμα>.BIN). Στις δύο πρώτες εποχές όλοι μοιάζουν
# (graphics.md): ο πολιτισμός φαίνεται από τη Χαλκού.
CULTURES = [('egypt', 'E'), ('greek', 'G'), ('babylon', 'B'), ('asia', 'A'),
            ('rome', 'R'), ('persia', 'P'), ('phoenicia', 'F'), ('celt', 'K')]
# Τα αρχεία των εποχών (χωρίς κεφαλίδα, src/dsk.py) πέφτουν στο AGE_AT της
# C6: πρώτα ο πίνακας (ανά τύπο: ύψος, εικόνα dw, άλλαξε), μετά οι εικόνες,
# ως το FOG (game/fog.asm).
AGE_AT = 0x4A00
FOG = 0x5F80
INFO = {b['key']: b for b in json.load(open(os.path.join(
    gfx.OUT, 'buildings.json')))['buildings']}

UNIT_SETS = ['villager_m', 'swordsman', 'archer', 'villager_carry',
             'hoplite']                                 # = U_SET

# (κλειδί, πλήκτρο, προαπαιτούμενο, κόστος (τροφή, ξύλο, χρυσό, πέτρα),
#  πόντοι ανέγερσης, μονάδα που βγάζει)
TYPES = [
    ('town_center', 'C', None,      (0, 200, 0, 0),  60, 'villager_m'),
    ('house',       'H', None,      (0, 30, 0, 0),   10, None),
    ('barracks',    'B', None,      (0, 125, 0, 0),  30, 'swordsman'),
    ('granary',     'G', None,      (0, 120, 0, 0),  25, None),
    ('storage_pit', 'S', None,      (0, 120, 0, 0),  25, None),
    ('market',      'M', 'granary', (0, 150, 0, 0),  30, None),
    ('archery',     'R', 'barracks', (0, 150, 0, 0), 30, 'archer'),
    ('stable',      'L', 'barracks', (0, 150, 0, 0), 30, None),
    ('farm',        'F', 'market',  (0, 75, 0, 0),   15, None),
    ('tower',       'W', 'granary', (0, 0, 0, 150),  30, None),
    # Εποχή του Χαλκού (M9): η ακαδημία βγάζει οπλίτες (το σετ τους από τη
    # δισκέτα, στη θέση 3 της C5)· ο ναός και το κυβερνείο τίποτα
    ('temple',      'N', None,      (0, 200, 0, 0),  40, None),
    ('gov_center',  'K', 'market',  (0, 200, 0, 0),  50, None),
    ('academy',     'D', 'stable',  (0, 200, 0, 0),  50, 'hoplite'),
]
KEYS = [t[0] for t in TYPES]

# Ο πόρος 13 («καλάμια», κανένα στον χάρτη) γίνεται το ΠΛΑΚΙΔΙΟ ΚΤΙΡΙΟΥ: το
# γράφει ο Z80 στην κάτοψη κάθε κτιρίου, είναι εμπόδιο (src/make_map.py) και
# δεν έχει sprite (διάφανο εδώ).
BLD_RES = 13

# Ο πίνακας πλήκτρων του CPC: χαρακτήρας -> (γραμμή, bit).
MATRIX = {'C': (7, 6), 'H': (5, 4), 'B': (6, 6), 'G': (6, 4), 'S': (7, 4),
          'M': (4, 6), 'R': (6, 2), 'L': (4, 4), 'F': (6, 5), 'W': (7, 3),
          'T': (6, 3), 'ESC': (8, 2), 'N': (5, 6), 'K': (4, 5), 'D': (7, 5),
          'U': (5, 2)}
TRAIN_KEY = 'T'

# Οι μονάδες που βγαίνουν: κόστος και καρέ (των 25 Hz) εκπαίδευσης.
UNITS = {'villager_m': ((50, 0, 0, 0), 200),
         'swordsman':  ((35, 0, 15, 0), 250),
         'archer':     ((40, 20, 0, 0), 250),
         'hoplite':    ((60, 0, 40, 0), 250)}  # (ένα byte: ως 255 — ήταν 300, M12)
assert all(t <= 255 for _, t in UNITS.values()), 'καρέ εκπαίδευσης: ένα byte'


def min_age(key):
    return min(INFO[key]['drawn_at_ages'])


def image(key, age=START_AGE):
    """Η εικόνα του κτιρίου στην εποχή: η τελευταία που έχει ζωγραφιστεί ως
    τότε."""
    return B.render(key, CULTURE, B.covers(INFO[key]['drawn_at_ages'])[age])


def footprint(key):
    return B.footprint(key)


def mask_page():
    """byte δεδομένων -> μάσκα: τα bits του pixel αναμμένα όπου είναι pen 0."""
    import cpcimg
    out = bytearray(256)
    for d in range(256):
        a, b = cpcimg.mode0_pens(d)
        out[d] = cpcimg.mode0_byte(15 if a == 0 else 0, 15 if b == 0 else 0)
    return bytes(out)


def encode(img):
    """Η εικόνα χωρίς μάσκα: το pen 0 είναι το διάφανο (encode_masked το
    απαγορεύει ως χρώμα, άρα τίποτα δεν χάνεται)."""
    gfx.encode_masked(img)                  # (ο έλεγχος του pen 0)
    return gfx.encode_opaque(img)


def decode(data, w, h):
    """bytes (w bytes x h) -> εικόνα με None για το διάφανο."""
    return [[None if p == 0 else p for p in row]
            for row in gfx.decode_opaque(data, 2 * w, h)]


def age_images(age):
    """{τύπος: εικόνα} όσων υπάρχουν στην εποχή."""
    out = {}
    for t in TYPES:
        try:
            out[t[0]] = image(t[0], age)
        except KeyError:
            pass
    return out


def main():
    res = bytearray(open(os.path.join(DATA, 'resources.bin'), 'rb').read())
    k = (BLD_RES - 1) * 128                 # διάφανο: μάσκα #FF, δεδομένα 0
    res[k:k + 128] = bytes([0xFF, 0x00] * 64)
    blob = bytearray(res)
    blob += bytes(0x800 - len(blob))        # τα πλακίδια εδάφους στο #4800:
    terrain = open(os.path.join(DATA, 'terrain.bin'), 'rb').read()   # μία
    assert len(terrain) == 256              # σελίδα, ώστε το byte του χάρτη
    blob += terrain                         # AND #F0 να είναι το low byte
    assert ORG + len(blob) == MASK_PG
    blob += mask_page()
    blob += bytes(IMG0 - ORG - len(blob))
    start = age_images(START_AGE)
    bronze = age_images(3)
    rows = []
    for k, (key, hot, pre, cost, pts, unit) in enumerate(TYPES):
        img = start.get(key) or bronze[key]     # (ναός κλπ: χωρίς εικόνα ως
        w, h = len(img[0]) // 2, len(img)       # τη Χαλκού)
        assert w == 4 * footprint(key), key
        if key in start:
            addr = ORG + len(blob)
            blob += encode(img)
        else:
            addr = 0
        u = UNIT_SETS.index(unit) if unit else 255
        ucost, utime = UNITS[unit] if unit else ((0, 0, 0, 0), 0)
        rows.append('        db %d, %d, %d, %s, %d, %d, %d, %s, %d\n'
                    '        dw #%04X                 ; %s (%s)\n'
                    % (footprint(key), min_age(key),
                       255 if pre is None else KEYS.index(pre),
                       ', '.join(map(str, cost)), pts, w, h,
                       ', '.join(map(str, (u,) + ucost)), utime, addr, key,
                       hot))
    # οι κόκκινοι μεταγλωττισμένοι (make_compiled.py), στο τέλος της τράπεζας
    cj = json.load(open(os.path.join(DATA, 'compiled.json')))
    red = open(os.path.join(DATA, 'compiled_red.bin'), 'rb').read()
    free = cj['red_org'] - ORG - len(blob)
    assert free >= 0, 'η C6 δεν χωράει τους κόκκινους: %d' % free
    sizes = age_files()
    with open(os.path.join(DATA, 'age3.asm'), 'w') as f:
        f.write('; age3.asm — ΠΑΡΑΓΕΤΑΙ από src/make_bank6.py. Τα αρχεία των '
                'εποχών 3 (Χαλκού)\n; και 4 (Σιδήρου), M9/M12: ένα ανά '
                'πολιτισμό, χωρίς κεφαλίδα, στο AGE_AT\n; της C6 — ο πίνακας '
                '(ανά τύπο: ύψος, εικόνα, άλλαξε) και μετά οι εικόνες.\n\n'
                'AGE_AT      equ #%04X\nAGE_TAB_LEN equ %d\nAGE_MAX     equ %d'
                '             ; το μεγαλύτερο αρχείο\n'
                'cult_let:   db "%s"         ; τα γράμματα των αρχείων, με τη '
                'σειρά του μενού\n'
                % (AGE_AT, 4 * len(TYPES), max(sizes),
                   ''.join(l for _, l in CULTURES)))
    blob += bytes(free) + red
    assert len(blob) <= 0x4000
    with open(os.path.join(DATA, 'bank6.bin'), 'wb') as f:
        f.write(blob)
    keys = ''.join('BTY_%s equ %d\n' % (t[0].upper(), k)
                   for k, t in enumerate(TYPES))
    with open(os.path.join(DATA, 'bld.asm'), 'w') as f:
        f.write('; bld.asm — οι τύποι κτιρίων (M7).\n'
                '; ΠΑΡΑΓΕΤΑΙ από src/make_bank6.py — μην το πειράζεις με το '
                'χέρι.\n;\n'
                '; Ανά τύπο (BT_SIZE bytes): κάτοψη n, ελάχιστη εποχή, '
                'προαπαιτούμενο (255 κανένα),\n'
                '; κόστος τροφή, ξύλο, χρυσό, πέτρα, πόντοι ανέγερσης, '
                'πλάτος (bytes δεδομένων),\n'
                '; ύψος, μονάδα (σετ, 255 καμία), κόστος της μονάδας (4), '
                'καρέ εκπαίδευσης, και\n'
                '; η εικόνα στην τράπεζα C6.\n\n'
                'BT_N        equ %d\nBT_SIZE     equ 18\nSTART_AGE   equ %d\n'
                'MASK_PG     equ #%04X      ; byte δεδομένων -> μάσκα (C6)\n'
                'IMG0        equ #%04X      ; οι εικόνες των κτιρίων (C6)\n'
                'CMP_RED     equ #%04X      ; οι κόκκινοι μεταγλωττισμένοι (C6)\n'
                '%s\nbld_types:\n%s'
                % (len(TYPES), START_AGE, MASK_PG, IMG0, cj['red_org'], keys,
                   ''.join(rows)))
        keym = [MATRIX[t[1]] for t in TYPES] + [MATRIX[TRAIN_KEY],
                                                 MATRIX['ESC'], MATRIX['U']]
        f.write('\n; τα πλήκτρα: οι τύποι (%s), μετά %s (εκπαίδευση), ESC και U '
                '(έρευνα, M9)\n'
                '; ως (γραμμή του πίνακα, μάσκα)\nBLD_RES     equ %d\n'
                'bld_keym:\n%s'
                % (''.join(t[1] for t in TYPES), TRAIN_KEY, BLD_RES,
                   ''.join('        db %d, #%02X\n' % (r, 1 << b)
                           for r, b in keym)))
    print('data/bank6.bin  %d bytes (πόροι %d + %d τύποι κτιρίων, %d ελεύθερα, '
          'οι κόκκινοι στο #%04X)' % (len(blob), len(res), len(TYPES), free,
                                      cj['red_org']))
    print('data/age[34]?.bin  %d πολιτισμοί x 2, ως %d bytes (ως το #%04X)'
          % (len(CULTURES), max(sizes), AGE_AT + max(sizes)))


def age_files():
    """data/age3<γράμμα>.bin, age4<γράμμα>.bin για κάθε πολιτισμό -> τα
    μεγέθη τους."""
    global CULTURE
    keep, sizes = CULTURE, []
    for culture, letter in CULTURES:
        CULTURE = culture
        for age in (3, 4):
            now, before = age_images(age), age_images(age - 1)
            tab, imgs = bytearray(), bytearray()
            at = AGE_AT + 4 * len(TYPES)
            for key, *_ in TYPES:
                img = now[key]
                a = at + len(imgs)
                tab += bytes([len(img), a & 255, a >> 8,
                              int(before.get(key) != img)])
                imgs += encode(img)
            data = tab + imgs
            assert AGE_AT + len(data) <= FOG, \
                '%s εποχή %d: %d bytes, πέρα από το FOG' % (culture, age,
                                                           len(data))
            with open(os.path.join(DATA, 'age%d%s.bin' % (age, letter)),
                      'wb') as f:
                f.write(data)
            sizes.append(len(data))
    CULTURE = keep
    return sizes


if __name__ == '__main__':
    main()
