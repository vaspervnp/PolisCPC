"""Όλες οι μονάδες -> δεδομένα Mode 0 για Amstrad CPC.

    python3 src/make_sprites.py              # όλα
    python3 src/make_sprites.py knight       # μία μονάδα
    python3 src/make_sprites.py --mirror     # και τις όψεις W, έτοιμες

Βγάζει ΕΝΑ αρχείο ανά μονάδα. Δεν μπαίνουν όλες σε έναν CPC ταυτόχρονα και
δεν χρειάζεται: ένα σενάριο φορτώνει τις μονάδες που παίζουν σε αυτό.
"""
import json
import os
import sys

import cpcimg
import gfx
import mounts
import preview
import units

OUT = gfx.OUT
TMP = os.environ.get('TMPDIR', '/tmp')
DATA = os.path.join(OUT, 'data')
PREVIEW = os.path.join(OUT, 'preview')


def mounted_set(spec):
    name = spec[0]
    s = gfx.SpriteSet(name, mounts.W, mounts.H, note=spec[1])
    for f in mounts.FACINGS:
        for ph in range(4):
            s.add(mounts.mounted(spec, f, ph), '%s_walk_%s%d' % (name, f, ph),
                  'walk_' + f)
    for f in mounts.FACINGS:
        for ph in range(2):
            s.add(mounts.mounted(spec, f, 0 if ph == 0 else 1, attack=bool(ph)),
                  '%s_atk_%s%d' % (name, f, ph), 'atk_' + f)
    for i, img in enumerate(units.die_frames(
            (name, spec[1], spec[3], None, None, {}))):
        wide = gfx.blank(mounts.W, mounts.H, None)
        gfx.stamp(wide, img, 2, 0)
        s.add(wide, '%s_die%d' % (name, i), 'die')
    return s


def siege_set(spec):
    name = spec[0]
    s = gfx.SpriteSet(name, mounts.W, mounts.H, note=spec[1])
    for f in mounts.FACINGS:
        for ph in range(4):
            s.add(mounts.machine(spec, f, ph), '%s_walk_%s%d' % (name, f, ph),
                  'walk_' + f)
    for f in mounts.FACINGS:
        for ph in range(2):
            s.add(mounts.machine(spec, f, ph), '%s_atk_%s%d' % (name, f, ph),
                  'atk_' + f)
    for i in range(3):
        img = mounts.machine(spec, 's', 0)
        s.add(gfx.shift(img, 0, i + 1), '%s_die%d' % (name, i), 'die')
    return s


def add_west(s):
    """Προσθέτει τις όψεις W ως καθρέφτισμα των E, στο ΤΕΛΟΣ του σετ.

    Στο τέλος ώστε τα υπάρχοντα tags να μείνουν συνεχόμενα και οι δείκτες των
    άλλων κινήσεων να μην κουνηθούν. Κοστίζει ~29% παραπάνω μνήμη και γλιτώνει
    τον πίνακα καθρεφτίσματος και τους κύκλους του.
    """
    west = [(n, f, t) for n, f, t in zip(s.names, s.frames, s.tags)
            if t.endswith('_e')]
    for n, f, t in west:
        s.add(gfx.mirror(f), n.replace('_e', '_w'), t[:-2] + '_w')
    return s


def all_sets():
    out = [units.build(sp) for sp in units.FOOT]
    out += [mounted_set(sp) for sp in mounts.MOUNTED]
    out += [siege_set(sp) for sp in mounts.SIEGE]
    return out


# ------------------------------------------------------------------ έξοδος

