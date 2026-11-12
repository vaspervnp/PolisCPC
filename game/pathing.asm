; pathing.asm — εύρεση δρόμου και κάδοι γειτονιάς. M5.
;
; ΑΠΟ ΤΟΝ ΚΟΣΜΟ ΣΤΟ ΠΛΑΚΙΔΙΟ
;
;   Η μονάδα «πατάει» στο (fx, fy) = (WX + 2, WY + 14). Το πλακίδιο κάτω από
;   το κέντρο του byte fx, στη γραμμή fy (ο ρόμβος των bytes του εδάφους):
;
;       i = (2 fx + fy - 383) >> 3        j = (fy - 2 fx + 383) >> 3
;
;   και το κέντρο του (i, j) είναι στο fx = 2 (i - j) + 192, fy = 4 (i + j) + 4.
;
; ΧΟΝΔΡΟ ΠΛΕΓΜΑ 16 x 16 κελιών των 6 x 6 πλακιδίων (όχι A*)
;
;   Στην εκκίνηση: για κάθε κελί, αν έχει έστω ένα ελεύθερο πλακίδιο, και αν
;   περνάει κανείς στο γειτονικό ανατολικά (+i) / νότια (+j) — ένα ζεύγος
;   ελεύθερων πλακιδίων εκατέρωθεν του ορίου, το «πέρασμα» (PORTAL), όσο
;   πιο κοντά στη μέση του ορίου γίνεται.
;
;   Σε κάθε εντολή: BFS από το κελί του στόχου (256 κελιά, ~15 ms: ΕΝΑ καρέ)
;   -> για κάθε κελί η κατεύθυνση προς το επόμενο (flow field). Η μονάδα
;   πηγαίνει στο πέρασμα προς το επόμενο κελί, και στο κελί του στόχου
;   κατευθείαν στον στόχο. Μέσα στο κελί: ΟΛΙΣΘΗΣΗ — αν το βήμα πέφτει σε
;   εμπόδιο, δοκιμάζει μόνο τον έναν άξονα, μετά τον άλλον, μετά τις
;   διαγώνιες δίπλα.
;
; ΚΑΔΟΙ 12 x 12 των 8 x 8 πλακιδίων: συνδεδεμένη λίστα μονάδων ανά κάδο ΚΑΙ
; ΑΝΑ ΟΜΑΔΑ (κεφαλές στο BKT0 / BKT1, επόμενη στο PN), ώστε η στόχευση να
; διαβάζει μόνο εχθρούς. Το πλέγμα των κεφαλών είναι 14 x 14 με ΑΔΕΙΟ
; περίγραμμα: ο κάδος (bi, bj) είναι το 15 + 14 bj + bi, και οι 8 γείτονες
; είναι σταθερές μετατοπίσεις, χωρίς ελέγχους ορίων. Η μονάδα αλλάζει κάδο
; μόνο όταν αλλάζει περιοχή.

BLOCK_TAB   equ #A900           ; 256: byte χάρτη -> 1 αν δεν περνιέται
CELL_TAB    equ #AA00           ; 256 κελιά: bits 0 E, 1 S, 2 W, 3 N ανοιχτά,
                                ; bit 4 έχει ελεύθερο πλακίδιο
FIELD_TAB   equ #AB00           ; 2 x 256: η κατεύθυνση ανά κελί (0 E, 1 S,
                                ; 2 W, 3 N, 4 στόχος, 255 απρόσιτο)
BKT0        equ #4E90           ; 196 x 2: η πρώτη μονάδα του κάδου (255
BKT1        equ #5690           ; καμία), ανά ομάδα — στις σειρές της σελίδας
                                ; του HUD που δεν φαίνονται, όπως το PORTAL
PORTAL      equ #4690           ; 256, στην κύρια RAM: η σελίδα του HUD, στις
                                ; σειρές 21-25 που δεν φαίνονται ποτέ
                                ; (low nibble: το j του περάσματος E, high:
                                ; το i του περάσματος S, μέσα στο κελί)
QUEUE       equ BUF_A           ; 128, κυκλική: η ουρά του BFS
FIELDS      equ 2

U_FIELD     equ 24              ; ποιο flow field ακολουθεί (0 κανένα, 1-2,
                                ; FIELD_WALK: κανένα, αλλά με ακολούθηση τοίχου)
U_TCELL     equ 25              ; το κελί του στόχου της
U_BKT       equ 26              ; ο κάδος της (255 κανένας)
; Για τη στόχευση, ανά μονάδα, σε πίνακες ΣΤΟΙΧΙΣΜΕΝΟΥΣ ώστε L = ο δείκτης
; της (κι αυτοί στις σειρές του HUD που δεν φαίνονται):
PX          equ #5F00           ; 128: το low byte του WX
PY          equ #5F80           ; 128: το low byte του WY
PN          equ #6700           ; 128: η επόμενη στον κάδο (255 τέλος)
NT          equ PN + 128        ; 128: 1 = όχι στόχος (M8: όσες περιπλανιούνται)
U_TEAM      equ 28
U_STUCK     equ 29              ; βήματα με ολίσθηση στη σειρά
U_TGT       equ 30              ; ο κοντινότερος εχθρός (255 κανένας)
U_OCELL     equ 31              ; το κελί του ΔΙΚΟΥ της στόχου (σχηματισμός)
U_WH        equ 17              ; ακολούθηση τοίχου: ποιο σημείο πορείας (το
                                ; δεύτερο byte του U_FRAME, μόνο για F_FIXED)

