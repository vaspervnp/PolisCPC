; jobs.asm — οι δουλειές των χωρικών (από το gather.asm): η απόφαση, το
; ταξίδι στην πηγή και στο σημείο απόθεσης, το μάζεμα, η επόμενη πηγή.
;
; Στη σελίδα του HUD (HI_B, main.asm), όπως το BOOT: τρέχουν ΜΟΝΟ με την C0
; στο #4000 και δεν αλλάζουν οι ίδιες τράπεζα εκεί (καλούν όμως ρουτίνες
; του κύριου κώδικα που αλλάζουν και γυρίζουν, π.χ. το rq_set).

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