ASM_HEAD = """; %(name)s.asm — %(note)s, Amstrad CPC Mode 0
; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ από src/make_sprites.py — μην το πειράζεις με το χέρι.
;
; %(n)d καρέ, %(w)d x %(h)d pixels (%(units)d x %(h)d μονάδες οθόνης).
; Δεδομένα ΜΕ ΜΑΣΚΑ, πλεγμένα mask,data ανά ζευγάρι pixels:
;
;       AND mask  /  OR data
;
; %(dw)d bytes ΔΕΔΟΜΕΝΩΝ ανά γραμμή — η γραμμή στη μνήμη είναι το ΔΙΠΛΟ,
; %(rw)d bytes. Το %(name)s_W παρακάτω είναι bytes δεδομένων.
;
;       διεύθυνση = %(name)s_gfx + καρέ * %(name)s_SZ
;
; Οι κινήσεις είναι ΣΥΝΕΧΟΜΕΝΕΣ: παίζεις μία με «πρώτο καρέ + πλήθος».
; Η όψη W δεν υπάρχει — είναι καθρέφτισμα της E.
"""


def write_unit(s, outdir):
    dw = s.w // 2
    blob = bytearray()
    lines = [ASM_HEAD % dict(name=s.name, note=s.note, n=len(s.frames),
                             w=s.w, h=s.h, units=s.w * 2, dw=dw, rw=dw * 2),
             '',
             '%-14s equ %-5d ; bytes ΔΕΔΟΜΕΝΩΝ ανά γραμμή' % (s.name + '_W', dw),
             '%-14s equ %-5d ; γραμμές' % (s.name + '_H', s.h),
             '%-14s equ %-5d ; bytes ανά καρέ (μάσκα+δεδομένα)'
             % (s.name + '_SZ', s.bytes_per_frame()),
             '%-14s equ %-5d ; καρέ' % (s.name + '_N', len(s.frames)), '']
    for tag, first, count in s.tag_ranges():
        lines.append('%-22s equ %-4d ; %d καρέ'
                     % ('%s_%s' % (s.name, tag), first, count))
    lines += ['', '%s_gfx:' % s.name]
    for name, frame in zip(s.names, s.frames):
        data = gfx.encode_masked(frame)
        assert len(data) == s.bytes_per_frame()
        blob += data
        lines.append('  ; %s' % name)
        for r in range(0, len(data), 16):
            lines.append('  db ' + ','.join('#%02X' % b for b in data[r:r + 16]))
    lines.append('')
    with open(os.path.join(outdir, '%s.bin' % s.name), 'wb') as f:
        f.write(blob)
    with open(os.path.join(outdir, '%s.asm' % s.name), 'w') as f:
        f.write('\n'.join(lines))
    return bytes(blob)


def verify(s, blob):
    """Αποκωδικοποιεί ΟΛΟ το blob πίσω σε pens και το συγκρίνει.

    Οι ισχυρισμοί του cpcimg δένουν ήδη κωδικοποιητή και αποκωδικοποιητή· αυτό
    πιάνει τα άλλα λάθη — λάθος μήκος καρέ, λάθος σειρά, μάσκα ανάποδα.
    """
    sz, bad = s.bytes_per_frame(), 0
    for i, frame in enumerate(s.frames):
        got = gfx.decode_masked(blob[i * sz:(i + 1) * sz], s.w, s.h)
        for a, b in zip(got, frame):
            bad += sum(1 for p, q in zip(a, b) if p != q)
    assert len(blob) == sz * len(s.frames)
    return bad


