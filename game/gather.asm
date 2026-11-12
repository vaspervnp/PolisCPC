; gather.asm — πόροι και χωρικοί. M6.
;
; ΧΩΡΙΚΟΣ: ΠΗΓΑΙΝΕ -> ΜΑΖΕΨΕ -> ΓΥΡΝΑ -> ΑΔΕΙΑΣΕ
;
;   Η εντολή (RETURN) πάνω σε πλακίδιο με πόρο που μαζεύεται: οι επιλεγμένοι
;   χωρικοί (σετ 0, ομάδα του παίκτη) παίρνουν δουλειά· οι υπόλοιπες μονάδες
;   πάνε απλώς εκεί. Η κατάσταση είναι στο U_JOB, και αλλάζει ΜΟΝΟ στην
;   απόφαση (units_think, μία φορά στα ~22 καρέ):
;
;     J_GO    περπατάει στο ελεύθερο πλακίδιο δίπλα στην πηγή που είναι πιο
;             κοντά της· όταν σταματήσει (και είναι δίπλα): J_WORK
;     J_WORK  σε κάθε απόφαση +GATHER_N, ως carry_max[είδος], από την πηγή·
;             γεμάτος, ή άδειασε η πηγή: J_BACK
;     J_BACK  περπατάει στο κοντινότερο κτίριο που δέχεται το είδος (M7:
;             Κέντρο Πόλης, σιταποθήκη, αποθήκη)· εκεί ο φόρτος πάει στη μπάρα του
;             HUD, και ξανά J_GO στην ίδια πηγή. Αν η πηγή άδειασε: στην
;             κοντινότερη του ίδιου είδους (src_next)· αν δεν έχει: αδρανής.
;
;   Το πρώτο ταξίδι ακολουθεί το flow field της εντολής· τα επόμενα πάνε
;   ίσια, με ακολούθηση τοίχου (U_FIELD = FIELD_WALK, pathing.asm).
;
; ΠΗΓΕΣ: τι έχει μείνει
;
;   Ένα byte ανά πλακίδιο για το ποσό θα ήταν 9 KB. Εδώ μόνο οι πηγές που
;   ΑΝΟΙΞΑΝ: πίνακας SRC_N εγγραφών (θέση στον χάρτη, ποσό), που γεμίζει
;   όταν κάποιος αρχίζει να μαζεύει. Όταν το ποσό τελειώσει, το πλακίδιο
;   αλλάζει πόρο (δέντρο -> κούτσουρο, θάμνος -> άδειος, βράχος -> πετρούλες,
;   res_spent) και, αν φαίνεται, ξαναζωγραφίζονται οι δύο στήλες του.
;
; Οι πίνακες ανά μονάδα (L = ο δείκτης της, όπως PX/PY) και οι πηγές είναι
; στις σειρές της σελίδας του HUD που δεν φαίνονται ποτέ (screen.asm).

U_JOB       equ 27              ; η δουλειά: 0 καμία, J_*
J_GO        equ 1
J_WORK      equ 2
J_BACK      equ 3

J_CARRY     equ #7700           ; 128: πόσο κουβαλάει
J_KIND      equ #7780           ; 128: τι (0 τροφή, 1 ξύλο, 2 χρυσό, 3 πέτρα)
J_SI        equ #7F00           ; 128: η πηγή, i
J_SJ        equ #7F80           ; 128: η πηγή, j
SRC_TAB     equ #6F00           ; SRC_N x (θέση στον χάρτη dw, ποσό dw)
SRC_N       equ 32              ; ελεύθερη: high byte της θέσης = #FF

SET_CARRY   equ 3               ; το σετ του χωρικού με φορτίο (make_carry.py)
GATHER_N    equ 2
FIELD_WALK  equ FIELDS + 1      ; ίσια, με ακολούθηση τοίχου


; ------------------------------------------------------------ εκκίνηση

; HL = αρχή σελίδας -> 256 μηδενικά.
zero_page:
        ld d,h
        ld e,1
        ld (hl),0
        ld bc,255
        ldir
        ret