STUCK_MAX   equ 48

; ------------------------------------------------------------ εκκίνηση

nav_init:
        ld hl,BLOCK_TAB         ; BLOCK_TAB[b] = ter_block[b>>4] OR res_block[b&15]
.b:     ld a,l
        rrca
        rrca
        rrca
        rrca
        and 15
        ld e,a
        ld d,0
        push hl
        ld hl,ter_block
        add hl,de
        ld c,(hl)
        pop hl
        ld a,l
        and 15
        ld e,a
        push hl
        ld hl,res_block
        add hl,de
        ld a,(hl)
        pop hl
        or c
        ld (hl),a
        inc l
        jr nz,.b
        ; τα κελιά
        ld hl,CELL_TAB
        ld b,0
.z:     ld (hl),0
        inc l
        djnz .z
        xor a                   ; A = κελί
.cell:  ld (n_cell),a
        call cell_open          ; bit 4
        ld a,(n_cell)
        and 15
        cp 15
        call nz,edge_e
        ld a,(n_cell)
        cp 240
        call c,edge_s
        ld a,(n_cell)
        inc a
        jr nz,.cell
        ; οι κάδοι
        ld hl,BKT0
        ld b,196
.h:     ld (hl),255
        inc hl
        djnz .h
        ld hl,BKT1
        ld b,196
.h1:    ld (hl),255
        inc hl
        djnz .h1
        xor a
.u:     push af
        call idx_ix
        ld (ix+U_BKT),255
        ld (ix+U_TGT),255
        bit F_WANDER,(ix+U_FL)  ; οι τυχαίες θέσεις: όχι μέσα σε εμπόδιο
        jr z,.pl
.re:    call unit_tile
        ld hl,(n_i)
        ld de,(n_j)
        call tile_blk
        or a
        jr z,.pl
        call rnd_pos
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        jr .re
.pl:    call unit_pxy
        ld a,(ix+U_TEAM)        ; ελεύθερη θέση (M7): σε κανέναν κάδο
        inc a
        jr z,.nb
        call unit_tile
        call unit_inblk
        call bucket_update
.nb:
        pop af
        inc a
        cp UNITS
        jr nz,.u
        ret

; Το κελί n_cell έχει ελεύθερο πλακίδιο; -> bit 4.
cell_open:
        call cell_base          ; D = 6 ci, E = 6 cj
        ld c,6
.j:     ld b,6
        push de
.i:     push bc
        push de
        call tile_blk_de
        pop de
        pop bc
        or a
        jr z,.yes
        inc d
        djnz .i
        pop de
        inc e
        dec c
        jr nz,.j
        ret
.yes:   pop de
        ld a,(n_cell)
        ld l,a
        ld h,CELL_TAB >> 8
        set 4,(hl)
        ret

; n_cell -> D = 6 ci, E = 6 cj.
cell_base:
        ld a,(n_cell)
        and 15
        ld d,a
        add a,a
        add a,d
        add a,a
        ld d,a
        ld a,(n_cell)
        and #F0
        rrca
        rrca
        rrca
        rrca
        ld e,a
        add a,a
        add a,e
        add a,a
        ld e,a
        ret

; Η σειρά δοκιμής στο όριο: από τη μέση προς τα έξω.
portal_try: db 2, 3, 1, 4, 0, 5

; Πέρασμα ανατολικά: (6ci+5, 6cj+t) και (6ci+6, 6cj+t) ελεύθερα.
edge_e: ld hl,portal_try
        ld b,6
.t:     push bc
        push hl
        call cell_base
        ld a,(hl)
        ld (n_t),a
        add a,e
        ld e,a                  ; j
        ld a,d
        add a,5
        ld d,a                  ; i
        push de
        call tile_blk_de
        pop de
        or a
        jr nz,.no
        inc d
        call tile_blk_de
        or a
        jr nz,.no
        pop hl
        pop bc
        ld a,(n_cell)           ; E στο κελί, W στο επόμενο, και το j
        ld l,a
        ld h,CELL_TAB >> 8
        set 0,(hl)
        inc l
        set 2,(hl)
        dec l
        ld de,PORTAL
        ld h,0
        add hl,de
        ld a,(hl)
        and #F0
        ld b,a
        ld a,(n_t)
        or b
        ld (hl),a
        ret
.no:    pop hl
        inc hl
        pop bc
        djnz .t
        ret

; Πέρασμα νότια: (6ci+t, 6cj+5) και (6ci+t, 6cj+6) ελεύθερα.
edge_s: ld hl,portal_try
        ld b,6
