"""Τα κτίρια των οκτώ πολιτισμών -> ένα αρχείο ανά πολιτισμό.

    python3 src/make_buildings.py            # και οι οκτώ
    python3 src/make_buildings.py greek      # ένας

ΓΙΑΤΙ ΕΝΑ ΑΡΧΕΙΟ ΑΝΑ ΠΟΛΙΤΙΣΜΟ ΚΑΙ ΟΧΙ ΑΝΑ ΚΤΙΡΙΟ

Μια πίστα φορτώνει τα σετ των πολιτισμών που παίζουν σε αυτήν — δύο. Με ένα
αρχείο ανά κτίριο θα ήταν 66 ανοίγματα αρχείου· έτσι είναι δύο.

ΓΙΑΤΙ ΧΡΕΙΑΖΕΤΑΙ ΠΙΝΑΚΑΣ

Τα κτίρια ΔΕΝ έχουν ίδιο μέγεθος: το πλάτος είναι η κάτοψη (8, 16, 24 ή 32
pixels για 1x1 ώς 4x4 πλακίδια) και το ύψος είναι ΟΣΟ ΧΡΕΙΑΖΕΤΑΙ — ο καμβάς
κόβεται από πάνω. Δεν μπορεί να υπολογιστεί η θέση τους με πολλαπλασιασμό,
όπως στις μονάδες — μπαίνει πίνακας με πλάτος, ύψος και μετατόπιση ανά
καταχώριση.
"""
import json
import os
import sys

import bstyle
import buildings as B
import gfx
import preview

OUT = gfx.OUT
DATA = os.path.join(OUT, 'data')
PREVIEW = os.path.join(OUT, 'preview')

AGE_GR = {1: 'Λίθινη', 2: 'Εργαλείων', 3: 'Χαλκού', 4: 'Σιδήρου'}


def entries():
    """-> [(κλειδί, όνομα, εποχή, μέγεθος)] με τη σειρά του αρχείου."""
    out = []
    for key, name, size, ages, _ in B.BUILDINGS:
        for age in ages:
            out.append((key, name, age, size))
    return out


ASM_HEAD = """; buildings_%(c)s.asm — %(name)s, Amstrad CPC Mode 0
; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ από src/make_buildings.py — μην το πειράζεις με το χέρι.
;
; %(n)d εικόνες, %(bytes)d bytes. Δεδομένα ΜΕ ΜΑΣΚΑ, πλεγμένα mask,data ανά
; ζευγάρι pixels: AND mask / OR data.
;
; ΙΣΟΜΕΤΡΙΚΑ. Το πλάτος είναι η κάτοψη (1x1 = 8 pixels ... 4x4 = 32) και
; το ύψος όσο χρειάζεται η κάθε εικόνα, οπότε η θέση ΔΕΝ βγαίνει με
; πολλαπλασιασμό.
;
; ΤΟΠΟΘΕΤΗΣΗ: η κάτω γραμμή της εικόνας είναι η κάτω γραμμή του κουτιού του
; ΜΠΡΟΣΤΙΝΟΥ πλακιδίου (i0+n-1, j0+n-1). Οριζόντια, η εικόνα αρχίζει
; (n-1)*2 bytes αριστερά από το κουτί του ΠΙΣΩ πλακιδίου (i0, j0). Ο πίνακας %(c)s_table δίνει ανά καταχώριση:
;
;       db πλάτος_σε_bytes_ΔΕΔΟΜΕΝΩΝ, ύψος_σε_γραμμές
;       dw μετατόπιση από το %(c)s_gfx
;
; Η γραμμή στη ΜΝΗΜΗ είναι το ΔΙΠΛΟ του πλάτους δεδομένων (μάσκα + δεδομένα).
;
; ΕΠΟΧΕΣ: μια εικόνα ισχύει ώσπου να έρθει η επόμενη. Ο πίνακας %(c)s_age
; δίνει, για κάθε κτίριο και κάθε εποχή 1-4, τη ΘΕΣΗ στον πίνακα — ή #FF αν
; το κτίριο δεν υπάρχει ακόμα σε εκείνη την εποχή.
"""