; ------------------------------------------------------------ εντολή

; (n_i, n_j) με πρόσημο -> A = το είδος του πόρου εκεί (255 κανένα), και
; cmd_si, cmd_sj = το πλακίδιο.
res_at: ld hl,(n_i)
        ld a,h
        or a
        jr nz,.none
        ld a,l
        cp MAPW
        jr nc,.none
        ld d,a
        ld hl,(n_j)
        ld a,h
        or a
        jr nz,.none
        ld a,l
        cp MAPW
        jr nc,.none
        ld e,a
        ld (cmd_sj),de          ; cmd_sj = j, cmd_si = i
        call map_ptr
        ld a,(hl)
        and 15
        ld e,a
        ld d,0
        ld hl,res_kind
        add hl,de
        ld a,(hl)
        ret
.none:  ld a,255
        ret

; IX = χωρικός της εντολής: η πηγή cmd_si, cmd_sj, του είδους cmd_kind.
job_start:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(cmd_si)
        ld (hl),a
        set 7,l
        ld a,(cmd_sj)
        ld (hl),a
        ld h,J_KIND >> 8        ; άλλο είδος: ό,τι κουβαλούσε χάνεται
        ld a,(cmd_kind)
        cp (hl)
        jr z,.same
        ld (hl),a
        res 7,l
        ld (hl),0
        xor a
        call set_look
.same:  call stand_point
        jr c,job_idle           ; τίποτα ελεύθερο γύρω της: απλώς πάει εκεί
        call tile_target
        ld (ix+U_JOB),J_GO
        ret

job_idle:
        ld (ix+U_JOB),0
        ret

; IX, A = σετ (0 ή SET_CARRY) -> U_SET, U_BASE. Το unit_update βλέπει την
; αλλαγή (U_LOOK) και τον ξαναζωγραφίζει.
set_look:
        ld (ix+U_SET),a
        add a,a
        ld e,a
        ld d,0
        ld hl,set_base
        add hl,de
        ld a,(hl)
        ld (ix+U_BASE),a
        inc hl
        ld a,(hl)
        ld (ix+U_BASE+1),a
        ret

; ------------------------------------------------------------ απόφαση

; IX, U_JOB != 0. Από το unit_think. Τίποτα όσο περπατάει.
job_tick:
        bit F_MOVE,(ix+U_FL)
        ret nz
        ld a,(ix+U_JOB)
        cp J_WORK
        jp z,job_work
        cp J_GO
        jr z,job_at_src
        cp J_BUILD
        jp z,bld_job
        ; J_BACK, στο σημείο απόθεσης: ο φόρτος στη μπάρα
        ld l,(ix+U_IDX)
        ld h,J_CARRY >> 8
        ld c,(hl)
        ld (hl),0
        set 7,l                 ; J_KIND
        ld a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,hud_val
        bit 0,(ix+U_TEAM)       ; ή του αντιπάλου (M10)
        jr z,.p
        ld hl,ai_val
.p:     add hl,de
        ld a,(hl)
        add a,c
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        ld a,e                  ; ο αριθμός του είδους (bit kind)
        rrca
        ld b,a
        inc b
        xor a
        scf
.bit:   rla
        djnz .bit
        ld hl,hud_dirty
        or (hl)
        ld (hl),a
        xor a                   ; χωρίς φορτίο
        call set_look
        ; και πίσω στην πηγή, αν έχει ακόμα
job_go_src:
        call src_check          ; άδειασε: η κοντινότερη του ίδιου είδους
        call nz,src_next
        jp nz,job_idle
        call stand_point
        jr c,job_idle
        call tile_target
        ld (ix+U_JOB),J_GO
job_walk:
        ld (ix+U_FIELD),FIELD_WALK
        ld (ix+U_WF),0
        ld (ix+U_STUCK),0
        set F_MOVE,(ix+U_FL)
        ret