.t:     push bc
        push hl
        call cell_base
        ld a,(hl)
        ld (n_t),a
        add a,d
        ld d,a                  ; i
        ld a,e
        add a,5
        ld e,a                  ; j
        push de
        call tile_blk_de
        pop de
        or a
        jr nz,.no
        inc e
        call tile_blk_de
        or a
        jr nz,.no
        pop hl
        pop bc
        ld a,(n_cell)
        ld l,a
        ld h,CELL_TAB >> 8
        set 1,(hl)
        ld a,l
        add a,16
        ld l,a
        set 3,(hl)
        ld a,(n_cell)
        ld l,a
        ld de,PORTAL
        ld h,0
        add hl,de
        ld a,(hl)
        and #0F
        ld b,a
        ld a,(n_t)
        add a,a
        add a,a
        add a,a
        add a,a
        or b
        ld (hl),a
        ret
.no:    pop hl
        inc hl
        pop bc
        djnz .t
        ret

; ------------------------------------------------------------ πλακίδια

; D = i, E = j (0..95) -> A = 1 αν είναι εμπόδιο.
tile_blk_de:
        ld l,e                  ; HL = MAP + 96 j + i
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld c,d
        ld b,0
        add hl,bc
        ld bc,MAP
        add hl,bc
        ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        ret

; HL = fx, DE = fy (κόσμος, με πρόσημο) -> HL = i, DE = j (με πρόσημο).
feet_tile:
        push de
        add hl,hl               ; 2 fx
        push hl
        add hl,de               ; 2 fx + fy - 383
        ld de,-383
        add hl,de
        call sra3
        ex (sp),hl              ; (sp) = i, HL = 2 fx
        pop bc                  ; BC = i
        pop de                  ; DE = fy
        ex de,hl                ; HL = fy, DE = 2 fx
        or a
        sbc hl,de
        ld de,383
        add hl,de
        call sra3
        ex de,hl                ; DE = j
        ld h,b
        ld l,c                  ; HL = i
        ret

sra3:   sra h
        rr l
        sra h
        rr l
        sra h
        rr l
        ret

; HL = i, DE = j -> A = 1 αν εμπόδιο (έξω από τον χάρτη: εμπόδιο).
tile_blk:
        ld a,h
        or d
        jr nz,.out
        ld a,l
        cp MAPW
        jr nc,.out
        ld a,e
        cp MAPW
        jr nc,.out
        ld d,l
        jp tile_blk_de
.out:   ld a,1
        ret

; HL = WX, DE = WY (πάνω-αριστερή γωνία) -> A = 1 αν τα πόδια εκεί πέφτουν σε
; εμπόδιο.
spot_blk:
        inc hl
        inc hl
        push hl
        ld hl,14
        add hl,de
        ex de,hl
        pop hl
        call feet_tile
        jp tile_blk

; IX -> n_i, n_j: το πλακίδιο κάτω από τα πόδια της (με πρόσημο, 16-bit).
unit_tile:
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        inc hl
        inc hl
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        push hl
        ld hl,14
        add hl,de
        ex de,hl
        pop hl
        call feet_tile
        ld (n_i),hl
        ld (n_j),de
        ret

; HL (με πρόσημο) -> A = 0..95.
clamp95:
        bit 7,h
        jr nz,.z
        ld a,h
        or a
        jr nz,.m
        ld a,l
        cp MAPW
        ret c
.m:     ld a,MAPW - 1
        ret
.z:     xor a
        ret

; A = 0..95 -> A = A / 6, από πίνακα.
div6:   ld l,a
        ld h,0
        ld de,div6_tab
        add hl,de
        ld a,(hl)
        ret

div6_tab:
k = 0
        repeat 96
        db (k * 43) >> 8         ; = k / 6 ακέραιο (το «/» του rasm στρογγυλεύει)
k = k + 1
        rend

; (n_i, n_j) -> A = το κελί (cj * 16 + ci), από το κοντινότερο μέσα στον χάρτη.
tile_cell:
        ld hl,(n_j)
        call clamp95
        call div6
        add a,a
        add a,a
        add a,a
        add a,a
        push af
        ld hl,(n_i)
        call clamp95
        call div6
        pop bc
        or b
        ret

; ------------------------------------------------------------ flow field

; A = κελί του στόχου -> το flow field f (1..FIELDS) σε field_f. BFS,
; ΜΟΙΡΑΣΜΕΝΟ σε καρέ: εδώ μόνο η αρχή, και το field_cont (από το units_tick)
; βγάζει ως BFS_N κελιά από την ουρά ανά καρέ. Ώσπου να τελειώσει, το
; field_tc του πεδίου είναι 255: οι μονάδες πάνε ίσια.
BFS_N       equ 96
field_build:
        ld (n_cell),a
        ld a,1
        ld (nphase),a           ; για τη μέτρηση (tests/m5_check.py)
        ld a,(field_rr)         ; το επόμενο πεδίο, κυκλικά
        inc a
        cp FIELDS + 1
        jr c,.f
        ld a,1
