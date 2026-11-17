"""Το περίγραμμα κάθε καρέ των μονάδων, για όταν κρύβονται πίσω από κτίριο —
και το βέλος των τοξοτών (M8).

    python3 src/make_edges.py

-> data/arrow.bin       το καρέ ενός βέλους (8 x 16, με μάσκα), μετά τον
                        κέρσορα στην C5 (SPR_ARROW). ΑΧΡΗΣΙΜΟΠΟΙΗΤΟ προς το
                        παρόν: τα βέλη ζωγραφίζονται με XOR (game/bank7.asm)·
                        η θέση μένει για ένα βέλος-sprite αργότερα.
-> data/occ_edges.bin   (1) 16 bytes ανά καρέ, με τη σειρά που έχει η τράπεζα C5
                        (game/units.asm, units_gfx): ανά σετ (U_SET) τα 21
                        καρέ του αρχείου και μετά οι 4 όψεις W (τα καρέ 4-7
                        καθρεφτισμένα) — 25 x 128 bytes = SPR_STRIDE. Ένα byte
                        ανά γραμμή, bit 7 το αριστερό pixel: 1 όπου το pixel
                        ανήκει στη σιλουέτα και έχει διάφανο γείτονα (πάνω,
                        κάτω, αριστερά, δεξιά· έξω από το καρέ = διάφανο).

                        (2) στο +#700 (#7B00 στην C5), δύο σελίδες: η μάσκα
                        και το pen του περιγράμματος για κάθε byte γραμμής
                        με bits μόνο στο ζευγάρι ενός byte (#C0, #30, #0C,
                        #03) — ώστε ο Z80 να κάνει `AND ζευγάρι; LD L,A`.

                        (3) στο +#900 (#7D00): ξανά η σελίδα της μάσκας και
                        στο +#A00 το pen του περιγράμματος της ομάδας 1
                        (κόκκινο: H = #7D αντί για #7B στο occ_make)· και στο
                        +#B00 (#7F00, TR1) ο πίνακας byte προς byte της
                        ομάδας 1: κάθε pixel με pen ομάδας (T, t) στο pen της
                        (gfx.TEAMS[1]) — για το blit16t.
-> data/c5_set0..2.bin  οι θέσεις 0-2 της C5 (χωρικός, σπαθοφόρος, τοξότης): τα
                        21 καρέ του σετ, με το καρέ 12 (το πρώτο της επίθεσης
                        S, που δεν δείχνεται: μόνο το χτύπημα 13/15/17) να
                        είναι Η ΟΨΗ W ΤΗΣ ΕΠΙΘΕΣΗΣ: το 15 (E) καθρεφτισμένο.
-> data/c5_slot3.bin    η θέση 3 της C5 ΟΛΟΚΛΗΡΗ (25 καρέ): ο ΟΠΛΙΤΗΣ (σετ 4,
                        από την ακαδημία) και το ΙΠΠΙΚΟ (σετ 5, από τον
                        στάβλο, src/horse8.py), 12 καρέ το καθένα (slot3).
                        Είναι το HOPL.BIN της δισκέτας, που το φορτώνει το
                        start (game/main.asm). Ο χωρικός με
                        φορτίο (σετ 3) δεν έχει πια δικά του καρέ: ο χωρικός
                        + το δέμα από πάνω (carry_ov, bank7.asm).
-> data/ctop.asm        ανά καρέ του χωρικού: η γραμμή του δέματος (2 πάνω από
                        την πρώτη γεμάτη, src/make_carry.py).

Το game/occlude.asm βρίσκει τη γραμμή r του καρέ στη διεύθυνση A (C5) στο
OCC_E + (A - #4000) / 8 + r.
"""
import os

import cpcimg
import gfx
import make_map

DATA = os.path.join(gfx.OUT, 'data')
SETS = ['villager_m', 'swordsman', 'archer']        # οι θέσεις 0-2 της C5
SLOT3 = 'hoplite'                                   # η θέση 3: U_SET 4
FRAMES, WEST = 21, 4


ATK_E = 15                      # το καρέ του χτυπήματος, όψη E
W_ATK = 12                      # το καρέ W της επίθεσης, σε κάθε σετ


def frames(name):
    blob = open(os.path.join(DATA, name + '.bin'), 'rb').read()
    assert len(blob) == FRAMES * 128, name
    return [gfx.decode_masked(blob[k:k + 128], 8, 16)
            for k in range(0, len(blob), 128)]


def c5_set(name):
    """Τα 21 καρέ ενός σετ όπως μπαίνουν στην C5: το 12 = το W της επίθεσης."""
    fs = frames(name)
    fs[W_ATK] = gfx.mirror(fs[ATK_E])
    return fs


def slot(name):
    """Τα 25 καρέ μιας θέσης της C5: τα 21 και οι 4 όψεις W (4-7 ανάποδα)."""
    fs = c5_set(name)
    return fs + [gfx.mirror(fs[4 + k]) for k in range(WEST)]


# Η ΘΕΣΗ 3, ΜΟΙΡΑΣΜΕΝΗ (2026-11-17): ο οπλίτης (σετ 4) και το ιππικό (σετ 5,
# src/horse8.py), 12 καρέ το καθένα, και ένα κενό (25 = SPR_STRIDE / 128):
#   0-1 βάδισμα S, 2-3 E, 4-5 N, 6-7 W (τα E καθρεφτισμένα): 2 καρέ ανά όψη,
#   8 το W της επίθεσης, 9 το χτύπημα S, 10 το χτύπημα E, 11 το πτώμα.
# Το χτύπημα N είναι το βάδισμα N (4). Ο Z80 τα βρίσκει με το half_tab
# (game/units.asm, unit_frame).
HALF = 12
HALF_WALK = {'s': (0, 1), 'e': (4, 6), 'n': (8, 9)}
POSE = {12: 8, 13: 9, 15: 10, 17: 4, 18: 11, 19: 11, 20: 11}  # U_STEP -> καρέ


