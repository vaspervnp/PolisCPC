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

Τα κτίρια ΔΕΝ είναι στον χάρτη: είναι αντικείμενα με δική τους λίστα (M7).
Κάτω από τις κατόψεις τους ο χάρτης έχει σκέτο έδαφος.
"""
import json
import os

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


def main():
    grd, res = mockup.make_map()
    blob = encode(grd, res)
    assert len(blob) == N * N
    with open(os.path.join(DATA, 'map96.bin'), 'wb') as f:
        f.write(blob)
    used = sum(1 for b in blob if b & 15)
    print('data/map96.bin  %dx%d = %d bytes, %d πλακίδια με πόρο'
          % (N, N, len(blob), used))
    with open(os.path.join(DATA, 'map96.json'), 'w') as f:
        json.dump({'size': N, 'byte': {'bits_4_7': 'terrain index',
                                       'bits_0_3': 'resource index, 0=none'},
                   'order': 'j*96 + i', 'bytes': len(blob)}, f, indent=1)
        f.write('\n')


if __name__ == '__main__':
    main()