.f:     ld (field_rr),a
        ld (field_f),a
        ld e,a                  ; ο στόχος του πεδίου: όχι ακόμα
        ld d,0
        ld hl,field_tc - 1
        add hl,de
        ld (hl),255
        ld a,e                  ; H = η σελίδα του πεδίου
        add a,(FIELD_TAB >> 8) - 1
        ld h,a
        ld (n_page),a
        ld l,0                  ; όλο το πεδίο 255
        ld d,h
        ld e,1
        ld (hl),255
        ld bc,255
        ldir
        ld h,d
        ld a,(n_cell)
        ld l,a
        ld (hl),4               ; ο στόχος
        ld (QUEUE),a
        xor a
        ld (n_rd),a             ; ανάγνωση από την ουρά: n_rd
        inc a
        ld (n_wr),a             ; γράψιμο: n_wr
        ld (n_busy),a
        ret

; Ως BFS_N κελιά από την ουρά. Στο τέλος: το πεδίο ισχύει.
field_cont:
        ld a,BFS_N
        ld (n_cnt),a
        ld a,(n_wr)
        ld e,a
        ld d,QUEUE >> 8         ; γράψιμο: E (D = η σελίδα της ουράς)
.pop:   ld a,(n_rd)
        cp e
        jr z,.done
        ld hl,n_cnt
        dec (hl)
        jr z,.pause
        ld l,a
        ld h,QUEUE >> 8
        ld c,(hl)               ; C = το κελί
        inc a
        and 127
        ld (n_rd),a
        ld l,c
        ld h,CELL_TAB >> 8
        ld b,(hl)               ; B = τα ανοιχτά όρια
        ld a,(n_page)
        ld h,a
        bit 0,b                 ; E: ο γείτονας έρχεται πηγαίνοντας W
        jr z,.ns
        ld l,c
        inc l
        ld a,(hl)
        inc a
        jr nz,.ns
        ld (hl),2
        ld a,l
        ld (de),a
        inc e
        res 7,e
.ns:    bit 1,b                 ; S: ο γείτονας πηγαίνει N
        jr z,.nw
        ld a,c
        add a,16
        ld l,a
        ld a,(hl)
        inc a
        jr nz,.nw
        ld (hl),3
        ld a,l
        ld (de),a
        inc e
        res 7,e
.nw:    bit 2,b                 ; W: ο γείτονας πηγαίνει E
        jr z,.nn
        ld l,c
        dec l
        ld a,(hl)
        inc a
        jr nz,.nn
        ld (hl),0
        ld a,l
        ld (de),a
        inc e
        res 7,e
.nn:    bit 3,b                 ; N: ο γείτονας πηγαίνει S
        jr z,.pop
        ld a,c
        sub 16
        ld l,a
        ld a,(hl)
        inc a
        jr nz,.pop
        ld (hl),1
        ld a,l
        ld (de),a
        inc e
        res 7,e
        jr .pop
.pause: ld a,e
        ld (n_wr),a
        ret
.done:  xor a
        ld (n_busy),a
        ld a,(field_f)          ; το πεδίο ισχύει
        ld e,a
        ld d,0
        ld hl,field_tc - 1
        add hl,de
        ld a,(n_cell)
        ld (hl),a
        ld a,2
        ld (nphase),a
        ret

; ------------------------------------------------------------ βήμα

; IX, D = ως πόσα bytes, E = ως πόσες γραμμές. Ένα βήμα προς το σημείο
; πορείας (way_point), με ολίσθηση γύρω από τα εμπόδια. Ορίζει την όψη, και
; τον κάδο. Z αν δεν υπάρχει πια βήμα (έφτασε, ή κόλλησε για καλά).
nav_step:
        ld (n_lim),de
        ld l,(ix+U_WX)          ; a = 2 fx + fy - 383, b = fy - 2 fx + 383:
        ld h,(ix+U_WX+1)        ; το πλακίδιο είναι (a >> 3, b >> 3)
        inc hl
        inc hl
        add hl,hl
        ex de,hl                ; DE = 2 fx
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld bc,14
        add hl,bc               ; HL = fy
        push hl
        add hl,de
        ld bc,-383
        add hl,bc
        ld (n_a),hl
        pop hl
        or a
        sbc hl,de
        ld bc,383
        add hl,bc
        ld (n_b),hl
        call way_point          ; -> n_wx, n_wy
        ld hl,(n_wx)
        ld c,(ix+U_WX)
        ld b,(ix+U_WX+1)
        or a
        sbc hl,bc
        ld a,(n_lim + 1)
        ld d,a
        call clamp_step
        ld (g_x),a
        ld hl,(n_wy)
        ld c,(ix+U_WY)
        ld b,(ix+U_WY+1)
        or a
        sbc hl,bc
        ld a,(n_lim)
        ld d,a
        call clamp_step
        ld (g_y),a
        ld hl,g_x
        or (hl)
        jr nz,.go
        ld a,(n_way)            ; στο σημείο πορείας: αν ήταν ο στόχος, τέλος
        or a
        ret z
        ld (ix+U_FIELD),0       ; αλλιώς (πέρασμα πάνω σε εμπόδιο;): ίσια
        or 1
        ret
