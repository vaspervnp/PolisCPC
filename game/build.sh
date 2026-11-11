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
ls -l build/polis.dsk build/polis.sna build/m0_bars.sna
