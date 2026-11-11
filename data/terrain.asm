; terrain.asm — πλακίδια εδάφους, Amstrad CPC Mode 0
; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ από src/make_terrain.py — μην το πειράζεις με το χέρι.
;
; 16 εικόνες x 16 bytes = 256 bytes.
;
; ΙΣΟΜΕΤΡΙΚΟΣ ΡΟΜΒΟΣ, ΑΔΙΑΦΑΝΟΣ. Κομμένος σε όρια byte, άρα
; οι γείτονες κουμπώνουν χωρίς επικάλυψη και δεν χρειάζεται μάσκα.
; Αποθηκεύονται ΜΟΝΟ τα bytes μέσα στον ρόμβο, γραμμή-γραμμή κατά
; τον πίνακα tile_spans (πρώτο byte, πλήθος) — 8 γραμμές του κουτιού
; 8x8, η πρώτη και η τελευταία άδειες.
;
; Το πλακίδιο (i, j) πάει στο x = (i-j)*4 pixels = (i-j)*2 bytes,
; y = (i+j)*4 γραμμές, από την αρχή του χάρτη.
;
; Ο ΧΑΡΤΗΣ ΕΙΝΑΙ ΕΝΑ BYTE ΑΝΑ ΠΛΑΚΙΔΙΟ
;
;       bits 0-3   τύπος εδάφους, 0-15
;       bits 4-7   πόρος, 0 = τίποτα
;
; 64x64 = 4.096 bytes. 96x96 = 9.216. Και τα δύο χωράνε σε μία τράπεζα.

TILE_W             equ 4    ; bytes πλάτος του κουτιού
TILE_H             equ 8    ; γραμμές του κουτιού
TILE_SZ            equ 16   ; offset = index * TILE_SZ

tile_spans:
  db 0,0
  db 1,2
  db 1,2
  db 0,4
  db 0,4
  db 1,2
  db 1,2
  db 0,0

ter_grass          equ 0    ; γρασίδι
ter_grass_tuft     equ 1    ; γρασίδι θάμνος
ter_grass_flower   equ 2    ; γρασίδι άνθη
ter_dirt           equ 3    ; χώμα
ter_dirt_rough     equ 4    ; χώμα τραχύ
ter_sand           equ 5    ; άμμος
ter_sand_dune      equ 6    ; αμμόλοφος
ter_rock_floor     equ 7    ; βράχος
ter_water_deep     equ 8    ; βαθύ νερό, ΑΔΙΑΒΑΤΟ
ter_water_shallow  equ 9    ; ρηχό νερό, ΑΔΙΑΒΑΤΟ
ter_shore_ne       equ 10   ; ακτή, νερό ΒΑ
ter_shore_se       equ 11   ; ακτή, νερό ΝΑ
ter_shore_sw       equ 12   ; ακτή, νερό ΝΔ
ter_shore_nw       equ 13   ; ακτή, νερό ΒΔ
ter_cliff          equ 14   ; γκρεμός, ΑΔΙΑΒΑΤΟ
ter_road           equ 15   ; δρόμος

terrain_gfx:
  ; grass — γρασίδι
  db #73,#F3,#F3,#F3,#F3,#F3,#B3,#F3,#F3,#F3,#F3,#F3,#73,#F3,#F3,#F3
  ; grass_tuft — γρασίδι θάμνος
  db #B3,#F3,#33,#73,#F3,#B3,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#B3,#F3,#F3
  ; grass_flower — γρασίδι άνθη
  db #73,#F3,#F3,#B7,#F3,#F3,#B3,#F3,#F3,#F3,#F3,#F3,#5B,#F3,#73,#F3
  ; dirt — χώμα
  db #DA,#CF,#CF,#CF,#CF,#CF,#CF,#E5,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF
  ; dirt_rough — χώμα τραχύ
  db #30,#CF,#CF,#CF,#CF,#CF,#47,#CF,#CF,#CF,#9A,#65,#CF,#CF,#CF,#CF
  ; sand — άμμος
  db #ED,#FC,#FC,#FC,#FC,#FC,#FC,#DE,#FC,#FC,#FC,#FC,#DE,#FC,#FC,#FC
  ; sand_dune — αμμόλοφος
  db #ED,#DE,#DE,#ED,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#ED,#DE,#FC,#FC
  ; rock_floor — βράχος
  db #81,#03,#03,#03,#03,#03,#42,#03,#03,#03,#03,#03,#03,#03,#03,#03
  ; water_deep — βαθύ νερό
  db #EA,#C0,#C0,#C0,#C0,#C0,#C0,#EA,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
  ; water_shallow — ρηχό νερό
  db #D7,#FF,#FF,#FF,#FF,#FF,#FF,#D7,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
  ; shore_ne — ακτή, νερό ΒΑ
  db #DE,#E9,#F6,#DE,#F3,#F3,#FC,#CB,#F3,#F3,#F6,#FC,#73,#F3,#F3,#F3
  ; shore_se — ακτή, νερό ΝΑ
  db #73,#F3,#F3,#F6,#F3,#F3,#FC,#DE,#F3,#F6,#FC,#E9,#ED,#FC,#FC,#E9
  ; shore_sw — ακτή, νερό ΝΔ
  db #73,#F3,#F3,#F3,#FC,#F9,#B3,#F3,#C7,#FC,#F3,#F3,#ED,#F9,#D6,#ED
  ; shore_nw — ακτή, νερό ΒΔ
  db #D6,#FC,#FC,#DE,#D6,#FC,#B9,#F3,#ED,#FC,#F3,#F3,#F9,#F3,#F3,#F3
  ; cliff — γκρεμός
  db #83,#C3,#03,#03,#03,#03,#03,#03,#42,#03,#42,#03,#03,#03,#03,#81
  ; road — δρόμος
  db #F0,#E5,#F0,#F0,#F0,#DA,#F0,#E5,#F0,#F0,#F0,#F0,#F0,#DA,#F0,#F0