.go:    ld a,(ix+U_FL)          ; είναι ήδη μέσα σε εμπόδιο: βγαίνει ελεύθερα
        and 1 << F_INBLK
        ld (n_in),a
        ld a,(ix+U_FIELD)       ; με εντολή: ακολούθηση τοίχου
        or a
        jp nz,follow
        ld a,(g_x)              ; 1. το βήμα όπως είναι
        ld c,a
        ld a,(g_y)
        ld b,a
        call try_step
        jr z,nav_ok
        ld a,(g_x)              ; 2. μόνο οριζόντια
        or a
        jr z,.t3
        ld c,a
        ld b,0
        call try_step
        jr z,.slid
.t3:    ld a,(g_y)              ; 3. μόνο κάθετα
        or a
        jr z,.t4
        ld b,a
        ld c,0
        call try_step
        jr z,.slid
.t4:    ld a,(g_x)              ; 4. η άλλη διαγώνιος: (gx, -gy)
        ld c,a
        ld a,(g_y)
        neg
        ld b,a
        or c
        jr z,.t5
        call try_step
        jr z,.slid
.t5:    ld a,(g_x)              ; 5. (-gx, gy)
        neg
        ld c,a
        ld a,(g_y)
        ld b,a
        or c
        jr z,.stuck
        call try_step
        jr z,.slid
.stuck: xor a                   ; κανένα: μένει, και μετράει
        ld (g_x),a
        ld (g_y),a
        inc a
        ld (n_same),a
        jr .cnt
.slid:  ld a,c
        ld (g_x),a
        ld a,b
        ld (g_y),a
.cnt:   inc (ix+U_STUCK)
        ld a,(ix+U_STUCK)
        cp STUCK_MAX
        jr c,nav_mv
        xor a                   ; κόλλησε για καλά: σταματάει
        ret
nav_ok: ld (ix+U_STUCK),0
nav_mv: ld a,(g_x)              ; η κίνηση
        call add_wx
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld a,(g_y)
        call add_wy
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        call unit_pxy
        ld a,(n_same)           ; ίδιο πλακίδιο (ή καμία κίνηση): ούτε κάδος
        or a
        jp nz,set_face
        ld hl,(n_ti)            ; νέο πλακίδιο: το βρήκε ήδη το try_step
        ld (n_i),hl
        ld hl,(n_tj)
        ld (n_j),hl
        ld a,(n_in)
        or a
        call nz,unit_inblk      ; έβγαινε από εμπόδιο: βγήκε;
        call bucket_update
        jp set_face

; ΑΚΟΛΟΥΘΗΣΗ ΤΟΙΧΟΥ (bug2), για όσες έχουν εντολή. Το χονδρό πλέγμα δίνει
; τη γενική κατεύθυνση· μέσα στο κελί ένα εμπόδιο μπορεί να είναι κοίλο, και
; η απλή ολίσθηση εκεί κολλάει. Όταν το βήμα προς το σημείο πορείας πέφτει
; σε εμπόδιο, η μονάδα στρίβει αριστερά ώσπου να βρει ελεύθερο, και από εκεί
; ακολουθεί το εμπόδιο με αυτό ΣΤΑ ΔΕΞΙΑ (δοκιμάζει πρώτα δεξιά, μετά ίσια,
; μετά αριστερά). Ξαναπαίρνει τον δρόμο όταν το βήμα προς τον στόχο είναι
; ελεύθερο ΚΑΙ είναι πιο κοντά από εκεί που άρχισε να ακολουθεί.
;
; 8 κατευθύνσεις, δεξιόστροφα στην οθόνη: 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW,
; 6 N, 7 NE, με βήμα 1 byte / 2 γραμμές (η ισομετρική διαγώνιος).
FOLLOW_MAX  equ 250
dir_dx:     db 1, 1, 0, -1, -1, -1, 0, 1
dir_dy:     db 0, 2, 2, 2, 0, -2, -2, -2
goal_tab:   db 5, 6, 7, 4, 0, 0, 3, 2, 1        ; [(sy+1)*3 + sx+1]
rot_follow: db 2, 1, 0, -1, -2, -3, -4          ; δεξιά πρώτα
rot_start:  db -1, -2, -3, -4, 1, 2, 3          ; στην αρχή: αριστερά

follow:
        ld a,(g_x)              ; η κατεύθυνση του στόχου
        call sgn
        inc a
        ld c,a
        ld a,(g_y)
        call sgn
        inc a
        ld b,a
        add a,a
        add a,b
        add a,c
        ld e,a
        ld d,0
        ld hl,goal_tab
        add hl,de
        ld a,(hl)
        ld (n_gd),a
        call way_dist
        bit 7,(ix+U_WF)
        jr nz,.on
        ld a,(g_x)              ; δεν ακολουθεί: το βήμα όπως είναι
        ld c,a
        ld a,(g_y)
        ld b,a
        call try_step
        jp z,nav_ok
        call way_hash           ; εμπόδιο: αρχίζει να ακολουθεί
        ld (ix+U_WH),a
        ld a,(n_dist)
        ld (ix+U_WD),a
        ld (ix+U_STUCK),0
        ld a,(n_gd)
        ld hl,rot_start
        jr .try
