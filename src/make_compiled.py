"""Τα «μεταγλωττισμένα» sprites των μονάδων -> data/compiled.bin (τράπεζα C7).

    python3 src/make_compiled.py

Κάθε καρέ βαδίσματος γίνεται ΚΩΔΙΚΑΣ Z80 που το ζωγραφίζει, αντί για
δεδομένα που διαβάζει το blit16. Ανά byte του sprite (μάσκα, δεδομένα):

    διάφανο (μάσκα #FF)   τίποτα                              0 T
    αδιαφανές (μάσκα 0)   ld (hl),n                          10 T
    μικτό                 ld a,(hl) / and m / or d / ld (hl),a  28 T

αντί για 40 T ανά byte πάντα. Ανάμεσα: `inc l` όσα bytes παραλείπονται, και
ανά γραμμή η αλλαγή γραμμής του blit16 (L = C, H + 8, και στην αλλαγή σειράς
χαρακτήρων +80 τυλιγμένο στα 2 KB) σε ΕΝΑ byte: `rst #28`, στη χαμηλή μνήμη
(game/main.asm), που φαίνεται πάντα, όποια τράπεζα κι αν είναι στο #4000.

ΣΥΜΒΑΣΗ: HL = το byte οθόνης της πάνω-αριστερής γωνίας. Καμία γραμμή του
sprite δεν περνάει όριο σελίδας (το low byte κάθε σειράς χαρακτήρων < #FD):
το ελέγχει ο καλών, αλλιώς πάει στο blit16. Χαλάει A, C, HL.

ΔΙΑΤΑΞΗ στο #4000 (τράπεζα C7):

    #4000   πίνακας: σετ x 16 καρέ x dw  (καρέ = όψη x 4 + βήμα, όψεις S E N W)
    ...     οι ρουτίνες

Οι όψεις W είναι οι E καθρεφτισμένες, όπως στην τράπεζα C5.
"""
import json
import os

import gfx

DATA = os.path.join(gfx.OUT, 'data')
SETS = ['villager_m', 'swordsman', 'archer', 'villager_carry']   # = U_SET
ORG = 0x4000
LIMIT = 0x4000                  # μία τράπεζα


def frames(name):
    blob = open(os.path.join(DATA, name + '.bin'), 'rb').read()
    dec = [gfx.decode_masked(blob[k:k + 128], 8, 16)
           for k in range(0, 12 * 128, 128)]
    return dec + [gfx.mirror(dec[4 + k]) for k in range(4)]   # S E N W


def compile_frame(img):
    data = gfx.encode_masked(img)
    out = bytearray([0x4D])                     # ld c,l
    for y in range(16):
        cur = 0
        for k in range(4):
            m, d = data[y * 8 + 2 * k], data[y * 8 + 2 * k + 1]
            if m == 0xFF:
                continue
            out += b'\x2C' * (k - cur)          # inc l
            cur = k
            if m == 0:
                out += bytes([0x36, d])         # ld (hl),d
            else:
                out += bytes([0x7E, 0xE6, m])   # ld a,(hl) / and m
                if d:
                    out += bytes([0xF6, d])     # or d
                out += b'\x77'                  # ld (hl),a
        out += b'\xC9' if y == 15 else b'\xEF'  # ret / rst #28
    return bytes(out)


def main():
    base = ORG + len(SETS) * 16 * 2
    code = bytearray()
    entries = []
    sizes = {}
    for name in SETS:
        n = 0
        for img in frames(name):
            entries.append(base + len(code))
            r = compile_frame(img)
            code += r
            n += len(r)
        sizes[name] = n
    blob = bytearray()
    for e in entries:
        blob += bytes([e & 255, e >> 8])
    blob += code
    assert len(blob) <= LIMIT, 'τα μεταγλωττισμένα δεν χωράνε: %d' % len(blob)
    with open(os.path.join(DATA, 'compiled.bin'), 'wb') as f:
        f.write(blob)
    with open(os.path.join(DATA, 'compiled.json'), 'w') as f:
        json.dump({'org': ORG, 'sets': SETS, 'frames_per_set': 16,
                   'bytes': len(blob), 'per_set': sizes}, f, indent=1)
        f.write('\n')
    print('data/compiled.bin  %d bytes (%d ελεύθερα στην τράπεζα): %s'
          % (len(blob), LIMIT - len(blob), sizes))


if __name__ == '__main__':
    main()