job_at_src:                     ; σταμάτησε: είναι δίπλα στην πηγή;
        call unit_tile
        ld hl,(n_i)
        call clamp95
        ld c,a
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(hl)
        sub c
        inc a
        cp 3
        jp nc,job_idle
        ld hl,(n_j)
        call clamp95
        ld c,a
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_SJ >> 8
        ld a,(hl)
        sub c
        inc a
        cp 3
        jp nc,job_idle
        ld (ix+U_JOB),J_WORK
        ret

; Στο κοντινότερο έτοιμο κτίριο του παίκτη που δέχεται το είδος του:
; Κέντρο Πόλης όλα, σιταποθήκη τροφή, αποθήκη ξύλο, χρυσό και πέτρα. Στο
; ελεύθερο πλακίδιο γύρω του που είναι πιο κοντά. Κανένα: αδρανής.
job_go_drop:
        call unit_sp
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_KIND >> 8
        ld a,(hl)
        ld (dr_kind),a
        ld a,255
        ld (dr_best),a
        ld iy,BLD_TAB
        ld a,(bld_top)
        ld b,a
.l:     ld a,(iy+B_ST)          ; (ελεύθερη: 255, όχι 0)
        dec a
        jr nz,.n
        ld a,(iy+B_OWN)         ; της ομάδας του (M10)
        cp (ix+U_TEAM)
        jr nz,.n
        ld a,(iy+B_TYPE)
        or a                    ; Κέντρο Πόλης
        jr z,.ok
        ld c,a
        ld a,(dr_kind)
        or a                    ; Z: τροφή
        ld a,c
        jr nz,.pit
        cp BTY_GRANARY
        jr z,.ok
        jr .n
.pit:   cp BTY_STORAGE_PIT
        jr nz,.n
.ok:    ld a,(iy+B_I)           ; |i0 + 1 - ui| + |j0 + 1 - uj|
        inc a
        ld c,a
        ld a,(sp_ui)
        sub c
        call abs_a
        ld c,a
        ld a,(iy+B_J)
        inc a
        ld e,a
        ld a,(sp_uj)
        sub e
        call abs_a
        add a,c
        ld hl,dr_best
        cp (hl)
        jr nc,.n
        ld (hl),a
        ld (dr_rec),iy
.n:     call bnext
        djnz .l
        ld a,(dr_best)
        inc a
        jp z,job_idle
        ld iy,(dr_rec)
        call bld_ring
        jp c,job_idle
        call tile_target
        ld (ix+U_JOB),J_BACK
        jp job_walk

; Μαζεύει: min(GATHER_N, ό,τι χωράει, ό,τι έχει η πηγή).
job_work:
        call src_check
        jr nz,.gone
        call src_entry          ; HL -> το ποσό της πηγής
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = ποσό
        ld l,(ix+U_IDX)
        set 7,l                 ; το όριο του είδους (carry_max: M9). (Ως το
        ld h,J_KIND >> 8        ; M10 χωρίς το bit 7: διάβαζε το J_CARRY ως
        ld a,(hl)               ; είδος, και το όριο από ό,τι ακολουθούσε το
        res 7,l                 ; carry_max — που έτυχε να είναι 10.)
        add a,carry_max & 255
        ld c,a
        ld b,carry_max >> 8
        ld a,(bc)
        ld (cm_cur),a
        ld h,J_CARRY >> 8
        sub (hl)
        ld c,a                  ; C = ό,τι χωράει
        ld a,GATHER_N
        cp c
        jr c,.r
        ld a,c
.r:     ld b,a                  ; B = min(GATHER_N, χωράει)
        ld a,d
        or a
        jr nz,.t
        ld a,e
        cp b
        jr nc,.t
        ld b,a                  ; ... και ως το ποσό
.t:     ld a,(hl)
        add a,b
        ld (hl),a
        ld c,a                  ; C = φόρτος
        or a
        jr z,.nl
        push bc
        push de
        ld a,SET_CARRY          ; με φορτίο
        call set_look
        pop de
        pop bc
