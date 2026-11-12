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
-> data/set3.bin        το σετ 3 της C5: ο χωρικός με φορτίο (villager_carry),
                        με τα καρέ 12-14 (επίθεση του χωρικού με φορτίο, που
                        δεν χρησιμοποιείται: πριν χτυπήσει γίνεται σετ 0) να
                        έχουν ΤΙΣ ΟΨΕΙΣ W ΤΗΣ ΕΠΙΘΕΣΗΣ των σετ 0, 1, 2: το
                        καρέ 15 (E, το χτύπημα) καθρεφτισμένο. Η C5 δεν είχε
                        άλλο χώρο (game/bank7.asm, atk_w).

Το game/occlude.asm βρίσκει τη γραμμή r του καρέ στη διεύθυνση A (C5) στο
OCC_E + (A - #4000) / 8 + r.
"""
import os

import cpcimg
import gfx
import make_map

DATA = os.path.join(gfx.OUT, 'data')
SETS = ['villager_m', 'swordsman', 'archer', 'villager_carry']    # = U_SET
FRAMES, WEST = 21, 4


ATK_E = 15                      # το καρέ του χτυπήματος, όψη E
W_ATK = 12                      # στο σετ 3: τα W της επίθεσης, ένα ανά σετ 0-2


def frames(name):
    blob = open(os.path.join(DATA, name + '.bin'), 'rb').read()
    assert len(blob) == FRAMES * 128, name
    return [gfx.decode_masked(blob[k:k + 128], 8, 16)
            for k in range(0, len(blob), 128)]


def set3():
    """Τα 21 καρέ του σετ 3, όπως μπαίνουν στην C5."""
    fs = frames('villager_carry')
    for k, name in enumerate(SETS[:3]):
        fs[W_ATK + k] = gfx.mirror(frames(name)[ATK_E])
    return fs


def set_frames(k):
    return set3() if k == 3 else frames(SETS[k])


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
    for k in range(len(SETS)):
        fs = set_frames(k)
        for f in fs + [gfx.mirror(fs[4 + k]) for k in range(WEST)]:
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
    with open(os.path.join(DATA, 'set3.bin'), 'wb') as f:
        f.write(b''.join(gfx.encode_masked(img) for img in set3()))
    t = table()
    t += bytes(PAGES_AT - len(t))
    t += pages()
    with open(os.path.join(DATA, 'occ_edges.bin'), 'wb') as f:
        f.write(t)
    print('data/occ_edges.bin  %d bytes (%d σετ x %d καρέ x 16 γραμμές, και '
          'οι 5 σελίδες: περίγραμμα x 2 ομάδες, πίνακας της ομάδας 1)' % (len(t), len(SETS), FRAMES + WEST))


if __name__ == '__main__':
    main()
