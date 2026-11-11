"""Έδαφος, πόροι και HUD -> δεδομένα Mode 0.

    python3 src/make_terrain.py

Βγάζει τρία ζευγάρια .bin/.asm στο data/ και τρεις προεπισκοπήσεις.

ΤΡΙΑ ΑΡΧΕΙΑ, ΓΙΑΤΙ ΖΟΥΝ ΣΕ ΔΙΑΦΟΡΕΤΙΚΟΥΣ ΧΡΟΝΟΥΣ

    terrain    μπαίνει όταν χτίζεται το φόντο, μία φορά ανά κύλιση
    resources  το ίδιο, αλλά ΠΑΝΩ στο έδαφος και με μάσκα
    hud        μία φορά στην αρχή, μετά μόνο οι αριθμοί αλλάζουν

Το HUD δεν έχει καμία δουλειά να φορτώνεται ξανά όταν αλλάζει πίστα· το
έδαφος και οι πόροι αλλάζουν ανά πίστα μαζί με τους δύο πολιτισμούς.

ΟΛΑ ΤΑ ΜΕΓΕΘΗ ΕΙΝΑΙ ΣΤΑΘΕΡΑ — ΔΕΝ ΧΡΕΙΑΖΕΤΑΙ ΠΙΝΑΚΑΣ

Αυτό είναι η διαφορά από τα κτίρια, που έχουν τρία μεγέθη και χρειάζονται
πίνακα με πλάτος/ύψος/μετατόπιση. Εδώ η θέση βγαίνει με πολλαπλασιασμό:

    πλακίδιο  index * 32       (αδιαφανές, 4 bytes x 8 γραμμές)
    πόρος     (index-1) * 128  (με μάσκα, 8 bytes x 16 γραμμές)
    HUD       index * 128      (με μάσκα, 8 bytes x 16 γραμμές)

ΓΙΑΤΙ (index-1) ΣΤΟΥΣ ΠΟΡΟΥΣ

Ο πόρος 0 είναι «τίποτα» και είναι η συντριπτική πλειοψηφία του χάρτη. Ο
βρόχος ΠΡΕΠΕΙ να τον προσπερνά ούτως ή άλλως — ένα πλήρως μασκαρισμένο
sprite κοστίζει όσο ένα δέντρο και ζωγραφίζει το τίποτα. Αφού ο έλεγχος
υπάρχει, η άδεια θέση στο αρχείο θα ήταν 128 bytes για το τίποτα.
"""
import json
import os

import gfx
import preview
import terrain as T

OUT = gfx.OUT
DATA = os.path.join(OUT, 'data')
PREVIEW = os.path.join(OUT, 'preview')

TILE_SZ = T.TILE_W // 2 * T.TILE_H            # αδιαφανές
RES_SZ = T.RES_W * T.RES_H                    # μάσκα + δεδομένα
HUD_SZ = T.HUD_W * T.HUD_H

HEAD = """; %(file)s — %(what)s, Amstrad CPC Mode 0
; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ από src/make_terrain.py — μην το πειράζεις με το χέρι.
;
; %(n)d εικόνες x %(sz)d bytes = %(bytes)d bytes.
%(note)s"""

MAP_NOTE = """;
; Ο ΧΑΡΤΗΣ ΕΙΝΑΙ ΕΝΑ BYTE ΑΝΑ ΠΛΑΚΙΔΙΟ
;
;       bits 0-3   τύπος εδάφους, 0-15
;       bits 4-7   πόρος, 0 = τίποτα
;
; 64x64 = 4.096 bytes. 96x96 = 9.216. Και τα δύο χωράνε σε μία τράπεζα.
"""


def dump(lines, blob, step=16):
    for r in range(0, len(blob), step):
        lines.append('  db ' + ','.join('#%02X' % b for b in blob[r:r + step]))


def write(stem, what, note, equs, blobs, labels, sz, extra=()):
    n = len(blobs)
    lines = [(HEAD % dict(file=stem + '.asm', what=what, n=n, sz=sz,
                          bytes=n * sz, note=note)).rstrip('\n')]
    lines += list(extra)
    lines.append('')
    for name, val, comment in equs:
        lines.append('%-18s equ %-4s ; %s' % (name, val, comment))
    lines += ['', '%s_gfx:' % stem]
    for label, blob in zip(labels, blobs):
        lines.append('  ; %s' % label)
        dump(lines, blob)
    lines.append('')
    with open(os.path.join(DATA, stem + '.bin'), 'wb') as f:
        for b in blobs:
            f.write(b)
    with open(os.path.join(DATA, stem + '.asm'), 'w') as f:
        f.write('\n'.join(lines))
    return n * sz


