"""Η τράπεζα C6 και τα κτίρια του παιχνιδιού (M7).

    python3 src/make_bank6.py

-> data/bank6.bin   ό,τι μπαίνει στην C6 στο #4000: οι πόροι (resources.bin,
                    15 x 128, στοιχισμένοι), τα πλακίδια εδάφους στο #4800
                    (terrain.bin, μία σελίδα), και μετά οι εικόνες των κτιρίων
                    της αρχικής εποχής (με μάσκα, mask,data ανά byte, γραμμή
                    προς γραμμή)
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
CULTURE = 'greek'
START_AGE = 2
INFO = {b['key']: b for b in json.load(open(os.path.join(
    gfx.OUT, 'buildings.json')))['buildings']}

UNIT_SETS = ['villager_m', 'swordsman', 'archer']      # = U_SET

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
]
KEYS = [t[0] for t in TYPES]

# Ο πόρος 13 («καλάμια», κανένα στον χάρτη) γίνεται το ΠΛΑΚΙΔΙΟ ΚΤΙΡΙΟΥ: το
# γράφει ο Z80 στην κάτοψη κάθε κτιρίου, είναι εμπόδιο (src/make_map.py) και
# δεν έχει sprite (διάφανο εδώ).
BLD_RES = 13

# Ο πίνακας πλήκτρων του CPC: χαρακτήρας -> (γραμμή, bit).
MATRIX = {'C': (7, 6), 'H': (5, 4), 'B': (6, 6), 'G': (6, 4), 'S': (7, 4),
          'M': (4, 6), 'R': (6, 2), 'L': (4, 4), 'F': (6, 5), 'W': (7, 3),
          'T': (6, 3), 'ESC': (8, 2)}
TRAIN_KEY = 'T'

# Οι μονάδες που βγαίνουν: κόστος και καρέ (των 25 Hz) εκπαίδευσης.
UNITS = {'villager_m': ((50, 0, 0, 0), 200),
         'swordsman':  ((35, 0, 15, 0), 250),
         'archer':     ((40, 20, 0, 0), 250)}


def min_age(key):
    return min(INFO[key]['drawn_at_ages'])


def image(key, age=START_AGE):
    """Η εικόνα του κτιρίου στην εποχή: η τελευταία που έχει ζωγραφιστεί ως
    τότε."""
    return B.render(key, CULTURE, B.covers(INFO[key]['drawn_at_ages'])[age])


def footprint(key):
    return B.footprint(key)


def main():
    res = bytearray(open(os.path.join(DATA, 'resources.bin'), 'rb').read())
    k = (BLD_RES - 1) * 128                 # διάφανο: μάσκα #FF, δεδομένα 0
    res[k:k + 128] = bytes([0xFF, 0x00] * 64)
    blob = bytearray(res)
    blob += bytes(0x800 - len(blob))        # τα πλακίδια εδάφους στο #4800:
    terrain = open(os.path.join(DATA, 'terrain.bin'), 'rb').read()   # μία
    assert len(terrain) == 256              # σελίδα, ώστε το byte του χάρτη
    blob += terrain                         # AND #F0 να είναι το low byte
    rows = []
    for key, hot, pre, cost, pts, unit in TYPES:
        img = image(key)
        w, h = len(img[0]) // 2, len(img)
        assert w == 4 * footprint(key), key
        addr = ORG + len(blob)
        blob += gfx.encode_masked(img)
        u = UNIT_SETS.index(unit) if unit else 255
        ucost, utime = UNITS[unit] if unit else ((0, 0, 0, 0), 0)
        rows.append('        db %d, %d, %d, %s, %d, %d, %d, %s, %d\n'
                    '        dw #%04X                 ; %s (%s)\n'
                    % (footprint(key), min_age(key),
                       255 if pre is None else KEYS.index(pre),
                       ', '.join(map(str, cost)), pts, w, h,
                       ', '.join(map(str, (u,) + ucost)), utime, addr, key,
                       hot))
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
                '%s\nbld_types:\n%s'
                % (len(TYPES), START_AGE, keys, ''.join(rows)))
        keym = [MATRIX[t[1]] for t in TYPES] + [MATRIX[TRAIN_KEY],
                                                 MATRIX['ESC']]
        f.write('\n; τα πλήκτρα: οι τύποι (%s), μετά %s (εκπαίδευση) και ESC\n'
                '; ως (γραμμή του πίνακα, μάσκα)\nBLD_RES     equ %d\n'
                'bld_keym:\n%s'
                % (''.join(t[1] for t in TYPES), TRAIN_KEY, BLD_RES,
                   ''.join('        db %d, #%02X\n' % (r, 1 << b)
                           for r, b in keym)))
    print('data/bank6.bin  %d bytes (πόροι %d + %d τύποι κτιρίων)'
          % (len(blob), len(res), len(TYPES)))


if __name__ == '__main__':
    main()
