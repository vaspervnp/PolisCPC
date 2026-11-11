"""Κωδικοποίηση Mode 0 και Mode 1 του Amstrad CPC, και η παλέτα του firmware.

ΑΝΤΙΓΡΑΦΟ, ΟΧΙ SYMLINK

Όσο το Polis ζούσε μέσα στο CPCArt, αυτό ήταν symlink στο
`steampunk/src/cpcimg.py` — έναν κωδικοποιητή που μοιράζονταν πέντε σετ
γραφικών. Εδώ είναι αντίγραφο επίτηδες: το PolisCPC πρέπει να χτίζεται από
μόνο του, με ένα `git clone` και τίποτε άλλο.

Αν διορθωθεί κάτι εκεί, φέρ' το με το χέρι. Ο ισχυρισμός στο τέλος του
αρχείου τρέχει σε κάθε import και πιάνει κάθε λάθος μεταφοράς — η σειρά των
bits του Mode 0 είναι ακριβώς το είδος του πράγματος που γράφεται λάθος
σιωπηλά.

Και στους δύο τρόπους το **bit 0 της πένας πάει στο ΠΑΝΩ bit του byte**, όχι
το bit 3. Είναι αντιδιαισθητικό και γράφεται λάθος με το ένα χέρι, γι' αυτό
κάθε κωδικοποιητής έχει δίπλα του τον αντίστροφο και έναν ισχυρισμό που τρέχει
σε κάθε import και τους δένει σε όλες τις δυνατές τιμές.
"""

# RGB για κάθε firmware number του CPC (0-26) και τα ονόματά τους.
FW_RGB = [
    (0x00,0x00,0x00), (0x00,0x00,0x80), (0x00,0x00,0xFF), (0x80,0x00,0x00),
    (0x80,0x00,0x80), (0x80,0x00,0xFF), (0xFF,0x00,0x00), (0xFF,0x00,0x80),
    (0xFF,0x00,0xFF), (0x00,0x80,0x00), (0x00,0x80,0x80), (0x00,0x80,0xFF),
    (0x80,0x80,0x00), (0x80,0x80,0x80), (0x80,0x80,0xFF), (0xFF,0x80,0x00),
    (0xFF,0x80,0x80), (0xFF,0x80,0xFF), (0x00,0xFF,0x00), (0x00,0xFF,0x80),
    (0x00,0xFF,0xFF), (0x80,0xFF,0x00), (0x80,0xFF,0x80), (0x80,0xFF,0xFF),
    (0xFF,0xFF,0x00), (0xFF,0xFF,0x80), (0xFF,0xFF,0xFF),
]
FW_NAMES = [
    'Black', 'Blue', 'Bright blue', 'Red', 'Magenta', 'Mauve', 'Bright red',
    'Purple', 'Bright magenta', 'Green', 'Cyan', 'Sky blue', 'Yellow', 'White',
    'Pastel blue', 'Orange', 'Pink', 'Pastel magenta', 'Bright green',
    'Sea green', 'Bright cyan', 'Lime', 'Pastel green', 'Pastel cyan',
    'Bright yellow', 'Pastel yellow', 'Bright white',
]

# Mode 0: 160x200, 16 pens, 2 pixels το byte, αναλογία pixel 2:1
#   αριστερό a: bit0->b7  bit1->b3  bit2->b5  bit3->b1
#   δεξί     b: bit0->b6  bit1->b2  bit2->b4  bit3->b0
MODE0_SHIFTS = ((7, 3, 5, 1), (6, 2, 4, 0))

# Mode 1: 320x200, 4 pens, 4 pixels το byte, αναλογία pixel 1:1
#   pixel i: bit0 -> b(7-i)   bit1 -> b(3-i)
MODE1_SHIFTS = tuple((7 - i, 3 - i) for i in range(4))

# Mode 2: 640x200, 2 pens, 8 pixels το byte, αναλογία pixel 1:2 (μισό πλάτος)
#   pixel i: bit0 -> b(7-i).  Ένα bit, οπότε δεν υπάρχει σειρά να μπερδευτεί —
#   αλλά ο αριστερότερος pixel πάει στο ΠΑΝΩ bit, όπως και στους άλλους δύο.
MODE2_SHIFTS = tuple((7 - i,) for i in range(8))


def _pack(pens, table):
    v = 0
    for pen, shifts in zip(pens, table):
        for bit, shift in enumerate(shifts):
            v |= ((pen >> bit) & 1) << shift
    return v


def _unpack(byte, table):
    out = []
    for shifts in table:
        pen = 0
        for bit, shift in enumerate(shifts):
            pen |= ((byte >> shift) & 1) << bit
        out.append(pen)
    return tuple(out)


def mode0_byte(a, b):
    return _pack((a, b), MODE0_SHIFTS)


def mode0_pens(byte):
    return _unpack(byte, MODE0_SHIFTS)


def mode1_byte(p0, p1, p2, p3):
    return _pack((p0, p1, p2, p3), MODE1_SHIFTS)


def mode1_pens(byte):
    return _unpack(byte, MODE1_SHIFTS)


def mode2_byte(*pens):
    return _pack(pens, MODE2_SHIFTS)


def mode2_pens(byte):
    return _unpack(byte, MODE2_SHIFTS)


assert all(mode0_pens(mode0_byte(a, b)) == (a, b)
           for a in range(16) for b in range(16)), 'Mode 0: όχι αντίστροφοι'
assert all(mode1_pens(mode1_byte(*p)) == p
           for p in [(a, b, c, d) for a in range(4) for b in range(4)
                     for c in range(4) for d in range(4)]), 'Mode 1: όχι αντίστροφοι'
assert all(mode2_pens(mode2_byte(*p)) == p
           for p in [tuple((n >> k) & 1 for k in range(8))
                     for n in range(256)]), 'Mode 2: όχι αντίστροφοι'
# Τα σημεία που προδίδουν αμέσως ανεστραμμένη σειρά bits.
assert mode0_byte(1, 0) == 0x80 and mode0_byte(3, 3) == 0xCC
assert mode1_byte(1, 0, 0, 0) == 0x80 and mode1_byte(3, 3, 3, 3) == 0xFF
assert mode2_byte(1, 0, 0, 0, 0, 0, 0, 0) == 0x80
assert mode2_byte(0, 0, 0, 0, 0, 0, 0, 1) == 0x01
assert mode2_byte(*([1] * 8)) == 0xFF

MODES = {
    0: dict(pens=16, px_per_byte=2, aspect=2, pack=mode0_byte),
    1: dict(pens=4, px_per_byte=4, aspect=1, pack=mode1_byte),
    2: dict(pens=2, px_per_byte=8, aspect=0.5, pack=mode2_byte),
}


def encode(img, mode):
    """Εικόνα (γραμμές από pens) -> bytes οθόνης."""
    n = MODES[mode]['px_per_byte']
    pack = MODES[mode]['pack']
    out = bytearray()
    for row in img:
        assert len(row) % n == 0, 'το πλάτος πρέπει να είναι πολλαπλάσιο του %d' % n
        for i in range(0, len(row), n):
            out.append(pack(*row[i:i + n]))
    return bytes(out)
