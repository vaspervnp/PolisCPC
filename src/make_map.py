"""Ο χάρτης της πρώτης πίστας -> data/map96.bin, όπως τον διαβάζει το παιχνίδι.

    python3 src/make_map.py

Είναι ο ΙΔΙΟΣ χάρτης με το preview/map.png (`mockup.make_map`, ίδιος σπόρος):
ό,τι κρίθηκε στο mockup είναι ό,τι ζωγραφίζει ο Z80.

ΕΝΑ BYTE ΑΝΑ ΠΛΑΚΙΔΙΟ, 96 x 96 = 9.216 bytes

    bits 4-7   έδαφος (θέση στο TERRAIN)  -> byte AND #F0 = θέση στη σελίδα
                                             των πλακιδίων, χωρίς ολίσθηση
    bits 0-3   πόρος (θέση στο RESOURCES), 0 = τίποτα

Σειρά: j εξωτερικά, i εσωτερικά — το (i, j) είναι στο j*96 + i. Στην οθόνη το
i πάει κάτω-δεξιά, άρα ένα βήμα «δεξιά κατά μήκος της σειράς ρόμβων» είναι
(i+1, j-1) = +1-96.

ΚΑΙ ΤΟ HUD (data/hud_page.bin)

Από το M2 το HUD ΔΕΝ είναι στη μνήμη οθόνης που κυλάει: είναι στην κύρια
RAM #4000-#7FFF και το δείχνει το δεύτερο «καρέ» του CRTC (split-screen).
Το αρχείο είναι ολόκληρη η σελίδα των 16 KB στη διάταξη του CRTC με αρχή 0:
σειρά k, γραμμή l, byte b στο l*#800 + k*80 + b. Είναι σχεδόν όλο μηδενικά·
το παιχνίδι το παίρνει συμπιεσμένο. Ίδιο HUD με το mockup, με τον μίνι
χάρτη χωρίς το πλαίσιο της κάμερας.

Τα κτίρια ΔΕΝ είναι στον χάρτη: είναι αντικείμενα με δική τους λίστα (M7).
Κάτω από τις κατόψεις τους ο χάρτης έχει σκέτο έδαφος.
"""
import json
import os

import cpcimg
import gfx
import mockup
import terrain as T

DATA = os.path.join(gfx.OUT, 'data')
N = mockup.N

TER = {k: i for i, (k, _, _, _) in enumerate(T.TERRAIN)}
RES = {k: i for i, (k, _, _, _, _) in enumerate(T.RESOURCES)}


def encode(grd, res):
    out = bytearray()
    for j in range(N):
        for i in range(N):
            out.append(TER[grd[j][i]] << 4 | RES[res[j][i] or 'none'])
    return bytes(out)


HUD_Y0, HUD_ROWS = mockup.MAP_H, 7

# Από πού ΔΕΝ περνάει μονάδα (M5). Ένας ορισμός για τον Z80 (data/nav.asm)
# και για τους ελέγχους (tests/m5_check.py).
BLOCK_TER = {'water_deep', 'water_shallow', 'cliff'}
BLOCK_RES = {'tree', 'tree_pine', 'tree_palm', 'berry_bush', 'bush_empty',
             'gold_rock', 'stone_rock', 'fish', 'whale', 'ruins'}


def blocked_byte(b):
    """Το byte του χάρτη -> 1 αν το πλακίδιο δεν περνιέται."""
    ter = T.TERRAIN[b >> 4][0]
    res = T.RESOURCES[b & 15][0]
    return int(ter in BLOCK_TER or res in BLOCK_RES)


def nav_asm():
    ter = [int(k[0] in BLOCK_TER) for k in T.TERRAIN]
    res = [int(k[0] in BLOCK_RES) for k in T.RESOURCES]
    assert len(ter) == 16 and len(res) == 16
    return ('; nav.asm — ποια εδάφη και πόροι ΔΕΝ περνιούνται (M5).\n'
            '; ΠΑΡΑΓΕΤΑΙ από src/make_map.py — μην το πειράζεις με το χέρι.\n'
            '; 1 = εμπόδιο, με τη θέση στο TERRAIN / RESOURCES.\n\n'
            'ter_block:  db %s\n'
            'res_block:  db %s\n'
            % (','.join(map(str, ter)), ','.join(map(str, res))))


def hud_page(grd, res):
    img = mockup.hud_background()
    mockup.minimap(img, grd, res, (0, 0), rect=False)
    page = bytearray(0x4000)
    for k in range(HUD_ROWS):
        for l in range(8):
            row = img[HUD_Y0 + k * 8 + l]
            for b in range(80):
                p, q = row[2 * b], row[2 * b + 1]
                page[l * 0x800 + k * 80 + b] = cpcimg.mode0_byte(p or 0, q or 0)
    return bytes(page)


def main():
    grd, res = mockup.make_map()
    with open(os.path.join(DATA, 'hud_page.bin'), 'wb') as f:
        f.write(hud_page(grd, res))
    print('data/hud_page.bin  HUD %d γραμμές, σελίδα 16 KB στη διάταξη CRTC'
          % (HUD_ROWS * 8))
    blob = encode(grd, res)
    assert len(blob) == N * N
    with open(os.path.join(DATA, 'map96.bin'), 'wb') as f:
        f.write(blob)
    used = sum(1 for b in blob if b & 15)
    print('data/map96.bin  %dx%d = %d bytes, %d πλακίδια με πόρο'
          % (N, N, len(blob), used))
    with open(os.path.join(DATA, 'nav.asm'), 'w') as f:
        f.write(nav_asm())
    print('data/nav.asm  εμπόδια: %s / %s'
          % (sorted(BLOCK_TER), sorted(BLOCK_RES)))
    with open(os.path.join(DATA, 'map96.json'), 'w') as f:
        json.dump({'size': N, 'byte': {'bits_4_7': 'terrain index',
                                       'bits_0_3': 'resource index, 0=none'},
                   'order': 'j*96 + i', 'bytes': len(blob)}, f, indent=1)
        f.write('\n')


if __name__ == '__main__':
    main()