def write_culture(culture, name, ents, blobs, outdir):
    lines = []
    total = sum(len(b) for b in blobs)
    lines.append(ASM_HEAD % dict(c=culture, name=name, n=len(ents),
                                 bytes=total))
    lines.append('')
    lines.append('%s_N          equ %d   ; καταχωρίσεις' % (culture, len(ents)))
    lines.append('')
    for i, (key, _, age, _) in enumerate(ents):
        lines.append('bld_%-22s equ %d'
                     % ('%s_%s' % (key, bstyle.AGE_NAMES[age]), i))
    lines += ['', '%s_table:' % culture]
    off = 0
    for (key, _, age, size), blob in zip(ents, blobs):
        w = B.SIZES[size][1]
        h = len(blob) // w
        lines.append('  db %d,%d' % (w // 2, h))
        lines.append('  dw %d        ; %s %s' % (off, key,
                                                 bstyle.AGE_NAMES[age]))
        off += len(blob)

    # πίνακας εποχών: 4 bytes ανά κτίριο
    lines += ['', '; 4 bytes ανά κτίριο — η θέση που ισχύει σε κάθε εποχή,',
              '; ή #FF αν το κτίριο δεν υπάρχει ακόμα.', '%s_age:' % culture]
    idx = {}
    for i, (key, _, age, _) in enumerate(ents):
        idx[(key, age)] = i
    for key, _, _, ages, _ in B.BUILDINGS:
        cov = B.covers(ages)
        row = []
        for age in (1, 2, 3, 4):
            row.append('#FF' if age not in cov else str(idx[(key, cov[age])]))
        lines.append('  db %-24s ; %s' % (','.join(row), key))

    lines += ['', '%s_gfx:' % culture]
    for (key, _, age, _), blob in zip(ents, blobs):
        lines.append('  ; %s %s' % (key, bstyle.AGE_NAMES[age]))
        for r in range(0, len(blob), 16):
            lines.append('  db ' + ','.join('#%02X' % b for b in blob[r:r + 16]))
    lines.append('')

    with open(os.path.join(outdir, 'buildings_%s.bin' % culture), 'wb') as f:
        for b in blobs:
            f.write(b)
    with open(os.path.join(outdir, 'buildings_%s.asm' % culture), 'w') as f:
        f.write('\n'.join(lines))
    return total


def main():
    want = [a for a in sys.argv[1:] if not a.startswith('--')]
    os.makedirs(DATA, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)

    cultures = [c for c in bstyle.CULTURES if not want or c[0] in want]
    assert cultures, 'κανένας πολιτισμός: %s' % want

    ents = entries()
    doc = {'ages': {str(k): v for k, v in AGE_GR.items()},
           'projection': 'isometric 2:1, tile = diamond 8x8 pixels',
           'sizes': {k: {'tiles': v[0], 'w': v[1], 'max_h': v[2]}
                     for k, v in B.SIZES.items()},
           'rule': ('Μια εικόνα ισχύει ώσπου να έρθει η επόμενη. Κτίριο που '
                    'δεν υπάρχει ακόμα σε μια εποχή δεν έχει καθόλου εικόνα.'),
           'buildings': [], 'cultures': []}
    for key, name, size, ages, _ in B.BUILDINGS:
        doc['buildings'].append({
            'key': key, 'name': name, 'size': size,
            'footprint': B.SIZES[size][0],
            'w': B.SIZES[size][1],
            'drawn_at_ages': ages,
            'age_to_variant': {str(a): bstyle.AGE_NAMES[v]
                               for a, v in B.covers(ages).items()},
        })

    grand = 0
    for culture, name, _, _, shape, _ in cultures:
        blobs, imgs = [], []
        for key, _, age, size in ents:
            img = B.render(key, culture, age)
            blobs.append(gfx.encode_masked(img))
            imgs.append(('%s %s' % (key[:10], bstyle.AGE_NAMES[age][:5]), img))
        # επαλήθευση: όλο το blob πίσω σε pens
        bad = 0
        for (key, _, age, size), blob, (_, img) in zip(ents, blobs, imgs):
            w, h = len(img[0]), len(img)
            got = gfx.decode_masked(blob, w, h)
            for a, b in zip(got, img):
                bad += sum(1 for p, q in zip(a, b) if p != q)
        assert bad == 0, '%s: %d pixels δεν γύρισαν σωστά' % (culture, bad)

        total = write_culture(culture, name, ents, blobs, DATA)
        grand += total
        sheet(os.path.join(PREVIEW, 'buildings_%s.png' % culture), imgs,
              '%s — %d κτίρια, στέγη %s' % (name, len(imgs), shape))
        doc['cultures'].append({'key': culture, 'name': name,
                                'roof': shape, 'images': len(ents),
                                'bytes': total})
        print('%-11s %-14s %2d εικόνες  %6d bytes (%.1f KB)'
              % (culture, name, len(ents), total, total / 1024.0))

    with open(os.path.join(OUT, 'buildings.json'), 'w') as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print('\n%d πολιτισμοί, %d bytes. Δύο σετ ανά πίστα = %.1f KB.'
          % (len(cultures), grand, 2 * grand / len(cultures) / 1024.0))


def sheet(path, imgs, title):
    """Τα κτίρια έχουν τέσσερα πλάτη και ελεύθερο ύψος — στοιχίζονται στη
    ΒΑΣΗ, όπως στον χάρτη, πάνω σε γρασίδι για να φαίνεται η κάτοψη."""
    from PIL import Image, ImageDraw
    z, cols = 3, 9
    MW, MH = 32, max(len(im) for _, im in imgs)
    cw, ch = MW * 2 * z + 10, MH * z + 15
    rows = (len(imgs) + cols - 1) // cols
    im = Image.new('RGB', (cols * cw + 12, 26 + rows * ch), (36, 70, 40))
    d = ImageDraw.Draw(im)
    d.text((8, 8), title, fill=(255, 206, 92))
    for i, (lab, img) in enumerate(imgs):
        ox = 6 + (i % cols) * cw
        oy = 24 + (i // cols) * ch
        w, h = len(img[0]), len(img)
        preview.draw(d, img, ox + (MW - w) * z, oy + (MH - h) * z, z)
        d.text((ox, oy + MH * z + 2), lab[:16], fill=(220, 222, 230))
    im.save(path)


if __name__ == '__main__':
    main()
