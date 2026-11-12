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

-> data/compiled_red.bin   ΟΙ ΚΟΚΚΙΝΟΙ (ομάδα 1): ο σπαθοφόρος και ο τοξότης
                           με τα pens της ομάδας αλλαγμένα (gfx.TEAMS[1]), στο
                           τέλος της τράπεζας C6 (RED_ORG, στοιχισμένο σε
                           σελίδα: make_bank6.py). Ίδια διάταξη: πίνακας 2 σετ
                           x 16 καρέ x dw, μετά οι ρουτίνες. Οι κόκκινοι
                           χωρικοί (και ό,τι δεν είναι μεταγλωττισμένο) πάνε
                           από το blit16t, με πίνακα pen προς pen (make_edges.py).
"""
import json
import os

import gfx

DATA = os.path.join(gfx.OUT, 'data')
SETS = ['villager_m', 'swordsman', 'archer', 'villager_carry']   # = U_SET
ORG = 0x4000
LIMIT = 0x4000                  # μία τράπεζα
RED_SETS = ['swordsman', 'archer']                             # = U_SET 1, 2
RED = 1                         # gfx.TEAMS: η ομάδα 1


def red(img):
    _, hi, lo = gfx.TEAMS[RED]
    return gfx.recolour(img, {gfx.TEAM_HI: hi, gfx.TEAM_LO: lo})


ALIAS = {'villager_carry': 'villager_m'}   # ο χωρικός με φορτίο (σετ 3): ο
                                            # ίδιος κώδικας + το δέμα (M9)


def build(names, org, paint=lambda img: img):
    base = org + len(names) * 16 * 2
    code = bytearray()
    entries = []
    sizes = {}
    first = {}
    for name in names:
        if name in ALIAS:
            k = names.index(ALIAS[name]) * 16
            entries += entries[k:k + 16]
            sizes[name] = 0
            continue
        n = 0
        regs = VIL_REGS if name in VIL_SETS else None
        for img in frames(name):
            entries.append(base + len(code))
            r = compile_frame(paint(img), regs)
            code += r
            n += len(r)
        sizes[name] = n
    blob = bytearray()
    for e in entries:
        blob += bytes([e & 255, e >> 8])
    return blob + code, sizes


def frames(name):
    blob = open(os.path.join(DATA, name + '.bin'), 'rb').read()
    dec = [gfx.decode_masked(blob[k:k + 128], 8, 16)
           for k in range(0, 12 * 128, 128)]
    return dec + [gfx.mirror(dec[4 + k]) for k in range(4)]   # S E N W


# ΟΙ ΧΩΡΙΚΟΙ (σετ 0, 3): τα bytes με pens της ομάδας είναι μόνο τρία, και
# γράφονται από τους B, D, E, που τους φορτώνει ο καλών ανά ομάδα
# (game/units.asm, units_draw: VIL_T0 / VIL_T1) — ένας κώδικας για όλες τις
# ομάδες. `ld (hl),r` / `or r` αντί για `ld (hl),n` / `or n`.
VIL_REGS = {12: 0, 196: 2, 200: 3}              # byte -> r (B 0, D 2, E 3)
VIL_SETS = ('villager_m', 'villager_carry')


def vil_values(team):
    """(B, D, E) της ομάδας: τα τρία bytes, βαμμένα."""
    import cpcimg
    _, hi, lo = gfx.TEAMS[team]
    m = {gfx.TEAM_HI: hi, gfx.TEAM_LO: lo}
    out = {}
    for v, r in VIL_REGS.items():
        a, b = cpcimg.mode0_pens(v)
        out[r] = cpcimg.mode0_byte(m.get(a, a), m.get(b, b))
    return out[0], out[2], out[3]


def compile_frame(img, regs=None):
    regs = regs or {}
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
                if d in regs:
                    out += bytes([0x70 + regs[d]])      # ld (hl),r
                else:
                    out += bytes([0x36, d])     # ld (hl),d
            else:
                out += bytes([0x7E, 0xE6, m])   # ld a,(hl) / and m
                if d in regs:
                    out += bytes([0xB0 + regs[d]])      # or r
                elif d:
                    out += bytes([0xF6, d])     # or d
                out += b'\x77'                  # ld (hl),a
        out += b'\xC9' if y == 15 else b'\xEF'  # ret / rst #28
    return bytes(out)


def main():
    blob, sizes = build(SETS, ORG)
    assert len(blob) <= LIMIT, 'τα μεταγλωττισμένα δεν χωράνε: %d' % len(blob)
    with open(os.path.join(DATA, 'compiled.bin'), 'wb') as f:
        f.write(blob)
    size = len(build(RED_SETS, 0x4000, red)[0])
    red_org = (0x8000 - size) & ~0xFF           # στο τέλος της C6
    rblob, _ = build(RED_SETS, red_org, red)
    with open(os.path.join(DATA, 'compiled_red.bin'), 'wb') as f:
        f.write(rblob)
    with open(os.path.join(DATA, 'compiled.json'), 'w') as f:
        json.dump({'org': ORG, 'sets': SETS, 'frames_per_set': 16,
                   'bytes': len(blob), 'per_set': sizes,
                   'red_org': red_org, 'red_sets': RED_SETS,
                   'red_bytes': len(rblob)}, f, indent=1)
        f.write('\n')
    print('data/compiled.bin  %d bytes (%d ελεύθερα στην τράπεζα): %s'
          % (len(blob), LIMIT - len(blob), sizes))
    with open(os.path.join(DATA, 'compiled.asm'), 'w') as f:
        f.write('; ΠΑΡΑΓΕΤΑΙ από src/make_compiled.py: B, D, E των χωρικών '
                'ανά ομάδα\n')
        f.write('CMP_LEN     equ %d            ; στην C7 από το #4000\n'
                % len(blob))
        for t in (0, 1):
            b, d, e = vil_values(t)
            f.write('VIL_B%d      equ #%02X\nVIL_DE%d     equ #%02X%02X\n'
                    % (t, b, t, d, e))
    print('data/compiled_red.bin  %d bytes, στο #%04X της C6' % (len(rblob), red_org))


if __name__ == '__main__':
    main()
