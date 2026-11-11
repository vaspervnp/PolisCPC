; terrain.asm — πλακίδια εδάφους, Amstrad CPC Mode 0
; ΠΑΡΑΓΕΤΑΙ ΑΥΤΟΜΑΤΑ από src/make_terrain.py — μην το πειράζεις με το χέρι.
;
; 16 εικόνες x 32 bytes = 512 bytes.
;
; ΑΔΙΑΦΑΝΟ: χωρίς μάσκα, μπαίνει με LDI. Τίποτα δεν είναι
; από κάτω του, οπότε η μάσκα θα ήταν διπλά bytes και διπλός
; χρόνος για το ίδιο αποτέλεσμα.
;
; Ο ΧΑΡΤΗΣ ΕΙΝΑΙ ΕΝΑ BYTE ΑΝΑ ΠΛΑΚΙΔΙΟ
;
;       bits 0-3   τύπος εδάφους, 0-15
;       bits 4-7   πόρος, 0 = τίποτα
;
; 64x64 = 4.096 bytes. 96x96 = 9.216. Και τα δύο χωράνε σε μία τράπεζα.

TILE_W             equ 4    ; bytes ανά γραμμή — ΑΔΙΑΦΑΝΟ,
;                            άρα τόσα και στη μνήμη
TILE_H             equ 8    ; γραμμές
TILE_SZ            equ 32   ; offset = index * TILE_SZ

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
ter_shore_n        equ 10   ; ακτή βορρά, ΑΔΙΑΒΑΤΟ
ter_shore_e        equ 11   ; ακτή ανατολής, ΑΔΙΑΒΑΤΟ
ter_shore_s        equ 12   ; ακτή νότου, ΑΔΙΑΒΑΤΟ
ter_shore_w        equ 13   ; ακτή δύσης, ΑΔΙΑΒΑΤΟ
ter_cliff          equ 14   ; γκρεμός, ΑΔΙΑΒΑΤΟ
ter_road           equ 15   ; δρόμος

terrain_gfx:
  ; grass — γρασίδι
  db #F3,#F3,#F3,#F3,#F3,#73,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#B3,#F3
  db #F3,#F3,#F3,#F3,#F3,#73,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#F3
  ; grass_tuft — γρασίδι θάμνος
  db #F3,#F3,#F3,#F3,#F3,#B3,#F3,#F3,#F3,#33,#73,#F3,#F3,#B3,#F3,#F3
  db #F3,#F3,#F3,#F3,#F3,#F3,#B3,#73,#F3,#F3,#F3,#F3,#F3,#F3,#F3,#F3
  ; grass_flower — γρασίδι άνθη
  db #F3,#F3,#F3,#F3,#F3,#73,#F3,#F3,#F3,#F3,#B7,#F3,#F3,#F3,#B3,#F3
  db #F3,#F3,#F3,#F3,#F3,#5B,#F3,#F3,#F3,#73,#F3,#F3,#F3,#F3,#F3,#F3
  ; dirt — χώμα
  db #CF,#CF,#CF,#CF,#CF,#DA,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#E5
  db #CF,#CF,#CF,#CF,#DA,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF
  ; dirt_rough — χώμα τραχύ
  db #CF,#CF,#CF,#CF,#CF,#30,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#CF,#47,#CF
  db #CF,#CF,#9A,#65,#CF,#CF,#CF,#CF,#9A,#CF,#CF,#CF,#CF,#CF,#CF,#CF
  ; sand — άμμος
  db #FC,#FC,#FC,#FC,#FC,#ED,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#DE
  db #FC,#FC,#FC,#FC,#FC,#DE,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
  ; sand_dune — αμμόλοφος
  db #FC,#FC,#FC,#FC,#FC,#ED,#DE,#FC,#FC,#DE,#ED,#FC,#FC,#FC,#FC,#FC
  db #FC,#FC,#FC,#FC,#FC,#ED,#DE,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC,#FC
  ; rock_floor — βράχος
  db #03,#03,#03,#03,#03,#81,#03,#03,#03,#03,#03,#03,#03,#03,#42,#03
  db #03,#03,#03,#03,#42,#03,#03,#03,#03,#03,#03,#03,#03,#03,#03,#03
  ; water_deep — βαθύ νερό
  db #C0,#C0,#C0,#C0,#C0,#EA,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#EA
  db #C0,#C0,#C0,#C0,#D5,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0,#C0
  ; water_shallow — ρηχό νερό
  db #FF,#FF,#FF,#FF,#FF,#D7,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#D7
  db #FF,#FF,#FF,#FF,#EB,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF
  ; shore_n — ακτή βορρά
  db #FF,#FF,#FF,#FF,#EB,#FF,#EB,#FF,#C3,#C3,#C3,#C3,#FC,#FC,#FC,#FC
  db #FC,#ED,#FC,#FC,#F6,#F6,#F6,#F6,#F3,#F3,#F3,#F3,#F3,#73,#F3,#F3
  ; shore_e — ακτή ανατολής
  db #F3,#F6,#E9,#FF,#F3,#76,#E9,#FF,#F3,#F6,#E9,#EB,#F6,#F6,#E9,#FF
  db #F3,#F6,#E9,#FF,#B3,#F6,#E9,#FF,#F3,#F6,#E9,#EB,#F3,#F6,#E9,#FF
  ; shore_s — ακτή νότου
  db #F3,#F3,#F3,#F3,#F3,#73,#F3,#F3,#F6,#F6,#F6,#F6,#FC,#ED,#FC,#FC
  db #FC,#FC,#FC,#FC,#C3,#C3,#C3,#C3,#EB,#FF,#EB,#FF,#FF,#FF,#FF,#FF
  ; shore_w — ακτή δύσης
  db #FF,#D6,#F9,#F3,#FF,#D6,#B9,#F3,#D7,#D6,#F9,#F3,#FF,#D6,#F9,#F9
  db #FF,#D6,#F9,#F3,#FF,#D6,#F9,#B3,#D7,#D6,#F9,#F3,#FF,#D6,#F9,#F3
  ; cliff — γκρεμός
  db #03,#03,#03,#03,#C3,#83,#C3,#03,#42,#03,#03,#81,#03,#03,#03,#03
  db #42,#03,#42,#03,#03,#03,#03,#03,#81,#03,#81,#03,#03,#03,#03,#03
  ; road — δρόμος
  db #F0,#F0,#F0,#F0,#E5,#F0,#E5,#F0,#F0,#F0,#F0,#F0,#F0,#DA,#F0,#E5
  db #F0,#F0,#F0,#F0,#E5,#F0,#DA,#F0,#F0,#F0,#F0,#F0,#F0,#F0,#DA,#F0