.nl:    pop hl
        ld a,e
        sub b
        ld (hl),a
        inc hl
        ld a,d
        sbc a,0
        ld (hl),a
        or (hl)
        dec hl
        or (hl)
        jr z,.empty
        ld a,(cm_cur)
        dec a
        cp c
        ret nc                  ; φόρτος < όριο
        jp job_go_drop
.empty: dec hl                  ; η εγγραφή ελεύθερη, το πλακίδιο αλλάζει
        ld (hl),#FF
        call src_deplete
        jp job_go_drop
.gone:  ld l,(ix+U_IDX)         ; την άδειασε άλλος: ό,τι κουβαλάει στο σπίτι,
        ld h,J_CARRY >> 8       ; αλλιώς στην επόμενη πηγή
        ld a,(hl)
        or a
        jp nz,job_go_drop
        jp job_go_src

; ------------------------------------------------------------ πηγές

; IX -> D = i, E = j της πηγής του.
job_src:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld d,(hl)
        set 7,l
        ld e,(hl)
        ret

; IX -> Z αν η πηγή έχει ακόμα πόρο του είδους του.
src_check:
        call job_src
        call map_ptr
        ld a,(hl)
        and 15
        ld e,a
        ld d,0
        ld hl,res_kind
        add hl,de
        ld c,(hl)
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_KIND >> 8
        ld a,(hl)
        cp c
        ret

; IX: η πηγή του άδειασε -> η κοντινότερη (απόσταση Chebyshev από την
; παλιά) με πόρο του ίδιου είδους, ως SRC_R πλακίδια μακριά, γίνεται η πηγή
; του: Z. NZ αν δεν υπάρχει. Σε βήματα: ακτίνα 1 (9 πλακίδια), 3, και 6
; (169, ~5 ms) — συνήθως η επόμενη είναι δίπλα.
SRC_R       equ 6
src_next:
        ld a,1
        call sn_try
        ret z
        ld a,3
        call sn_try
        ret z
        ld a,SRC_R
sn_try: ld (sn_r),a
        call job_src            ; D = si, E = sj
        ld a,255
        ld (sn_best),a
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_KIND >> 8
        ld a,(hl)
        ld (sn_kind),a
        ld a,(sn_r)
        ld c,a
        ld a,e
        sub c
        ld (sn_j),a             ; έξω από τον χάρτη (και τα αρνητικά): ≥ 96
        ld a,d
        sub c
        ld (sn_i0),a
        xor a
        sub c
        ld (sn_dj),a
.row:   ld a,(sn_j)
        cp MAPW
        jr nc,.nrow
        ld e,a
        ld d,0
        call map_ptr            ; HL = MAP + 96 j, + i0 με πρόσημο
        ld a,(sn_i0)
        ld c,a                  ; C = i
        ld e,a
        rla
        sbc a,a
        ld d,a
        add hl,de
        ld a,(sn_r)
        add a,a
        inc a
        ld b,a
.col:   ld a,c
        cp MAPW
        jr nc,.nc
        ld a,(hl)
        and 15
        push hl
        ld e,a
        ld d,0
        ld hl,res_kind
        add hl,de
        ld e,(hl)
        pop hl
        ld a,(sn_kind)
        cp e
        jr nz,.nc
        ld a,(sn_r)             ; max(|i - si|, |dj|)
        ld e,a
        ld a,(sn_i0)
        add a,e
        sub c
        call abs_a
        ld e,a
        ld a,(sn_dj)
        call abs_a
        cp e
        jr c,.m
        ld e,a
.m:     ld a,(sn_best)
        cp e
        jr c,.nc
        jr z,.nc
        ld a,e
        ld (sn_best),a
        ld a,c
        ld (sn_bi),a
        ld a,(sn_j)
        ld (sn_bj),a
.nc:    inc hl
        inc c
        djnz .col
.nrow:  ld hl,sn_j
        inc (hl)
        ld hl,sn_dj
        inc (hl)
        ld a,(sn_r)
        inc a
        cp (hl)
        jr nz,.row
        ld a,(sn_best)
        inc a
        jr z,.none
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(sn_bi)
        ld (hl),a
        set 7,l
        ld a,(sn_bj)
        ld (hl),a
        xor a
        ret