def build_terrain():
    blobs, imgs, equs, labels = [], [], [], []
    for i, (key, name, art, passable) in enumerate(T.TERRAIN):
        img = T.tile(art)
        blob = gfx.encode_opaque(img)
        assert len(blob) == TILE_SZ
        assert gfx.decode_opaque(blob, T.TILE_W, T.TILE_H) == img, key
        blobs.append(blob)
        imgs.append((key, img))
        labels.append('%s — %s' % (key, name))
        equs.append(('ter_' + key, i,
                     '%s%s' % (name, '' if passable else ', ΑΔΙΑΒΑΤΟ')))
    extra = [';', '; ΑΔΙΑΦΑΝΟ: χωρίς μάσκα, μπαίνει με LDI. Τίποτα δεν είναι',
             '; από κάτω του, οπότε η μάσκα θα ήταν διπλά bytes και διπλός',
             '; χρόνος για το ίδιο αποτέλεσμα.',
             MAP_NOTE.rstrip('\n'), '',
             'TILE_W             equ %-4d ; bytes ανά γραμμή — ΑΔΙΑΦΑΝΟ,'
             % (T.TILE_W // 2),
             ';                            άρα τόσα και στη μνήμη',
             'TILE_H             equ %-4d ; γραμμές' % T.TILE_H,
             'TILE_SZ            equ %-4d ; offset = index * TILE_SZ' % TILE_SZ]
    total = write('terrain', 'πλακίδια εδάφους', '', equs, blobs, labels,
                  TILE_SZ, extra)
    return total, imgs


def build_resources():
    blobs, imgs, equs, labels = [], [], [], []
    equs.append(('res_none', 0, 'τίποτα — ΔΕΝ ζωγραφίζεται, δεν έχει δεδομένα'))
    for i, (key, name, art, kind, amount) in enumerate(T.RESOURCES):
        if art is None:
            assert i == 0, 'μόνο η θέση 0 επιτρέπεται να είναι άδεια'
            continue
        img = T.res(art)
        blob = gfx.encode_masked(img)
        assert len(blob) == RES_SZ
        assert gfx.decode_masked(blob, T.RES_W, T.RES_H) == img, key
        blobs.append(blob)
        imgs.append((key, img))
        labels.append('%s — %s' % (key, name))
        equs.append(('res_' + key, i, '%s%s' % (
            name, ' (%s %d)' % (kind, amount) if kind else '')))
    extra = [';', '; Με μάσκα: κάθονται ΠΑΝΩ στο έδαφος και είναι ψηλότεροι',
             '; από το πλακίδιό τους — ένα δέντρο πατάει σε ένα πλακίδιο και',
             '; σκεπάζει το από πάνω. Βάση στη γραμμή 15.', '',
             'RES_W              equ %-4d ; bytes ΔΕΔΟΜΕΝΩΝ ανά γραμμή'
             % T.RES_W,
             ';                            (στη μνήμη η γραμμή είναι το ΔΙΠΛΟ)',
             'RES_H              equ %-4d ; γραμμές' % T.RES_H,
             'RES_SZ             equ %-4d ; offset = (index-1) * RES_SZ'
             % RES_SZ]
    total = write('resources', 'πόροι του χάρτη', '', equs, blobs, labels,
                  RES_SZ, extra)
    return total, imgs


def build_hud():
    blobs, imgs, equs, labels = [], [], [], []
    i = 0
    for key, name, art in T.ICONS:
        img = T.hud(art)
        blob = gfx.encode_masked(img)
        assert gfx.decode_masked(blob, T.HUD_W, T.HUD_H) == img, key
        blobs.append(blob)
        imgs.append((key, img))
        labels.append('%s — %s' % (key, name))
        equs.append(('hud_' + key, i, name))
        i += 1
    equs.append(('', '', ''))
    for key, name, art, who in T.COMMANDS:
        img = T.hud(art)
        blob = gfx.encode_masked(img)
        assert gfx.decode_masked(blob, T.HUD_W, T.HUD_H) == img, key
        blobs.append(blob)
        imgs.append((key, img))
        labels.append('%s — %s' % (key, name))
        equs.append(('cmd_' + key, i, '%s [%s]' % (name, who)))
        i += 1
    equs = [e for e in equs if e[0]]
    extra = [';', '; ΕΝΑ ΜΕΓΕΘΟΣ ΓΙΑ ΟΛΟ ΤΟ HUD: 8x16 pixels = 16x16 ΜΟΝΑΔΕΣ',
             '; ΟΘΟΝΗΣ, δηλαδή τετράγωνο. Ίδιο με τη μονάδα — ίδιο blit.',
             ';',
             '; Οι 8 πρώτες είναι ΚΑΤΑΣΤΑΣΗ (δείχνουν), οι 16 επόμενες είναι',
             '; ΕΝΤΟΛΕΣ (πατιούνται). Κανένα δεν αγγίζει τα pens 2 και 3, που',
             '; είναι της ομάδας: το HUD βγαίνει ίδιο με ή χωρίς τον πίνακα',
             '; παίκτη, οπότε δεν υπάρχει λάθος διαδρομή να διαλέξεις.', '',
             'HUD_W              equ %-4d ; bytes ΔΕΔΟΜΕΝΩΝ ανά γραμμή'
             % T.HUD_W,
             ';                            (στη μνήμη η γραμμή είναι το ΔΙΠΛΟ)',
             'HUD_H              equ %-4d ; γραμμές' % T.HUD_H,
             'HUD_SZ             equ %-4d ; offset = index * HUD_SZ' % HUD_SZ]
    total = write('hud', 'εικονίδια κατάστασης και εντολών', '', equs, blobs,
                  labels, HUD_SZ, extra)
    return total, imgs


def tiled(img, nx=3, ny=3):
    h, w = len(img), len(img[0])
    return [[img[y % h][x % w] for x in range(w * nx)] for y in range(h * ny)]


def main():
    os.makedirs(DATA, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)

    t_bytes, t_imgs = build_terrain()
    r_bytes, r_imgs = build_resources()
    h_bytes, h_imgs = build_hud()

    # Το έδαφος κρίνεται ΜΟΝΟ πλακιασμένο: μια κουκκίδα στην ακμή γίνεται
    # γραμμή όταν το πλακίδιο μπει δίπλα στον εαυτό του.
    preview.contact_sheet(os.path.join(PREVIEW, 'terrain.png'),
                          [(k, tiled(im)) for k, im in t_imgs], zoom=4, cols=8,
                          title='έδαφος 8x8, κάθε ένα 3x3 φορές — οι αρμοί',
                          grid=False)
    # Οι πόροι κρίνονται πάνω στο έδαφος που θα πατήσουν.
    def on(bg, art):
        b = T.tile(bg)
        return gfx.stamp([list(b[j % T.TILE_H]) for j in range(T.RES_H)], art)
    water = {'fish', 'whale'}
    preview.contact_sheet(
        os.path.join(PREVIEW, 'resources.png'),
        [(k, on(T.WATER_SHALLOW if k in water else T.GRASS, im))
         for k, im in r_imgs], zoom=6, cols=8,
        title='πόροι 8x16 με μάσκα, πάνω στο έδαφός τους', grid=False)
    preview.contact_sheet(
        os.path.join(PREVIEW, 'hud.png'),
        [(k, gfx.stamp(gfx.blank(T.HUD_W, T.HUD_H, gfx.PEN['t']), im))
         for k, im in h_imgs], zoom=6, cols=8,
        title='HUD 8x16 — 8 κατάστασης, 16 εντολών, πάνω σε κουμπί',
        grid=False)

    doc = {
        'map_byte': {'bits_0_3': 'έδαφος 0-15', 'bits_4_7': 'πόρος, 0=τίποτα'},
        'terrain': [{'key': k, 'name': n, 'passable': p, 'index': i}
                    for i, (k, n, _, p) in enumerate(T.TERRAIN)],
        'resources': [{'key': k, 'name': n, 'index': i, 'gathers': kind,
                       'amount': amt}
                      for i, (k, n, _, kind, amt) in enumerate(T.RESOURCES)],
        'hud': ([{'key': k, 'name': n, 'index': i, 'role': 'κατάσταση'}
                 for i, (k, n, _) in enumerate(T.ICONS)] +
                [{'key': k, 'name': n, 'index': len(T.ICONS) + i,
                  'role': 'εντολή', 'for': who}
                 for i, (k, n, _, who) in enumerate(T.COMMANDS)]),
        'bytes': {'terrain': t_bytes, 'resources': r_bytes, 'hud': h_bytes},
    }
    with open(os.path.join(OUT, 'terrain.json'), 'w') as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write('\n')

    tot = t_bytes + r_bytes + h_bytes
    print('έδαφος    %2d x %3d = %5d bytes' % (len(t_imgs), TILE_SZ, t_bytes))
    print('πόροι     %2d x %3d = %5d bytes' % (len(r_imgs), RES_SZ, r_bytes))
    print('HUD       %2d x %3d = %5d bytes' % (len(h_imgs), HUD_SZ, h_bytes))
    print('                     %5d bytes (%.1f KB) — μια τράπεζα έχει 16 KB'
          % (tot, tot / 1024.0))


if __name__ == '__main__':
    main()
