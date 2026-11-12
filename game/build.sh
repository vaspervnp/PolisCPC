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
# Πρώτο πέρασμα (M13): μόνο ο κώδικας της C7 στο build/c7.bin, για να μπει
# συμπιεσμένος στο POLIS.BIN από τα κανονικά περάσματα.
rasm game/main.asm -DC7RAW=1 -o build/c7raw -sz > /dev/null
rasm game/main.asm -o build/polis -s -sz
rasm game/main.asm -DSNA=1 -o build/polis -sz -v2 -ss
rasm game/main.asm -DSNA=1 -DBARS=1 -o build/m0_bars -sz -v2
cmp -s build/c7.bin build/c7chk.bin || { echo 'ο κώδικας της C7 άλλαξε ανάμεσα στα περάσματα (build/c7.bin)'; exit 1; }
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
      '#4000: %d)' % (size, end - 1, code - 1, 0x4000 - code))
assert code <= 0x4000, 'ο κώδικας μπαίνει στο παράθυρο τράπεζας #4000'
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
python3 src/dsk.py build/polis.dsk \
    $(for c in E G B A R P F K; do echo --zx0 AGE3$c.BIN data/age3$c.bin --zx0 AGE4$c.BIN data/age4$c.bin; done) \
    --zx0 HOPL.BIN data/c5_slot3.bin \
    $(for c in G E; do for n in 1 2 3 4; do echo --zx0 L$c$n.BIN data/l$(echo $c | tr GE ge)$n.bin; done; done) \
    --zx0 TITLE.BIN data/title.bin \
    --empty PROG.BIN 1024 \
    --empty SAVE.BIN 43008
ls -l build/polis.dsk build/polis.sna build/m0_bars.sna