.none:  or 1
        ret

; IX -> HL = το ποσό (dw) της πηγής του: η εγγραφή της, ή νέα με το ποσό
; του πόρου (res_amount). Αν ο πίνακας γέμισε, ένα ποσό που δεν τελειώνει.
src_entry:
        call job_src
        call map_ptr
        push hl                 ; (sp) = το byte του χάρτη
        ld bc,-MAP
        add hl,bc
        ex de,hl                ; DE = η θέση στον χάρτη
        ld hl,SRC_TAB
        ld b,SRC_N
.f:     ld a,(hl)
        inc hl
        cp e
        jr nz,.n1
        ld a,(hl)
        cp d
        jr z,.hit
.n1:    inc hl
        inc hl
        inc hl
        djnz .f
        ld hl,SRC_TAB + 1       ; καμία: η πρώτη ελεύθερη
        ld b,SRC_N
.g:     ld a,(hl)
        inc a
        jr z,.new
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .g
        pop hl                  ; γεμάτος
        ld hl,1000
        ld (src_spare),hl
        ld hl,src_spare
        ret
.new:   ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        inc hl                  ; HL -> ποσό
        ex (sp),hl              ; HL = το byte του χάρτη
        ld a,(hl)
        and 15
        add a,a
        ld e,a
        ld d,0
        ld hl,res_amount
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        dec hl
        ret
.hit:   inc hl
        pop de
        ret

; IX: η πηγή του άδειασε. Ο πόρος γίνεται res_spent, και ξαναζωγραφίζεται
; ΜΟΝΟ το κομμάτι του: οι 2 στήλες (4 bytes) του sprite, στις γραμμές του
; (σε ομάδες των 4), μία ανά καρέ (rq_set) — έδαφος, πόροι και κτίρια με τη
; σειρά του ζωγράφου, ψαλιδισμένα εκεί (col_redraw), και ο καθρέφτης. Οι
; μονάδες και ο κέρσορας που το ακουμπάνε ξαναζωγραφίζονται από πάνω
; (ορθογώνια στο RECTS, units_mark).
src_deplete:
        call job_src
        push de
        call map_ptr
        ld a,(hl)
        and 15
        ld c,a
        ld b,0
        push hl
        ld hl,res_spent
        add hl,bc
        ld c,(hl)
        pop hl
        ld a,(hl)
        and #F0
        or c
        ld (hl),a
        pop de
        call tile_xy            ; HL = x, DE = y (= το sprite του πόρου)
        jp rq_set               ; οι 2 στήλες του, μία ανά καρέ (buildings.asm)

; A = ζυγό byte οθόνης: το κομμάτι col_y0..col_y1 της στήλης από την αρχή,
; ΤΟ ΙΔΙΟ κομμάτι στον καθρέφτη (όχι όλη η στήλη: πιο κάτω μπορεί να είναι
; ζωγραφισμένη μια μονάδα, που δεν είναι φόντο), και ορθογώνια 4 x 16 που
; καλύπτουν το κομμάτι.
col_redraw:
        push af
        xor a                   ; μια κάθετη κύλιση στη μέση έχει ίσως
        ld (v_pend),a           ; ζωγραφίσει το παλιό: ξαναρχίζει
        ld a,#FE                ; οι έλεγχοι του παραθύρου στο draw_column
        ld (cw_j1),a
        ld (cw_j2),a
        ld a,RAM_RES            ; οι πόροι είναι στην C6
        call setram
        pop af
        push af
        call draw_column
        ld a,RAM_BASE
        call setram
        ld a,#18                ; πίσω σε «jr»: όλο το ύψος
        ld (cw_j1),a
        ld (cw_j2),a
        pop af
        push af
        call mirror_part
        pop af
        ld c,a
        ld a,(col_y0)
        ld b,a