def write_palette():
    lines = ['GIMP Palette', 'Name: Polis CPC Mode 0', 'Columns: 4',
             '# Τα 16 pens. Η στήλη FW είναι ο αριθμός για INK / SCR SET INK.',
             '# Το pen 0 ΔΕΝ ζωγραφίζεται ποτέ: είναι η μάσκα.', '#']
    for pen, (ch, nm, fw, use) in enumerate(gfx.PALETTE):
        r, g, b = gfx.RGB[pen]
        lines.append('%3d %3d %3d\tpen %02d  FW %02d  %-14s %s  %s'
                     % (r, g, b, pen, fw, nm, ch, use))
    with open(os.path.join(OUT, 'palette.gpl'), 'w') as f:
        f.write('\n'.join(lines) + '\n')

    asm = ['; palette.asm — τα 16 INK και οι πίνακες χρωμάτων παικτών.',
           '; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ — μην το πειράζεις με το χέρι.',
           ';',
           '; Το pen 0 είναι η μάσκα: βάλε το ό,τι χρώμα θες για φόντο χάρτη.',
           '',
           'polis_inks:',
           '  db ' + ','.join(str(f) for f in gfx.FW)
           + '   ; firmware numbers, pen 0..15', '']
    asm += ['; Χρώμα παίκτη: ο πίνακας αλλάζει ΜΟΝΟ τα pens %d και %d.'
            % (gfx.TEAM_HI, gfx.TEAM_LO),
            '; Πέρνα τα δεδομένα του sprite μία φορά στο φόρτωμα, pen προς pen.',
            '; ΟΧΙ αλλαγή του INK — τότε θα άλλαζαν ΟΛΟΙ οι παίκτες μαζί.', '']
    for i, (nm, hi, lo) in enumerate(gfx.TEAMS):
        asm.append('team_%-8s db %s   ; %s'
                   % (nm + ':', ','.join(str(v) for v in gfx.team_table(i)), nm))
    asm.append('')
    with open(os.path.join(OUT, 'palette.asm'), 'w') as f:
        f.write('\n'.join(asm))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    mirror = '--mirror' in sys.argv
    os.makedirs(DATA, exist_ok=True)
    os.makedirs(PREVIEW, exist_ok=True)

    sets = all_sets()
    if args:
        sets = [s for s in sets if s.name in args]
        assert sets, 'καμία μονάδα: %s' % args

    doc = {'palette': [{'pen': i, 'char': p[0], 'firmware': p[2],
                        'name': p[1], 'rgb': '#%02X%02X%02X' % gfx.RGB[i],
                        'use': p[3]} for i, p in enumerate(gfx.PALETTE)],
           'teams': [{'name': n, 'table': gfx.team_table(i)}
                     for i, (n, _, _) in enumerate(gfx.TEAMS)],
           'units': []}

    total = 0
    by_cat = {}
    for s in sets:
        if mirror:
            add_west(s)
        blob = write_unit(s, DATA)
        bad = verify(s, blob)
        assert bad == 0, '%s: %d pixels δεν γύρισαν σωστά' % (s.name, bad)
        total += len(blob)
        by_cat.setdefault(s.note, []).append(s.name)
        doc['units'].append({
            'name': s.name, 'category': s.note,
            'pixels': {'w': s.w, 'h': s.h},
            'screen_units': {'w': s.w * 2, 'h': s.h},
            'frames': len(s.frames),
            'data_bytes_per_row': s.w // 2,
            'row_bytes_in_memory': s.w,
            'bytes_per_frame': s.bytes_per_frame(),
            'total_bytes': len(blob),
            'animations': [{'tag': t, 'first': i, 'count': n}
                           for t, i, n in s.tag_ranges()],
            'frame_names': s.names,
        })
        gfx_sheet = s.sheet(cols=12)
        preview.contact_sheet(
            os.path.join(PREVIEW, '%s.png' % s.name),
            [(n, f) for n, f in zip(s.names, s.frames)],
            zoom=4, cols=12, title='%s — %s, %d καρέ'
            % (s.name, s.note, len(s.frames)))
        print('%-11s %-13s %2d καρέ  %dx%-2d  %4d bytes/καρέ  %6d σύνολο'
              % (s.name, s.note, len(s.frames), s.w, s.h,
                 s.bytes_per_frame(), len(blob)))

    write_palette()
    with open(os.path.join(OUT, 'sprites.json'), 'w') as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
        f.write('\n')

    print()
    for cat, names in by_cat.items():
        print('%-14s %s' % (cat, ', '.join(names)))
    print('\n%d μονάδες, %d bytes συνολικά (%.1f KB)'
          % (len(sets), total, total / 1024.0))


if __name__ == '__main__':
    main()
