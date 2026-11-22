#!/bin/sh
# Polis: χτίζει το παιχνίδι.
#
#   ./game/build.sh
#
# Βγάζει στο build/:
#   polis.dsk   δισκέτα με POLIS.BIN (κεφαλίδα AMSDOS) — RUN"POLIS
#   polis.sna   snapshot που ξεκινάει κατευθείαν, για γρήγορη δοκιμή
#   polis.sym   σύμβολα για τον debugger του emulator
#   m0_bars.sna η οθόνη ελέγχου του M0: οι 16 λωρίδες της παλέτας
#
# Η παλέτα έρχεται από το palette.asm, που το παράγει το src/make_sprites.py.
set -e
cd "$(dirname "$0")/.."
mkdir -p build
rm -f build/polis.dsk
# Πρώτο πέρασμα (M13): μόνο ο κώδικας της C7 στο build/c7.bin (και, M14, του
# init_z στο build/init.bin), για να μπουν συμπιεσμένοι στο POLIS.BIN από τα
# κανονικά περάσματα.
rasm game/main.asm -DC7RAW=1 -o build/c7raw -sz > /dev/null
rasm game/main.asm -o build/polis -s -sz
# (M20) τα σύμβολα των μενού για το snapshot — εδώ το polis.sym είναι «τράπεζα:διεύθυνση ΟΝΟΜΑ»
grep -E ' ((UM|HB|UI_IC)_[A-Z0-9_]+|HUD_MUS|FX_TICK|FX_V4|FX_DEC|MUS_GAME|UI_BTN|SN_CTR|SN_CT2|SN_CJ|SN_CI|SN_HOME|UI_END|UI[A-K]_END|SND[A-C]_END)$' build/polis.sym | awk '{split($1, a, ":"); if (a[1] != "260") print tolower($2) " equ #" a[2]}' > build/ui_sym.asm   # (όχι του κύριου κώδικα, 260: M22 hudvis.asm)
grep -q '^um_go ' build/ui_sym.asm || { echo 'build/ui_sym.asm: τα σύμβολα των μενού;'; exit 1; }
cp build/polis.sym build/polis_dsk.sym
rasm game/main.asm -DSNA=1 -o build/polis -sz -v2 -ss
# (M21) ο κύριος κώδικας ΙΔΙΟΣ στη δισκέτα και στο snapshot: οι έλεγχοι
# διαβάζουν τα σύμβολα του ενός και τρέχουν το άλλο (και το BOOT του πρώτου
# περάσματος καλεί τον κύριο κώδικα)
python3 - <<'PY'
def syms(p):
    out = {}
    for line in open(p):
        f = line.split()
        if len(f) >= 3 and f[2] == 'B0' and not f[1].startswith('#1'):
            v = int(f[1][1:], 16)
            if v < 0x3F00:
                out[f[0]] = v
    return out
a, b = syms('build/polis_dsk.sym'), syms('build/polis.sym')
bad = sorted((a[k], k, b[k]) for k in a if k in b and a[k] != b[k])
assert not bad, 'δισκέτα / snapshot: άλλες διευθύνσεις, πρώτη %s στο #%04X / #%04X' % (bad[0][1], bad[0][0], bad[0][2])
PY
rasm game/main.asm -DSNA=1 -DBARS=1 -o build/m0_bars -sz -v2
cmp -s build/c7.bin build/c7chk.bin || { echo 'ο κώδικας της C7 άλλαξε ανάμεσα στα περάσματα (build/c7.bin)'; exit 1; }
cmp -s build/boot.bin build/bootchk.bin || { echo 'ο κώδικας του BOOT άλλαξε ανάμεσα στα περάσματα (build/boot.bin)'; exit 1; }
cmp -s build/menu.bin build/menuchk.bin || { echo 'ο κώδικας του μενού άλλαξε ανάμεσα στα περάσματα (build/menu.bin)'; exit 1; }
cmp -s build/init.bin build/initchk.bin || { echo 'ο κώδικας του init_z άλλαξε ανάμεσα στα περάσματα (build/init.bin)'; exit 1; }
# Το POLIS.BIN φορτώνεται στο #0040. Ό,τι χρειάζεται το παιχνίδι όσο τρέχει
# (ως το code_end) πρέπει να τελειώνει πριν το παράθυρο τράπεζας #4000· τα
# συμπιεσμένα της εκκίνησης ακολουθούν και μπορούν να το περάσουν (κύρια RAM,
# διαβάζονται μόνο πριν γραφτεί το HUD εκεί), αλλά όχι το #8000 (ο χάρτης).
(cd build && rm -f POLIS.BIN && iDSK polis.dsk -g POLIS.BIN >/dev/null 2>&1)
python3 - <<'PY'
d = open('build/POLIS.BIN', 'rb').read()
size = d[24] | d[25] << 8
end = 0x40 + size
sym = {}
for line in open('build/polis.sym'):
    p = line.split()
    if len(p) >= 2 and p[1].startswith('#'):
        sym[p[0]] = int(p[1][1:], 16)