.on:    call way_hash           ; άλλαξε το σημείο πορείας (άλλο κελί): η
        cp (ix+U_WH)            ; απόσταση αναφοράς ξανά από εδώ — αλλιώς
        jr z,.same              ; συγκρίνει αποστάσεις από διαφορετικά σημεία
        ld (ix+U_WH),a          ; και κάνει κύκλους γύρω από το εμπόδιο
        ld a,(n_dist)
        ld (ix+U_WD),a
.same:  ld a,(n_dist)           ; ακολουθεί: φεύγει;
        cp (ix+U_WD)
        jr nc,.keep
        ld a,(g_x)
        ld c,a
        ld a,(g_y)
        ld b,a
        call try_step
        jr nz,.keep
        ld (ix+U_WF),0
        jp nav_ok
.keep:  ld a,(ix+U_WF)
        and 7
        ld hl,rot_follow
.try:   ld (n_dir),a            ; 7 στροφές από την τρέχουσα κατεύθυνση
        ld b,7
.r:     push bc
        push hl
        ld a,(n_dir)
        add a,(hl)
        and 7
        ld (n_try),a
        ld e,a
        ld d,0
        ld hl,dir_dx
        add hl,de
        ld c,(hl)
        ld hl,dir_dy
        add hl,de
        ld b,(hl)
        call try_step
        jr z,.go
        pop hl
        inc hl
        pop bc
        djnz .r
        xor a                   ; κλεισμένη από παντού
        ld (g_x),a
        ld (g_y),a
        inc a
        ld (n_same),a
        jr .cnt
.go:    pop hl
        pop hl
        ld a,c
        ld (g_x),a
        ld a,b
        ld (g_y),a
        ld a,(n_try)
        or #80
        ld (ix+U_WF),a
.cnt:   inc (ix+U_STUCK)
        ld a,(ix+U_STUCK)
        cp FOLLOW_MAX
        jp c,nav_mv
        ld (ix+U_WF),0          ; δεν βγαίνει: σταματάει
        xor a
        ret

; -> A = (n_wx + n_wy) low: ποιο σημείο πορείας.
way_hash:
        ld a,(n_wx)
        ld hl,n_wy
        add a,(hl)
        ret

; A -> -1, 0, 1.
sgn:    or a
        ret z
        ld a,1
        ret p
        ld a,-1
        ret

; IX -> n_dist = (2 |n_wx - WX| + |n_wy - WY|) / 4, ως 255.
way_dist:
        ld hl,(n_wx)
        ld e,(ix+U_WX)
        ld d,(ix+U_WX+1)
        or a
        sbc hl,de
        call abs_hl
        add hl,hl
        push hl
        ld hl,(n_wy)
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        or a
        sbc hl,de
        call abs_hl
        pop de
        add hl,de
        srl h
        rr l
        srl h
        rr l
        ld a,h
        or a
        ld a,l
        jr z,.s
        ld a,255
.s:     ld (n_dist),a
        ret

; IX -> PX, PY: τα low bytes της θέσης της, για τη στόχευση.
unit_pxy:
        ld l,(ix+U_IDX)
        ld h,PX >> 8
        ld a,(ix+U_WX)
        ld (hl),a
        set 7,l
        ld a,(ix+U_WY)
        ld (hl),a
        ret

; IX, (n_i, n_j) -> το F_INBLK: είναι μέσα σε εμπόδιο;
unit_inblk:
        res F_INBLK,(ix+U_FL)
        ld hl,(n_i)
        ld de,(n_j)
        call tile_blk
        or a
        ret z
        set F_INBLK,(ix+U_FL)
        ret

; C = dx, B = dy -> Z αν το νέο σημείο των ποδιών είναι ελεύθερο (ή η μονάδα
; είναι ήδη σε εμπόδιο). Κρατάει BC.
try_step:
        push bc
        ld a,c                  ; 2 dx (με πρόσημο, 16-bit) -> DE
        add a,a
        ld e,a
        rla
        sbc a,a
        ld d,a
        ld a,b                  ; dy -> BC
        ld c,a
        rla
        sbc a,a
        ld b,a
        ld hl,(n_a)             ; na = a + 2 dx + dy
        add hl,de
        add hl,bc
        ld (n_na),hl
        ld hl,(n_b)             ; nb = b - 2 dx + dy
        or a
        sbc hl,de
        add hl,bc
        ld (n_nb),hl
        ld a,(n_b)              ; ίδιο πλακίδιο; (nb XOR b) AND #FFF8 = 0
        xor l
        and #F8
        jr nz,.new
        ld a,(n_b + 1)
        xor h
        jr nz,.new
        ld hl,(n_na)
        ld a,(n_a)
        xor l
        and #F8
        jr nz,.new
        ld a,(n_a + 1)
        xor h
        jr nz,.new
        ld a,1                  ; ναι: όσο ελεύθερο ήταν
        ld (n_same),a
        pop bc
        xor a
        ret
