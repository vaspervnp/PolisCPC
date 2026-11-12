; boot.asm — ό,τι τρέχει ΜΙΑ φορά, στην εκκίνηση (M9).
;
; Ο κύριος κώδικας (#0040-#3FFF) γέμισε. Οι ρουτίνες της εκκίνησης ζουν
; εδώ: συναρμολογημένες για το BOOT (#7A30, γραμμές της σελίδας του HUD που
; δεν φαίνονται και δεν τις χρησιμοποιεί κανένας πίνακας), ταξιδεύουν στο
; POLIS.BIN μετά τον κώδικα της C7, και το `start` τις αντιγράφει εκεί
; πρώτο απ' όλα. Το hud_init καθαρίζει τη σελίδα ΜΟΝΟ ως το BOOT. Μετά την
; εκκίνηση η περιοχή είναι ελεύθερη (game/bank7.asm: το AGE_BUF).
;
; ΔΕΝ αλλάζουν τράπεζα στο #4000 (θα χανόταν ο κώδικας που τρέχει).
;
; ΚΑΙ ΜΕΤΑ ΤΗΝ ΕΚΚΙΝΗΣΗ: κανείς δεν γράφει εδώ, άρα ρουτίνες που τρέχουν με
; την C0 (η σελίδα του HUD στο #4000) και δεν αλλάζουν τράπεζα μπορούν να
; ζουν εδώ και στο παιχνίδι — το HUD της μπάρας (hud_update, M6).

; ---- από το game/units.asm

; Οι 128 μονάδες.
units_init:
        ld hl,UNIT_TAB          ; όλα μηδέν
        ld de,UNIT_TAB + 1
        ld bc,(UNITS + 2) * U_SIZE - 1
        ld (hl),0
        ldir
        ld hl,ACT_TAB
        ld b,UNITS
.za:    ld (hl),0
        inc hl
        djnz .za
        xor a
.u:     push af
        call idx_ix
        pop af
        push af
        ld (ix+U_IDX),a
        ld (ix+U_SY),255
        ld c,a                  ; σετ = i mod 3
.mod:   sub 3
        jr nc,.mod
        add a,3
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
        ld a,c
        cp TOWN_UNITS
        jr nc,.far
        and 3                   ; οι πρώτες: στην πόλη, 4 στήλες ανά 16 bytes
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,TOWN_X
        add hl,de
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld a,c                  ; ... και σειρές ανά 32 γραμμές
        and #FC
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TOWN_Y
        add hl,de
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        jr .pos
.far:   cp UNITS_LIVE           ; οι τελευταίες: ελεύθερες θέσεις (M7), μακριά
        jr c,.wan               ; από τον κόσμο, για όσες θα βγουν
        ld (ix+U_TEAM),TEAM_FREE
        ld (ix+U_WY+1),2000 >> 8
        jr .pos
.wan:   call rnd_pos            ; οι υπόλοιπες: τυχαία, έξω από την αρχική οθόνη
        set F_WANDER,(ix+U_FL)  ; — η άλλη ομάδα· ουδέτερες στη μάχη (NT)
        ld (ix+U_TEAM),1
        ld a,1
        call nt_put
.pos:   ld l,(ix+U_WX)          ; ο στόχος = εκεί που είναι
        ld h,(ix+U_WX+1)
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        pop af
        inc a
        cp UNITS
        jp nz,.u
        ld ix,ANCHOR_REC        ; η γωνία και ο κέρσορας: σταθερό καρέ, ποτέ
        ld hl,SPR_ANCHOR        ; στο ORDER των μονάδων
        call .fixed
        ld ix,CURSOR_REC
        ld hl,SPR_CURSOR
.fixed: set F_FIXED,(ix+U_FL)
        ld (ix+U_FRAME),l
        ld (ix+U_FRAME+1),h
        set F_ORD,(ix+U_FL)
        ld (ix+U_SY),255
        ret

; IX: τυχαία θέση στον κόσμο, έξω από την αρχική οθόνη (+ περιθώριο).
rnd_pos:
        call rnd                ; WX = (r AND 255) + (r' AND 127), ≤ 380
        ld e,a
        ld d,0
        push de
        call rnd
        pop de
        and 127
        ld l,a
        ld h,0
        add hl,de
        ld de,WORLD_W
        call min_hl_de
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        call rnd                ; WY = r(0..511) + r'(0..255), ≤ 740
        push af
        call rnd
        and 1
        ld d,a
        pop af
        ld e,a
        push de
        call rnd
        pop de
        ld l,a
        ld h,0
        add hl,de
        ld de,WORLD_H
        call min_hl_de
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        ld de,280               ; μέσα στο [80,200) x [280,470): ξανά
        or a
        sbc hl,de
        ret c
        ld de,190
        or a
        sbc hl,de
        ret nc
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld de,80
        or a
        sbc hl,de
        ret c
        ld de,120
        or a
        sbc hl,de
        jr c,rnd_pos
        ret

; ---- από το game/pathing.asm

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

; ---- από το game/buildings.asm

bld_init:
        ld hl,BLD_TAB           ; όλα ελεύθερα
        ld b,0
.c:     ld (hl),255
        inc l
        djnz .c
        ld hl,BLD_TAB2
        ld b,(BLD_MAX - BLD_N1) * B_SIZE
.c2:    ld (hl),255
        inc l
        djnz .c2
        ld a,255
        ld (bmode),a
        ld (sel_bld),a
        ld (bk_prev),a
        ld (rq_n),a
        xor a                   ; το Κέντρο Πόλης, έτοιμο
        ld d,TC_I
        ld e,TC_J
        ld c,1
        jp bld_new

; ---- από το game/gather.asm

gather_init:
        ld hl,SRC_TAB + 1       ; όλες οι πηγές ελεύθερες
        ld b,SRC_N
.s:     ld (hl),#FF
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .s
        ld hl,J_CARRY           ; καμία δεν κουβαλάει τίποτα
        call zero_page
        ld hl,J_SI
        call zero_page
        ld a,#3F                ; και οι 6 αριθμοί
        ld (hud_dirty),a
        jp hud_update

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

; ---- από το game/screen.asm

; Το HUD στην κύρια RAM #4000 (με τις τράπεζες στη θέση τους): οι 7 σειρές
; κάθε οκτάδας αποσυμπιέζονται στην οθόνη και πάνε στη θέση τους· τα
; υπόλοιπα μηδέν (οι σειρές 7-20 του καρέ Β φαίνονται: μαύρο).
HUD_ROWS    equ 7
hud_init:
        ld hl,hud_z
        ld de,SCREEN
        call dzx0
        ld hl,HUD_PAGE          ; όλη η σελίδα ως το BOOT (main.asm)
        ld de,HUD_PAGE + 1
        ld bc,BOOT - HUD_PAGE - 1
        ld (hl),0
        ldir
        ld hl,SCREEN
        ld de,HUD_PAGE
        ld a,8
.k:     ld bc,HUD_ROWS * 80
        ldir
        ex de,hl                ; DE += #800 - 560
        ld bc,#800 - HUD_ROWS * 80
        add hl,bc
        ex de,hl
        dec a
        jr nz,.k
        ld de,digits            ; και τα ψηφία, στις γραμμές που δεν φαίνονται
        ld bc,DIGITS_LEN
        ldir
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