def half(fs):
    out = []
    for f in 'sen':
        out += [fs[k] for k in HALF_WALK[f]]
    out += [gfx.mirror(fs[k]) for k in HALF_WALK['e']]
    out += [gfx.mirror(fs[ATK_E]), fs[13], fs[ATK_E], fs[20]]
    assert len(out) == HALF
    return out


def cavalry_frames():
    import horse8
    return horse8.build().frames


def slot3():
    """Τα 25 καρέ της θέσης 3: οπλίτης, ιππικό, ένα κενό."""
    blank = [[None] * 8 for _ in range(16)]
    return half(frames(SLOT3)) + half(cavalry_frames()) + [blank]


def edges(spr):
    def on(i, j):
        return 0 <= i < 8 and 0 <= j < 16 and spr[j][i] is not None
    out = []
    for j in range(16):
        b = 0
        for i in range(8):
            edge = on(i, j) and not (on(i - 1, j) and on(i + 1, j) and
                                     on(i, j - 1) and on(i, j + 1))
            b |= edge << (7 - i)
        out.append(b)
    return out


def table():
    out = bytearray()
    for name in SETS:
        for f in slot(name):
            out += bytes(edges(f))
    for f in slot3():
        out += bytes(edges(f))
    return out


PAGES_AT = 0x700                # από την αρχή του πίνακα: #7400 + #700 = #7B00
OM_PAIR = {0: 0xFF, 1: 0xAA, 2: 0x55, 3: 0x00}  # (pixel 0, pixel 1) -> μάσκα


def pages():
    om, od = [0xFF] * 256, [0] * 256
    out = make_map.outline_byte()
    for k in range(4):
        shift = 6 - 2 * k
        for e in range(1, 4):
            v = e << shift
            om[v] = OM_PAIR[e]
            od[v] = out & ~OM_PAIR[e] & 0xFF
    out1 = cpcimg.mode0_byte(RED_HI, RED_HI)   # ομάδα 1
    od1 = [0] * 256
    for k in range(4):
        shift = 6 - 2 * k
        for e in range(1, 4):
            v = e << shift
            od1[v] = out1 & ~OM_PAIR[e] & 0xFF
    return bytes(om) + bytes(od) + bytes(om) + bytes(od1) + tr1()


_, RED_HI, RED_LO = gfx.TEAMS[1]


def tr1():
    """byte -> byte: τα pens της ομάδας (T, t) στα της ομάδας 1."""
    m = {gfx.TEAM_HI: RED_HI, gfx.TEAM_LO: RED_LO}
    t = [0] * 256
    for a in range(16):
        for b in range(16):
            t[cpcimg.mode0_byte(a, b)] = cpcimg.mode0_byte(m.get(a, a),
                                                           m.get(b, b))
    return bytes(t)


ARROW = '''
........
........
........
........
........
........
......I.
....II..
..II....
.I......
........
........
........
........
........
........
'''


def arrow():
    rows = [r for r in ARROW.split('\n') if r]
    img = [[None if ch == '.' else gfx.PEN[ch] for ch in r] for r in rows]
    blob = gfx.encode_masked(img)
    assert len(blob) == 128
    return blob


def main():
    with open(os.path.join(DATA, 'arrow.bin'), 'wb') as f:
        f.write(arrow())
    for k, name in enumerate(SETS):
        with open(os.path.join(DATA, 'c5_set%d.bin' % k), 'wb') as f:
            f.write(b''.join(gfx.encode_masked(img) for img in c5_set(name)))
    with open(os.path.join(DATA, 'c5_slot3.bin'), 'wb') as f:
        f.write(b''.join(gfx.encode_masked(img) for img in slot3()))
    import make_carry
    tops = []
    for img in slot('villager_m'):
        top = next(y for y, r in enumerate(img) if any(p is not None for p in r))
        tops.append(max(0, top - len(make_carry.BUNDLE)))
    with open(os.path.join(DATA, 'ctop.asm'), 'w') as f:
        f.write('; ctop.asm — ΠΑΡΑΓΕΤΑΙ από src/make_edges.py: ανά καρέ της '
                'θέσης 0 της C5,\n; η γραμμή του δέματος του χωρικού με '
                'φορτίο (carry_ov, bank7.asm), και τα 2 bytes των γραμμών '
                'του.\nctop:       db %s\nBUN0        equ #%02X\n'
                'BUN1        equ #%02X\n'
                % (', '.join(map(str, tops)),
                   cpcimg.mode0_byte(gfx.PEN['y'], gfx.PEN['y']),
                   cpcimg.mode0_byte(gfx.PEN['D'], gfx.PEN['D'])))
    t = table()
    t += bytes(PAGES_AT - len(t))
    t += pages()
    with open(os.path.join(DATA, 'occ_edges.bin'), 'wb') as f:
        f.write(t)
    print('data/occ_edges.bin  %d bytes (%d σετ x %d καρέ x 16 γραμμές, και '
          'οι 5 σελίδες: περίγραμμα x 2 ομάδες, πίνακας της ομάδας 1)'
          % (len(t), len(SETS) + 1, FRAMES + WEST))


if __name__ == '__main__':
    main()