.new:   xor a
        ld (n_same),a
        ld hl,(n_nb)            ; j = nb >> 3, i = na >> 3
        call sra3
        ld (n_tj),hl
        ex de,hl
        ld hl,(n_na)
        call sra3
        ld (n_ti),hl
        ld a,(n_in)             ; μέσα σε εμπόδιο: περνάει πάντα
        or a
        jr nz,.free
        call tile_blk
        pop bc
        or a
        ret
.free:  pop bc
        xor a
        ret

; ------------------------------------------------------------ πορεία

; IX -> n_wx, n_wy (η πάνω-αριστερή γωνία όπου πρέπει να πάει), n_way = 0 αν
; είναι ο στόχος, 1 αν είναι πέρασμα.
way_point:
        xor a
        ld (n_way),a
        ld a,(ix+U_FIELD)
        or a
        jp z,.tgt
        cp FIELDS + 1           ; FIELD_WALK (gather.asm): ίσια, με
        jp nc,.tgt              ; ακολούθηση τοίχου
        ld e,a                  ; το πεδίο δείχνει ακόμα στο ίδιο κελί;
        ld d,0
        ld hl,field_tc - 1
        add hl,de
        ld a,(hl)
        cp (ix+U_TCELL)
        jp nz,.tgt
        ld a,e
        add a,(FIELD_TAB >> 8) - 1
        ld (n_page),a
        ld hl,(n_a)             ; το πλακίδιο από τα a, b του nav_step
        call sra3
        ld (n_i),hl
        ld hl,(n_b)
        call sra3
        ld (n_j),hl
        call tile_cell
        cp (ix+U_TCELL)         ; στο κελί του πεδίου, ή του δικού της
        jp z,.tgt               ; στόχου: ίσια
        cp (ix+U_OCELL)
        jp z,.tgt
        ld (n_cell),a
        ld l,a
        ld a,(n_page)
        ld h,a
        ld a,(hl)
        cp 4
        jp nc,.tgt              ; στόχος ή απρόσιτο: ίσια
        ld (n_dir),a
        call cell_base          ; D = 6 ci, E = 6 cj
        ld a,(n_dir)
        or a
        jr nz,.s
        ld a,(n_cell)           ; E: (6ci+6, 6cj + p_E[c])
        call portal_lo
        add a,e
        ld e,a
        ld a,d
        add a,6
        ld d,a
        jr .wp
.s:     dec a
        jr nz,.w
        ld a,(n_cell)           ; S: (6ci + p_S[c], 6cj+6)
        call portal_hi
        add a,d
        ld d,a
        ld a,e
        add a,6
        ld e,a
        jr .wp
.w:     dec a
        jr nz,.n
        ld a,(n_cell)           ; W: (6ci-1, 6cj + p_E[c-1])
        dec a
        call portal_lo
        add a,e
        ld e,a
        dec d
        jr .wp
.n:     ld a,(n_cell)           ; N: (6ci + p_S[c-16], 6cj-1)
        sub 16
        call portal_hi
        add a,d
        ld d,a
        dec e
.wp:    ld a,1                  ; η γωνία: x = 2 (i - j) + 190, y = 4 (i + j) - 10
        ld (n_way),a
        ld a,d
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,190
        add hl,bc
        ld (n_wx),hl
        ld l,d
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        ld bc,-10
        add hl,bc
        ld (n_wy),hl
        ret
.tgt:   ld l,(ix+U_TX)
        ld h,(ix+U_TX+1)
        ld (n_wx),hl
        ld l,(ix+U_TY)
        ld h,(ix+U_TY+1)
        ld (n_wy),hl
        ret

; A = κελί -> A = low / high nibble του PORTAL του. Κρατάει DE.
portal_lo:
        call portal_at
        and 15
        ret
portal_hi:
        call portal_at
        rrca
        rrca
        rrca
        rrca
        and 15
        ret
portal_at:
        push de
        ld e,a
        ld d,0
        ld hl,PORTAL
        add hl,de
        ld a,(hl)
        pop de
        ret

; ------------------------------------------------------------ κάδοι

; IX, (n_i, n_j) -> ο κάδος 15 + 14 (j>>3) + (i>>3), από το κοντινότερο
; πλακίδιο του χάρτη. Αν άλλαξε: έξω από τον παλιό, μέσα στον νέο.
bucket_update:
        ld hl,(n_j)
        call clamp95
        rrca
        rrca
        rrca
        and 15                  ; bj: 0..11
        add a,a                 ; x14 = x16 - x2
        ld b,a
        add a,a
        add a,a
        add a,a
        sub b
        add a,15
        ld c,a
        ld hl,(n_i)
        call clamp95
        rrca
        rrca
        rrca
        and 15
        add a,c
        cp (ix+U_BKT)
        ret z
        push af
        ld a,(ix+U_BKT)         ; έξω από τον παλιό
        cp 255
        call nz,bucket_out
        pop af
        ld (ix+U_BKT),a         ; μπροστά στον νέο
        call bkt_head
        ld a,(ix+U_IDX)
        ld e,(hl)               ; PN[idx] = η κεφαλή, κεφαλή = idx
        ld (hl),a
        ld l,a
        ld h,PN >> 8
        ld (hl),e
        ret

