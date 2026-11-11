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
rasm game/main.asm -o build/polis -s -sz
rasm game/main.asm -DSNA=1 -o build/polis -sz -v2 -ss
rasm game/main.asm -DSNA=1 -DBARS=1 -o build/m0_bars -sz -v2
# Το POLIS.BIN φορτώνεται στο #0040 και πρέπει να τελειώνει πριν το παράθυρο
# τράπεζας στο #4000.
(cd build && rm -f POLIS.BIN && iDSK polis.dsk -g POLIS.BIN >/dev/null 2>&1)
python3 - <<'PY'
d = open('build/POLIS.BIN', 'rb').read()
size = d[24] | d[25] << 8
end = 0x40 + size
print('POLIS.BIN: %d bytes, #0040-#%04X (ελεύθερα ώς το #4000: %d)'
      % (size, end - 1, 0x4000 - end))
assert end <= 0x4000, 'ο κώδικας μπαίνει στο παράθυρο τράπεζας #4000'
PY
ls -l build/polis.dsk build/polis.sna build/m0_bars.sna