.r:     push bc
        call add_rect
        pop bc
        ld a,b
        add a,16
        ld b,a
        ld hl,col_y1
        cp (hl)
        jr c,.r
        xor a                   ; πίσω σε όλο το ύψος: αλλιώς η επόμενη
        ld (col_y0),a           ; κύλιση (draw_column) ψαλιδίζει τους
        ld a,VIEW_H             ; πόρους και τα κτίρια της στο κομμάτι
        ld (col_y1),a
        ret

; A = ζυγό byte οθόνης: οι γραμμές col_y0..col_y1 της στήλης (2 bytes) στον
; καθρέφτη (τράπεζα C4, ίδια διάταξη, bit 15 σβηστό).
mirror_part:
        ld c,a
        ld a,RAM_BG
        call setram
        ld a,(col_y0)
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld a,(col_y0)
        neg
        ld b,a
        ld a,(col_y1)
        add a,b
        ld b,a                  ; B = πόσες γραμμές
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,c
        add a,e
        ld e,a
        call c,de_carry
        ld h,d
        ld l,e
        res 7,h
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        pop hl
        djnz .l
        ld a,RAM_BASE
        jp setram

; ------------------------------------------------------------ θέσεις

; D = i, E = j (0..95) -> HL = MAP + 96 j + i. Κρατάει DE.
map_ptr:
        ld l,e
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
        ret

; IX -> sp_ui, sp_uj: το πλακίδιο της, στον χάρτη.
unit_sp:
        call unit_tile
        ld hl,(n_i)
        call clamp95
        ld (sp_ui),a
        ld hl,(n_j)
        call clamp95
        ld (sp_uj),a
        ret

; IX -> D = i, E = j: το ελεύθερο πλακίδιο γύρω από την πηγή του που είναι
; πιο κοντά στο δικό της. Carry αν δεν υπάρχει κανένα.
stand_point:
        call unit_sp
        call job_src
        dec d
        dec e
        ld c,3

; D, E = γωνία, C = πλευρά: το ελεύθερο πλακίδιο του τετραγώνου C x C που
; είναι πιο κοντά στο (sp_ui, sp_uj) -> D, E. Carry αν κανένα.
near_free:
        ld a,c
        ld (nf_n),a
        ld a,255
        ld (sp_best),a
        ld b,c
.r:     push bc
        push de
        ld a,e                  ; έξω από τον χάρτη (και το -1 = 255)
        cp MAPW
        jr nc,.nr
        push de
        ld d,0
        call map_ptr            ; HL = MAP + 96 j, + i με πρόσημο
        pop de
        ld a,d
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld a,(nf_n)
        ld b,a
.c:     ld a,d
        cp MAPW
        jr nc,.n
        push hl
        ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        or a
        jr nz,.nn
        ld a,(sp_ui)            ; |i - ui| + |j - uj|
        sub d
        call abs_a
        ld c,a
        ld a,(sp_uj)
        sub e
        call abs_a
        add a,c
        ld hl,sp_best
        cp (hl)
        jr nc,.nn
        ld (hl),a
        ld (sp_bj),de
.nn:    pop hl
.n:     inc hl
        inc d
        djnz .c
.nr:    pop de
        inc e
        pop bc
        djnz .r
        ld a,(sp_best)
        inc a
        scf
        ret z
        ld de,(sp_bj)
        or a
        ret

abs_a:  bit 7,a
        ret z
        neg
        ret

; D = i, E = j -> HL = 2 (i - j) + 190, DE = 4 (i + j) - 10: η πάνω-αριστερή
; γωνία της μονάδας που πατάει στο κέντρο του πλακιδίου.
tile_xy:
        ld a,d
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,190
        add hl,bc
        push hl
        ld l,d
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        ld bc,-10
        add hl,bc
        ex de,hl
        pop hl
        ret

; IX, D = i, E = j -> ο στόχος της εκεί, και το U_OCELL του.
tile_target:
        push de
        call tile_xy
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld (ix+U_TY),e
        ld (ix+U_TY+1),d
        pop de
        ld l,d
        ld h,0
        ld (n_i),hl
        ld l,e
        ld (n_j),hl
        call tile_cell
        ld (ix+U_OCELL),a
        ret