; A = κάδος -> HL = η κεφαλή του, στον πίνακα της ομάδας της IX.
bkt_head:
        ld e,a
        ld d,0
        ld hl,BKT0
        bit 0,(ix+U_TEAM)
        jr z,.t
        ld hl,BKT1
.t:     add hl,de
        ret

; A = ο κάδος της IX: βγαίνει από τη λίστα του.
bucket_out:
        call bkt_head           ; HL = ο σύνδεσμος που δείχνει την τρέχουσα
        ld b,(ix+U_IDX)
.l:     ld a,(hl)
        cp 255
        ret z                   ; (δεν βρέθηκε: δεν πρέπει να γίνει)
        cp b
        jr z,.found
        ld l,a                  ; ο σύνδεσμος της επόμενης: &PN[A]
        ld h,PN >> 8
        jr .l
.found: ld e,b                  ; ο σύνδεσμος = PN[idx]
        ld d,PN >> 8
        ld a,(de)
        ld (hl),a
        ret

; ------------------------------------------------------------ στόχευση

; IX -> U_TGT: ο κοντινότερος ΕΧΘΡΟΣ στον κάδο της και στους 8 γύρω, με
; απόσταση 2 |dx| + |dy| (bytes x 2 ~ γραμμές). 255 αν κανείς. Μέσα σε 3 x 3
; κάδους οι διαφορές χωράνε σε 8 bits (|dx| ≤ 60 bytes, |dy| ≤ 120 γραμμές):
; μόνο τα low bytes, και ό,τι ξεπερνάει τα 255 πετιέται.
find_nearest:
        ld (ix+U_TGT),255
        ld a,(ix+U_BKT)
        cp 255
        ret z
        ld e,a
        ld d,0
        ld hl,BKT1 - 15         ; ο πίνακας της ΑΛΛΗΣ ομάδας, από τον γείτονα
        bit 0,(ix+U_TEAM)       ; πάνω-αριστερά (-15)
        jr z,.t
        ld hl,BKT0 - 15
.t:     add hl,de
        ld a,255
        ld (t_bestd),a
        ld c,(ix+U_WX)
        ld b,(ix+U_WY)
        ld de,12
        call .three             ; -15 -14 -13
        add hl,de
        call .three             ;  -1   0   1
        add hl,de
.three: ld a,(hl)               ; τρεις κάδοι στη σειρά: άδειος = 255. Αν
        inc hl                  ; είναι και οι τρεις άδειοι (το AND τους
        and (hl)                ; είναι 255), μονομιάς
        inc hl
        and (hl)
        inc a
        ret z                   ; (το HL στον τρίτο, όπως και παρακάτω)
        dec hl
        dec hl
        ld a,(hl)
        inc a
        call nz,.scan
        inc hl
        ld a,(hl)
        inc a
        call nz,.scan
        inc hl
        ld a,(hl)
        inc a
        call nz,.scan
        ret
.scan:  dec a
        push hl
        push de
        call scan_enemy
        pop de
        pop hl
        ret

; A = η πρώτη της λίστας, C / B = WX / WY (low) αυτής που ψάχνει (IX).
; Από τους πίνακες PX / PY / PN: L = ο δείκτης της υποψήφιας.
scan_enemy:
.l:     cp 255
        ret z
        ld l,a
        ld h,PX >> 8
        ld a,(hl)               ; 2 |dx|
        sub c
        jp p,.px
        neg
.px:    add a,a
        jr c,.next
        ld e,a
        set 7,l                 ; PY = PX + 128
        ld a,(hl)               ; + |dy|
        res 7,l
        sub b
        jp p,.py
        neg
.py:    add a,e
        jr c,.next
        ld de,t_bestd
        ex de,hl
        cp (hl)
        ex de,hl
        jr nc,.next
        ld h,NT >> 8            ; όχι στόχος (περιπλανιέται, M8)
        set 7,l
        bit 0,(hl)
        res 7,l
        jr nz,.next
        ld (de),a
        ld (ix+U_TGT),l
.next:  ld h,PN >> 8
        ld a,(hl)
        jr .l

; Για τη μέτρηση της στόχευσης (tests/m5_check.py): όλες οι 128, μία φορά.
bench_targets:
        ld a,1
        ld (bphase),a
        xor a
.u:     push af
        call idx_ix
        call find_nearest
        pop af
        inc a
        cp UNITS
        jr nz,.u
        ld a,2
        ld (bphase),a
        xor a
        ld (bench_req),a
        ret
