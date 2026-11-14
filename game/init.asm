; init.asm — ό,τι τρέχει ΜΙΑ φορά, στην εκκίνηση (M11).
;
; Συναρμολογημένο για το INIT (#E000: η μνήμη της οθόνης). Το `start` το
; αντιγράφει εκεί μετά το units_gfx (που χρησιμοποιεί όλη την οθόνη ως
; ενδιάμεσο χώρο) και πριν το hud_init (που χρησιμοποιεί μόνο ως το
; ~#D200)· το clear_screen (στο BOOT) τρέχει όταν τελειώσουν όλα.
;
; Ως το M10 ζούσαν στο BOOT (boot.asm), που έγινε πια μόνο για ρουτίνες
; που μένουν και στο παιχνίδι.

; ---- από το game/units.asm

; Η πίστα (M13): η κεφαλίδα της από το LV_HDR (το μενού), αλλιώς η
; παρτίδα του χάρτη της εκκίνησης (lv_def), στο lv_h — για το
; units_init, το bld_init, το fog_init, το rnd_pos. Και από εκεί: η κάμερα,
; οι πόροι, ο πολιτισμός, και ό,τι κρατάει η C7 (lv_c7: ο αντίπαλος, ο
; στόχος, η εκστρατεία).
lv_init:
        ld hl,LV_HDR
        ld a,(hl)
        cp #A5
        jr nz,.def
        inc hl
        ld a,(hl)
        dec hl
        cp #5A
        jr z,.cp
.def:   ld hl,lv_def
.cp:    ld de,lv_h
        ld bc,H_TEXT
        ldir
        ld a,(tut_on)           ; το tutorial (menu.asm): η παρτίδα του χάρτη
        or a                    ; της εκκίνησης, με το πρώτο κύμα αργά
        jr z,.nt
        ld hl,TUT_COOL
        ld (lv_h + H_COOL),hl
.nt:
        xor a
        ld (LV_HDR),a
        ld a,RAM_CMP
        call setram
        ld hl,lv_h + H_ROUTE
        ld de,lv_c7
        ld bc,H_TEXT - H_ROUTE
        ldir
        ld a,RAM_BASE
        call setram
        ld hl,(lv_h + H_CAM)
        ld (cam_x),hl
        ld hl,(lv_h + H_CAM + 2)
        ld (cam_y),hl
        ld hl,lv_h + H_RES
        ld de,hud_val
        ld bc,8
        ldir
        ld a,(lv_h + H_CULT)
        or a
        ret z
        ld (age3_name + 4),a
        ld (age4_name + 4),a
        ret

        include "../data/lvdef.asm"
lv_h:     ds H_TEXT

; Οι 128 μονάδες.
units_init:
        call lv_init
        ld a,(town_full)        ; ο πληθυσμός της μπάρας
        or a
        jr z,.n3
        ld a,TOWN_UNITS
        ld (hud_val + 8),a
.n3:
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
        ld hl,(lv_h + H_TOWN)
        ld de,(lv_h + H_TOWN + 2)
        cp TOWN_UNITS
        jr c,.town
        sub TOWN_UNITS          ; οι επόμενες TOWN_UNITS: η πόλη του
        cp TOWN_UNITS           ; αντιπάλου (M10), ίδια διάταξη
        ld a,c
        jr nc,.far
        sub TOWN_UNITS
        ld (ix+U_TEAM),1
        ld hl,(lv_h + H_AIU)
        ld de,(lv_h + H_AIU + 2)
.town:  ld b,a                  ; οι πρώτες: στην πόλη, 4 στήλες ανά 16
        ld a,(town_full)        ; bytes — μόνο οι χωρικοί 0, 3, 6 (σετ 0)·
        or a                    ; οι άλλες θέσεις ελεύθερες (town_full:
        ld a,b                  ; όλες, για τους ελέγχους)
        jr nz,.gw
        cp START_VIL * 3
        jr nc,.free
        ld a,(ix+U_SET)
        or a
        jr nz,.free
        ld a,b                  ; 0, 3, 6 -> οι θέσεις 5, 6, 7 της
        srl a                   ; διάταξης: μαζί, στη μεσαία σειρά
        cp 3
        jr nz,.gv
        dec a
.gv:    add a,5
        ld b,a
.gw:    and 3
        add a,a
        add a,a
        add a,a
        add a,a
        push de
        ld e,a
        ld d,0
        add hl,de
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld a,b                  ; ... και σειρές ανά 32 γραμμές
        and #FC
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        pop de
        add hl,de
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        jr .pos
.far:   cp UNITS_LIVE           ; οι τελευταίες: ελεύθερες θέσεις (M7), μακριά
        jr c,.wan               ; από τον κόσμο, για όσες θα βγουν
.free:  ld (ix+U_TEAM),TEAM_FREE
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
        ld de,(lv_h + H_TOWN + 2)     ; μέσα στο [x - 26, x + 94) x
        or a                    ; [y - 50, y + 140) γύρω από την πόλη: ξανά
        sbc hl,de
        ld de,50
        add hl,de
        bit 7,h
        ret nz
        ld de,190
        or a
        sbc hl,de
        ret nc
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld de,(lv_h + H_TOWN)
        or a
        sbc hl,de
        ld de,26
        add hl,de
        bit 7,h
        ret nz
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
        ld de,(lv_h + H_TC)   ; (D = i, E = j)
        ld c,1
        call bld_new
        xor a                   ; και του αντιπάλου (M10)
        ld de,(lv_h + H_AITC)
        ld c,1
        call bld_new
        ld (iy+B_OWN),1
        ret

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

; ---- από το game/screen.asm

; Το HUD στην κύρια RAM #4000 (με τις τράπεζες στη θέση τους): οι 7 σειρές
; κάθε οκτάδας αποσυμπιέζονται στην οθόνη και πάνε στη θέση τους· τα
; υπόλοιπα μηδέν (οι σειρές 7-20 του καρέ Β φαίνονται: μαύρο).
; HL = hud_z (το start: μέσα στο init_z ο rasm το υπολογίζει λάθος, M14).
hud_init:
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
        ld hl,HIA_AT            ; οι ρουτίνες στις κρυφές σειρές (main.asm)
        ld de,HI_A
        ld bc,HIA_LEN
        ldir
        ld de,HI_B
        ld bc,HIB_LEN
        ldir
        ld de,HI_C
        ld bc,HIC_LEN
        ldir
                                ; (πέφτει στο rpose_init)

; Οι πόζες της επίθεσης των κόκκινων (red_pose, units.asm): από τα σετ της
; C5, με τα δεδομένα μέσα από το TR1 (μάσκα, δεδομένα ανά byte), μέσω της
; οθόνης, στο RPOSE της σελίδας του HUD.
rpose_init:
        ld ix,rp_tab
        ld de,RPOSE
        ld b,8
        call .set
        ld de,RPOSE2
        ld b,6
.set:
.f:     push bc
        push de
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix
        inc ix
        ld a,RAM_SPR
        call setram
        ld de,SCREEN
        ld b,64
.b:     ld a,(hl)               ; η μάσκα
        ld (de),a
        inc hl
        inc de
        ld a,(hl)               ; τα δεδομένα, μεταφρασμένα
        push hl
        ld l,a
        ld h,TR1 >> 8
        ld a,(hl)
        pop hl
        ld (de),a
        inc hl
        inc de
        djnz .b
        ld a,RAM_BASE
        call setram
        pop de
        ld hl,SCREEN
        ld bc,128
        ldir
        pop bc
        djnz .f
        ret
rp_tab:
rps = 1
        repeat 2
        dw SPR_BASE + rps * SPR_STRIDE + ATK_W * 128
        dw SPR_BASE + rps * SPR_STRIDE + 13 * 128
        dw SPR_BASE + rps * SPR_STRIDE + 15 * 128
        dw SPR_BASE + rps * SPR_STRIDE + 17 * 128
rps = rps + 1
        rend
rps = 1                         ; ο θάνατος (RPOSE2)
        repeat 2
        dw SPR_BASE + rps * SPR_STRIDE + 18 * 128
        dw SPR_BASE + rps * SPR_STRIDE + 19 * 128
        dw SPR_BASE + rps * SPR_STRIDE + 20 * 128
rps = rps + 1
        rend


; ---- ο εξερευνημένος χάρτης (M11, fog.asm)

; Γύρω από το Κέντρο Πόλης (17 x 17) και από κάθε μονάδα του παίκτη. Το
; FD_TAB ελεύθερο ΜΕΤΑ: η πρώτη σχεδίαση τα ζωγραφίζει όλα.
fog_init:
        ld hl,SVM_AT            ; η αποθήκευση (savegame.asm) στις κρυφές
        ld de,SVM_STORE         ; σειρές της σελίδας του HUD (M12)
        ld bc,SVM_LEN
        ldir
        ld a,(load_req)         ; το μενού διάλεξε φόρτωμα: όλα από τη
        or a                    ; δισκέτα — αν βρεθεί παρτίδα
        jr z,.new
        ld hl,SVM_AT
        ld de,SVM
        ld bc,SVM_LEN
        ldir
        call mod_load
        jr nc,load_cont
.new:   ld a,(fog_on)           ; χωρίς ομίχλη: όλα εξερευνημένα
        or a
        jr nz,.on
        ld a,RAM_RES
        call setram
        ld hl,FOG
        ld de,FOG + 1
        ld bc,FOG_LEN - 1
        ld (hl),255
        ldir
        ld a,RAM_BASE
        jp setram
.on:    ld de,(lv_h + H_TC)   ; 3 x 3 σημεία ανά 4 από το (i - 2, j - 2)
        dec d
        dec d
        ld b,3
.i:     push bc
        ld a,(lv_h + H_TC)
        sub 2
        ld e,a
        ld b,3
.j:     push bc
        push de
        call fog_reveal
        pop de
        pop bc
        ld a,e
        add a,4
        ld e,a
        djnz .j
        pop bc
        ld a,d
        add a,4
        ld d,a
        djnz .i
        xor a
.u:     push af
        call idx_ix
        ld a,(ix+U_TEAM)
        or a
        jr nz,.n
        call unit_tile
        call unit_reveal
.n:     pop af
        inc a
        cp UNITS
        jr nz,.u
        ld hl,FD_TAB
        ld b,FD_N * 6
.f:     ld (hl),255
        inc hl
        djnz .f
        ret

; Μετά το φόρτωμα της παρτίδας (M12): οι εικόνες της εποχής της και ο
; οπλίτης ξανά από τη δισκέτα, όπως στο παιχνίδι (age_load: η εποχή
; ανεβαίνει από τη 2 — και ο πίνακας bld_types, που δεν σώζεται).
load_cont:
        xor a                   ; το tutorial δεν συνεχίζει σε σωσμένη παρτίδα
        ld (tut_on),a           ; (τα δεδομένα του στην C6 δεν σώζονται)
        ld (tut_win),a
        ld a,(hud_val + 10)
        cp 3
        ret c
        ld hl,(hud_dirty)       ; ό,τι γράφει το age_apply πέρα από τις
        push hl                 ; εικόνες: όπως ήταν στην παρτίδα (αλλιώς
        ld hl,(occ_dirty)       ; ξαναζωγραφίζει κτίρια, και η παρτίδα δεν
        push hl                 ; συνεχίζει ίδια)
        ld hl,(age_q)
        push hl
        push af
        ld a,2
        ld (hud_val + 10),a
        ld a,3
        ld (age_req),a
        call age_load
        pop af
        cp 4
        jr c,.back
        ld a,4
        ld (age_req),a
        call age_load
.back:  pop hl
        ld a,l
        ld (age_q),a
        pop hl
        ld a,l
        ld (occ_dirty),a
        pop hl
        ld a,l
        ld (hud_dirty),a
        ret
