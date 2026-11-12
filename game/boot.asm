; boot.asm — ρουτίνες της κύριας RAM ΠΑΝΩ από το #4000 (M9, M11).
;
; Ο κύριος κώδικας (#0040-#3FFF) γέμισε. Εδώ ζουν ρουτίνες που τρέχουν ΜΟΝΟ
; με την C0 (η σελίδα του HUD στο #4000) και δεν αλλάζουν οι ίδιες τράπεζα
; στο #4000 (θα χανόταν ο κώδικας που τρέχει) — μπορούν όμως να καλούν
; ρουτίνες του κύριου κώδικα που αλλάζουν και γυρίζουν στην C0 (far7,
; col_redraw, disk_load). Συναρμολογημένες για το BOOT (#7A30, σειρές 7-20
; της σελίδας του HUD), ταξιδεύουν στο POLIS.BIN, και το `start` τις
; αντιγράφει εκεί πρώτο απ' όλα· το hud_init καθαρίζει τη σελίδα ΜΟΝΟ ως το
; BOOT. Από την C7 με το call0.

; Οι ρουτίνες της εκκίνησης (units_init, nav_init, hud_init ...) ζούσαν
; εδώ ως το M10· πήγαν στο game/init.asm (#F000).

; ---- από το game/units.asm

; Πίνακας 256: τα δύο pixels του byte Mode 0 ανταλλαγμένα. Pixel 0 στα bits
; 7,5,3,1, pixel 1 στα 6,4,2,0 — άρα ανταλλαγή ζυγών/μονών bits.
make_swap:
        ld hl,SWAP_TAB
.s:     ld a,l
        add a,a
        and #AA
        ld c,a
        ld a,l
        rrca
        and #55
        or c
        ld (hl),a
        inc l
        jr nz,.s
        ret

; ---- από το game/main.asm

; Όλη η οθόνη pen 0.
clear_screen:
        ld hl,SCREEN
        ld de,SCREEN + 1
        ld bc,#3FFF
        ld (hl),0
        ldir
        ret

; Τα 16 pens από το polis_hw. Το firmware είναι κλειστό, άρα κανείς δεν
; ξαναγράφει τα INK στη διακοπή — μένουν όπως τα αφήνουμε.
set_palette:
        ld hl,polis_hw
        ld b,GA
        ld e,0
.pen:   out (c),e               ; επιλογή pen
        ld a,(hl)
        out (c),a               ; το χρώμα του
        inc hl
        inc e
        ld a,e
        cp 16
        jr nz,.pen
        ld a,HW_BLACK
        jp border

; Η τυπική οθόνη 160x200 στο #C000, γραμμένη ρητά: να μη στηριζόμαστε σε ό,τι
; άφησε το firmware ή ένα snapshot.
crtc_setup:
        ld hl,crtc_regs
        ld d,0
.reg:   ld bc,CRTC_SEL*256
        out (c),d
        ld a,(hl)
        ld b,CRTC_DAT
        out (c),a
        inc hl
        inc d
        ld a,d
        cp 14
        jr nz,.reg
        ret

crtc_regs:
        ;   R0  R1  R2  R3  R4  R5  R6  R7  R8  R9 R10 R11 R12 R13
        db  63, 40, 46,#8E, 38,  0, 25, 30,  0,  7,  0,  0,#30,  0

; ---- από το game/gather.asm (καλούνται και στο παιχνίδι, με την C0)

; ------------------------------------------------------------ HUD

; Οι αριθμοί της μπάρας (hud_val) που άλλαξαν (bits του hud_dirty: 0-5) στη
; σελίδα του HUD, 4 ψηφία ο καθένας, στοιχισμένα δεξιά (~0,6 ms ο καθένας).
; Η σελίδα είναι κύρια RAM: η C0 πρέπει να είναι μέσα.
hud_update:
        ld a,(hud_dirty)
        ld c,a
        xor a
        ld (hud_dirty),a
        ld hl,hud_val
        ld de,bar_x
        ld b,6
.n:     srl c
        jr nc,.skip
        push bc
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)
        dec hl
        push hl
        ld a,(de)
        call hud_num
        pop hl
        pop de
        pop bc
.skip:  inc hl
        inc hl
        inc de
        djnz .n
        ret

; BC = τιμή, A = byte της πρώτης στήλης.
hud_num:
        ld (hn_x),a
        ld h,b
        ld l,c
        ld de,10000             ; ως 9999
        call cmp_hl_de
        jr c,.ok
        ld hl,9999
.ok:    ld de,hn_d
        ld bc,-1000
        call .dig
        ld bc,-100
        call .dig
        ld bc,-10
        call .dig
        ld a,l
        ld (de),a
        ld hl,hn_d              ; τα μηδενικά μπροστά: κενά
        ld b,3
.z:     ld a,(hl)
        or a
        jr nz,.draw
        ld (hl),10
        inc hl
        djnz .z
.draw:  ld hl,hn_d
        ld c,0                  ; C = στήλη μέσα στον αριθμό
        ld b,4
.g:     push bc
        ld a,(hl)
        push hl
        ld l,a                  ; DE = digits + 10 d
        add a,a
        add a,a
        add a,l
        add a,a
        ld e,a
        ld d,0
        ld hl,digits
        add hl,de
        ex de,hl
        ld a,(hn_x)
        add a,c
        ld (hn_c),a
        ld hl,bar_rows
        ld b,5
.l:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld a,(hn_c)
        add a,c
        ld l,a
        ld a,b
        adc a,0
        ld h,a
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        pop bc
        djnz .l
        pop hl
        inc hl
        pop bc
        inc c
        inc c
        djnz .g
        ret
.dig:   ld a,-1                 ; πόσες φορές χωράει το -BC
.d1:    inc a
        add hl,bc
        jr c,.d1
        sbc hl,bc               ; carry 0: πίσω το τελευταίο
        ld (de),a
        inc de
        ret

; Οι 5 γραμμές των ψηφίων στη σελίδα του HUD (διάταξη CRTC με αρχή 0).
bar_rows:
hl_ = BAR_Y
        repeat 5
        dw HUD_PAGE + (hl_ & 7) * #800 + (hl_ >> 3) * 80
hl_ = hl_ + 1
        rend

; ---- ο αντίπαλος (M10): με την C0, από την C7 (call0)

; IX = χωρικός του αντιπάλου, C = είδος: μαζεύει από την πηγή του είδους
; στο ai_seed — την τελευταία που βρέθηκε, ή την κοντινότερη ως SRC_R από
; αυτήν (job_go_src, gather.asm).
ai_gather:
        ld a,c
        add a,a
        ld e,a
        ld d,0
        ld hl,ai_seed
        add hl,de
        push hl
        ld d,(hl)
        inc hl
        ld e,(hl)
        ld l,(ix+U_IDX)         ; J_SI, J_SJ = ο σπόρος
        ld h,J_SI >> 8
        ld (hl),d
        set 7,l
        ld (hl),e
        ld h,J_KIND >> 8        ; άλλο είδος: ό,τι κουβαλούσε χάνεται
        ld a,c
        cp (hl)
        jr z,.same
        ld (hl),a
        res 7,l
        ld (hl),0
        xor a
        call set_look
.same:  call job_go_src
        ld a,(ix+U_JOB)         ; βρέθηκε: ο σπόρος για τον επόμενο
        or a
        pop hl
        ret z
        push hl
        call job_src
        pop hl
        ld (hl),d
        inc hl
        ld (hl),e
        ret

ai_seed:    db 61, 33           ; τροφή (θάμνοι)
            db 52, 32           ; ξύλο
            db 75, 36           ; χρυσός
            db 79, 43           ; πέτρα


; ---- από το game/buildings.asm (M11): πλήκτρα, τοποθέτηση, ανέγερση

; ------------------------------------------------------------ πλήκτρα

; Από το cursor_input: τα πλήκτρα των κτιρίων, μόνο στο πάτημα.
bld_input:
        ld hl,bld_keym
        ld c,0
.k:     ld a,(hl)
        call read_row
        inc hl
        and (hl)
        inc hl
        jr nz,.got
        inc c
        ld a,c
        cp BT_N + 3
        jr nz,.k
        ld c,255
.got:   ld hl,bk_prev
        ld a,c
        cp (hl)
        ld (hl),a
        ret z
        inc a
        ret z
        dec a
        cp BT_N
        jr c,.type
        jr z,bld_train
        cp BT_N + 2             ; U: έρευνα στο επιλεγμένο κτίριο (bank7.asm)
        jr nz,.esc
        ld hl,res_start
        jp far7
.esc:   ld a,255                ; ESC
        ld (bmode),a
        jr cur_look
.type:  ld (bn_t),a             ; ένας τύπος: αν υπάρχει χωρικός επιλεγμένος
        call sel_villager       ; και ο τύπος χτίζεται
        ret nc
        ld a,(bn_t)
        call bld_can
        ret c
        ld a,(bn_t)
        ld (bmode),a

; Ο κέρσορας: γωνία όσο διαλέγεις θέση, αλλιώς βέλος.
cur_look:
        ld hl,SPR_CURSOR
        ld a,(bmode)
        inc a
        jr z,.s
        ld hl,SPR_ANCHOR
.s:     ld (CURSOR_REC + U_FRAME),hl
        ld a,1
        ld (cur_force),a
        ret

; T: μία μονάδα στην ουρά του επιλεγμένου κτιρίου — αν ο πληθυσμός μαζί με
; τις ουρές είναι κάτω από το όριο (pop_cap).
bld_train:
        ld a,(sel_bld)
        cp 255
        ret z
        call pop_cap
        ld c,a
        ld a,(hud_val + 8)
        ld hl,bq_tot
        add a,(hl)
        cp c
        ret nc
        ld a,(sel_bld)
        call brec_iy
        ld a,(iy+B_OWN)         ; του παίκτη (M10: και του αντιπάλου επιλέγεται)
        or a
        ret nz
        ld a,(iy+B_ST)
        or a
        ret z
        ld a,(iy+B_QN)
        cp QMAX
        ret nc
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UNIT
        add hl,de
        ld a,(hl)
        inc a
        ret z
        inc hl                  ; το κόστος της μονάδας
        call pay
        ret c
        inc (iy+B_QN)
        ld hl,bq_tot
        inc (hl)
        ret

; -> A = το όριο πληθυσμού: POP_BASE + POP_HOUSE ανά έτοιμο σπίτι (ως 255).
POP_BASE    equ 15
POP_HOUSE   equ 5
pop_cap:
        ld c,POP_BASE
        ld iy,BLD_TAB
        ld a,(bld_top)          ; ως την ψηλότερη θέση που πιάστηκε
        ld b,a
.l:     ld a,(iy+B_TYPE)
        cp BTY_HOUSE
        jr nz,.n
        ld a,(iy+B_OWN)         ; του παίκτη
        or a
        jr nz,.n
        ld a,(iy+B_ST)
        or a
        jr z,.n
        ld a,c
        add a,POP_HOUSE
        jr c,.n
        ld c,a
.n:     call bnext
        djnz .l
        ld a,c
        ret

; Carry αν υπάρχει χωρικός του παίκτη στην επιλογή.
sel_villager:
        ld a,(sel_n)
        or a
        ret z                   ; NC: κανένας
        ld b,a
        ld hl,SELLIST
.s:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        pop iy
        call is_villager
        scf
        ret z
        djnz .s
        or a
        ret

; IY = μονάδα -> Z αν είναι χωρικός του παίκτη (σετ 0 ή SET_CARRY, ομάδα 0).
is_villager:
        ld a,(iy+U_TEAM)
        or a
        ret nz
        ld a,(iy+U_SET)
        or a
        ret z
        cp SET_CARRY
        ret

; A = τύπος -> NC αν χτίζεται τώρα: εποχή, προαπαιτούμενο, κόστος (μόνο
; έλεγχος).
bld_can:
        call bt_hl
        inc hl
        ld a,(hud_val + 10)     ; η εποχή
        cp (hl)
        ret c
        inc hl
        ld a,(hl)               ; προαπαιτούμενο: ένα έτοιμο του παίκτη
        cp 255
        jr z,.cost
        push hl
        ld c,a
        ld iy,BLD_TAB
        ld a,(bld_top)          ; ως την ψηλότερη θέση που πιάστηκε
        ld b,a
.p:     ld a,(iy+B_TYPE)
        cp c
        jr nz,.pn
        ld a,(iy+B_OWN)
        or a
        jr nz,.pn
        ld a,(iy+B_ST)
        or a
        jr nz,.ok
.pn:    call bnext
        djnz .p
        pop hl
        scf
        ret
.ok:    pop hl
.cost:  inc hl
        ld de,hud_val           ; 4 x (κόστος ≤ ό,τι έχεις)
        ld b,4
.c:     ld a,(de)
        sub (hl)
        inc de
        ld a,(de)
        sbc a,0
        ret c
        inc de
        inc hl
        djnz .c
        or a
        ret

; HL -> 4 x κόστος: αφαιρείται από τη μπάρα αν φτάνει (NC), αλλιώς carry.
pay:    push hl
        ld de,hud_val
        ld b,4
.c:     ld a,(de)
        sub (hl)
        inc de
        ld a,(de)
        sbc a,0
        jr c,.no
        inc de
        inc hl
        djnz .c
        pop hl
        ld de,hud_val
        ld b,4
        ld c,1                  ; C = το bit του αριθμού στη μπάρα
.d:     ld a,(hl)               ; μόνο όσα κοστίζουν: ξαναγράφονται
        or a
        jr z,.e
        ld a,(hud_dirty)
        or c
        ld (hud_dirty),a
.e:     ld a,(de)
        sub (hl)
        ld (de),a
        inc de
        ld a,(de)
        sbc a,0
        ld (de),a
        inc de
        inc hl
        sla c
        djnz .d
        or a
        ret
.no:    pop hl
        ret

; ------------------------------------------------------------ τοποθέτηση

; RETURN με τύπο διαλεγμένο: η κάτοψη με κέντρο τον κέρσορα, αν είναι μέσα
; στον χάρτη και όλα της τα πλακίδια ελεύθερα (χωρίς πόρο ή με κούτσουρο) και
; ο τύπος χτίζεται: πληρώνεται, γίνεται θεμέλιο, και οι επιλεγμένοι
; χωρικοί πάνε να το χτίσουν.
bld_place:
        ld a,(bmode)
        call bt_hl
        ld a,(hl)
        ld (bn_n),a
        call cur_world
        ld hl,(cw_x)
        ld de,(cw_y)
        call feet_tile          ; HL = i, DE = j (με πρόσημο)
        ld a,(bn_n)             ; - (n - 1) / 2
        dec a
        srl a
        ld c,a
        ld b,0
        or a
        sbc hl,bc
        ex de,hl                ; HL = j, DE = i0
        or a
        sbc hl,bc
        ld a,h                  ; i0, j0 στο 0..96 - n
        or d
        ret nz
        ld a,(bn_n)
        neg
        add a,MAPW + 1
        ld c,a
        ld a,l
        cp c
        ret nc
        ld a,e
        cp c
        ret nc
        ld d,e                  ; D = i0, E = j0
        ld e,l
        ld (bp_ij),de
        ld a,(bn_n)             ; ελεύθερα;
        ld b,a
.r:     push bc
        push de
        ld a,(bn_n)
        ld b,a
.t:     push bc
        call map_ptr
        ld a,(hl)
        and 15
        jr z,.ok
        cp 4                    ; κούτσουρο
        jr nz,.bad
.ok:    ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        or a
        jr nz,.bad
        inc d
        pop bc
        djnz .t
        pop de
        inc e
        pop bc
        djnz .r
        ld a,(bmode)
        call bld_can
        ret c
        ld a,(bmode)
        call bt_hl
        inc hl
        inc hl
        inc hl
        call pay
        ret c
        ld de,(bp_ij)
        ld a,(bmode)
        ld c,0
        call bld_new
        ret c
        call bld_redraw         ; το θεμέλιο στην οθόνη
        call bidx               ; οι επιλεγμένοι χωρικοί: να το χτίσουν
        ld (bp_slot),a
        ld a,(sel_n)
        ld b,a
        ld hl,SELLIST
.v:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push bc
        push hl
        push de
        pop ix
        push ix
        pop iy
        call is_villager
        call z,build_go
        pop hl
        pop bc
        djnz .v
        ld a,255
        ld (bmode),a
        jp cur_look
.bad:   pop bc
        pop de
        pop bc
        ret

; IX = χωρικός: πάει στο ελεύθερο πλακίδιο γύρω από το κτίριο bp_slot που
; είναι πιο κοντά του.
build_go:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(bp_slot)
        ld (hl),a
        set 7,l                 ; J_SJ = 0: δεν ξεκίνησε ακόμα (το bld_job, στην
        ld (hl),0               ; απόφασή του: όχι όλοι στο καρέ της εντολής)
        ld (ix+U_JOB),J_BUILD
        res F_MOVE,(ix+U_FL)
        ret

; IX = χωρικός με J_BUILD που δεν ξεκίνησε: στο πλακίδιο δίπλα στο κτίριο.
build_walk:
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_SJ >> 8
        ld (hl),1
        call unit_sp
        call bld_ring           ; (IY = το κτίριο)
        jp c,job_idle
        call tile_target
        jp job_walk

; ------------------------------------------------------------ ανέγερση

; IX = χωρικός με J_BUILD που στέκεται (από το job_tick): αν είναι δίπλα
; στο κτίριο, +1 πόντος· με τους πόντους του τύπου, έτοιμο.
bld_job:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(hl)
        call brec_iy
        ld a,(iy+B_TYPE)
        inc a
        jp z,job_idle
        ld a,(iy+B_ST)
        or a
        jp nz,job_idle          ; το τελείωσαν άλλοι
        ld l,(ix+U_IDX)         ; δεν ξεκίνησε ακόμα
        set 7,l
        ld h,J_SJ >> 8
        ld a,(hl)
        or a
        jr z,build_walk
        call unit_tile          ; δίπλα: στο τετράγωνο (i0 - 1 .. i0 + n)
        ld a,(iy+B_TYPE)
        call bt_hl
        ld c,(hl)
        inc c
        inc c                   ; C = n + 2
        ld hl,(n_i)
        call clamp95
        sub (iy+B_I)
        inc a
        cp c
        jp nc,job_idle
        ld hl,(n_j)
        call clamp95
        sub (iy+B_J)
        inc a
        cp c
        jp nc,job_idle
        inc (iy+B_PROG)
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_PTS
        add hl,de
        ld a,(iy+B_PROG)
        cp (hl)
        ret c
        ld (iy+B_ST),1          ; έτοιμο: η εικόνα του
        ld (iy+B_PROG),0
        ld a,1                  ; και μπορεί να κρύβει μονάδες (occlude.asm)
        ld (occ_dirty),a
        call bld_redraw
        jp job_idle


; ---- από το game/buildings.asm (M11)

; ------------------------------------------------------------ κάρτα

; Σε κάθε καρέ μονάδων: η κάρτα του HUD. Με κτίριο επιλεγμένο, το μέγεθος της
; ουράς του (ψηφίο) και η πρόοδος (μπάρα 12 pixels) — της ανέγερσης όσο
; είναι θεμέλιο, αλλιώς της μονάδας που εκπαιδεύεται. Χωρίς: κενή (μία φορά).
hud_card:
        ld a,(sel_bld)
        cp 255
        jr nz,.on
        ld hl,card_on
        ld a,(hl)
        or a
        ret z
        ld (hl),0
        ld a,10
        call card_digit
        xor a
        jr card_bar
.on:    ld a,1
        ld (card_on),a
        ld a,(sel_bld)
        call brec_iy
        ld a,(iy+B_QN)
        call card_digit
        ld hl,res_card          ; έρευνα (M9): η μπάρα της
        call far7
        cp 255
        jr nz,card_bar
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_PTS
        ld a,(iy+B_ST)
        or a
        jr z,.f
        ld de,BT_UTIME
        ld a,(iy+B_QN)
        or a
        jr z,card_bar           ; (A = 0)
.f:     add hl,de
        ld e,(hl)               ; pixels = πρόοδος x 12 / μέγιστο
        ld d,0
        ld l,(iy+B_PROG)
        ld h,d
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,hl
        add hl,hl
        ld b,-1
.d:     inc b
        or a
        sbc hl,de
        jr nc,.d
        ld a,b

; A = πόσα pixels (0..12) γεμάτα: η μπάρα της κάρτας.
card_bar:
        ld c,a
        ld hl,HUD_PAGE + (CARD_BY & 7) * #800 + (CARD_BY >> 3) * 80 + CARD_X
        ld b,6
.b:     ld d,CARD_EMPTY
        ld a,c
        or a
        jr z,.w
        dec c
        ld d,CARD_HALF
        jr z,.w
        dec c
        ld d,CARD_FULL
.w:     ld (hl),d
        inc hl
        djnz .b
        ret

; A = ψηφίο (0-9, 10 κενό): στην κάρτα.
card_digit:
        ld l,a                  ; DE = digits + 10 A
        add a,a
        add a,a
        add a,l
        add a,a
        ld e,a
        ld d,0
        ld hl,digits
        add hl,de
        ex de,hl
        ld hl,card_rows
        ld b,5
.l:     ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        inc hl
        djnz .l
        ret

card_rows:
cl_ = CARD_Y
        repeat 5
        dw HUD_PAGE + (cl_ & 7) * #800 + (cl_ >> 3) * 80 + CARD_X
cl_ = cl_ + 1
        rend