code = sym['CODE_END']
print('POLIS.BIN: %d bytes, #0040-#%04X· κώδικας ως #%04X (ελεύθερα ώς το '
      'SQ_N #3F00: %d)' % (size, end - 1, code - 1, 0x3F00 - code))
assert code <= 0x3F00, 'ο κώδικας μπαίνει στις ομάδες (SQ_N, #3F00, M15)'
assert end <= 0x8000, 'τα δεδομένα εκκίνησης φτάνουν στον χάρτη #8000'
# το map_z, όπως το βλέπει ο κώδικας: το «ld hl,map_z» στην αρχή του start
# (di, ld sp,nn, ld hl,nn) — το .sym έχει τις ασυμπίεστες θέσεις μετά από LZX0
body = d[128:]
assert body[0] == 0xF3 and body[1] == 0x31 and body[4] == 0x21, 'start'
map_z = body[5] | body[6] << 8
assert map_z <= 0x7A30, 'το POLIS.BIN φτάνει στο BOOT (#7A30, main.asm) πριν από τον χάρτη (map_z, ο τελευταίος: αποσυμπιέζεται πριν αντιγραφεί το BOOT)'
print('ως τον χάρτη: #%04X (ελεύθερα ώς το BOOT: %d· ως το #8000: %d)' % (map_z - 1, 0x7A30 - map_z, 0x8000 - end))
PY
# Τα αρχεία χωρίς κεφαλίδα AMSDOS (M12, src/dsk.py): οι εποχές ανά
# πολιτισμό και ο οπλίτης, συμπιεσμένα ZX0 (M13: τα φορτώνει το disk_load
# στην οθόνη, και το dzx0 στη θέση τους).
cat build/ui.bin build/ui_a.bin build/ui_b.bin build/ui_c.bin build/ui_d.bin build/ui_e.bin build/ui_f.bin build/ui_g.bin build/ui_h.bin build/ui_i.bin build/ui_j.bin build/ui_k.bin data/ui_end.bin data/ic_c5a.bin data/ic_c5b.bin > build/ui_all.bin   # (M20)
python3 src/dsk.py build/polis.dsk \
    $(for c in E G B A R P F K; do echo --zx0 AGE3$c.BIN data/age3$c.bin --zx0 AGE4$c.BIN data/age4$c.bin; done) \
    --zx0 HOPL.BIN data/c5_slot3.bin \
    $(for c in G E; do for n in 1 2 3 4; do echo --zx0 L$c$n.BIN data/l$(echo $c | tr GE ge)$n.bin; done; done) \
    --zx0 TITLE.BIN data/title.bin \
    --zx0 MENU.BIN build/menu.bin \
    --zx0 TUTOR.BIN build/tutor.bin \
    --zx0 UI.BIN build/ui_all.bin \
    --empty PROG.BIN 1024 \
    --empty SAVE.BIN 43008
ls -l build/polis.dsk build/polis.sna build/m0_bars.sna
