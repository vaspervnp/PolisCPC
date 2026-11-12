; buildings.asm — κτίρια: τοποθέτηση, ανέγερση, ουρά παραγωγής. M7.
;
; ΣΤΟΝ ΧΑΡΤΗ. Κάθε πλακίδιο της κάτοψης παίρνει τον πόρο BLD_RES (13):
; εμπόδιο για την εύρεση δρόμου, χωρίς sprite. Όσο χτίζεται (θεμέλιο), το
; έδαφος της κάτοψης γίνεται «χώμα τραχύ»· όταν τελειώσει, ζωγραφίζεται η
; εικόνα του (τράπεζα C6, src/make_bank6.py).
;
; Η ΣΕΙΡΑ ΤΟΥ ΖΩΓΡΑΦΟΥ. Το κτίριο έχει «βάθος» τη σειρά ρόμβων του ΜΠΡΟΣΤΙΝΟΥ
; του πλακιδίου (i0 + j0 + 2(n-1)) και ζωγραφίζεται ΜΕΤΑ από όλους τους
; πόρους της σειράς του και ΠΡΙΝ από τους πόρους της επόμενης. Το ίδιο και
; στις τρεις σχεδιάσεις: ολόκληρο το παράθυρο (res.asm), η στήλη της
; οριζόντιας κύλισης και το κομμάτι της (scroll.asm, gather.asm), η σειρά
; της κάθετης. Σε καθεμία: πρώτα τα «υποψήφια» (bld_cands: όσα τέμνουν την
; περιοχή, ταξινομημένα κατά βάθος), και πριν από τα sprites κάθε σειράς r
; τα υποψήφια με βάθος < r (bld_flush). Στη στήλη αυτό γίνεται μετά το
; έδαφος της ομάδας: το κάτω άκρο του κτιρίου είναι 2 γραμμές κάτω από αυτό
; των sprites της σειράς του.
;
; ΤΟ ΔΕΝΤΡΟ. Ένας τύπος χτίζεται αν η εποχή ≥ η ελάχιστη του και ο παίκτης
; έχει ήδη ολοκληρωμένο το προαπαιτούμενο (data/bld.asm).
;
; ΠΛΗΚΤΡΑ. Με χωρικούς επιλεγμένους: C H B G S M R L F W = τύπος κτιρίου
; (ο κέρσορας γίνεται γωνία), RETURN = εδώ (κέντρο της κάτοψης), ESC =
; άκυρο. Με κτίριο επιλεγμένο (κλικ πάνω του): T = μία μονάδα στην ουρά.

; Ο πίνακας σε ΔΥΟ κομμάτια (θέση 0..27): 16 εγγραφές στη σελίδα #A400 (το
; SWAP_TAB, που χρειάζεται μόνο στην εκκίνηση) και 12 στο #BE40, αμέσως μετά
; το UNIT_TAB. (Όχι στο #AD00: εκεί γράφει το buffer γραμμής της κάθετης
; κύλισης, BUF_A + #800.) Ελεύθερη εγγραφή: τύπος 255.
BLD_TAB     equ #A400
BLD_TAB2    equ #BE40
BLD_N1      equ 16
BLD_MAX     equ 28
B_SIZE      equ 16
B_TYPE      equ 0
B_OWN       equ 1
B_I         equ 2               ; η πίσω γωνία της κάτοψης
B_J         equ 3
B_ST        equ 4               ; 0 θεμέλιο, 1 έτοιμο
B_DEP       equ 5               ; το βάθος (η σειρά ρόμβων του μπροστινού)
B_WX        equ 6               ; dw: το αριστερό byte της εικόνας (κόσμος)
B_WYB       equ 8               ; dw: η γραμμή κάτω από την εικόνα (κόσμος)
B_W         equ 10              ; πλάτος σε bytes δεδομένων
B_H         equ 11
B_IMG       equ 12              ; dw: στην C6
B_PROG      equ 14              ; πόντοι ανέγερσης, μετά καρέ εκπαίδευσης
B_QN        equ 15              ; μονάδες στην ουρά

BT_FOOT     equ 0               ; ο πίνακας τύπων (data/bld.asm)
BT_AGE      equ 1
BT_PRE      equ 2
BT_COST     equ 3
BT_PTS      equ 7
BT_W        equ 8
BT_H        equ 9
BT_UNIT     equ 10
BT_UCOST    equ 11
BT_UTIME    equ 15
BT_IMG      equ 16

J_BUILD     equ 4               ; η δουλειά του χωρικού (gather.asm)
QMAX        equ 5
CAND_MAX    equ 8
UNITS_LIVE  equ 80              ; οι υπόλοιπες ως 128: ελεύθερες θέσεις (M10: 48, για τις δύο ομάδες)
TEAM_FREE   equ 255
FOUND_BYTE  equ (4 << 4) | BLD_RES ; θεμέλιο: χώμα τραχύ + πλακίδιο κτιρίου
TC_I        equ 30              ; το Κέντρο Πόλης του παίκτη
TC_J        equ 58
AI_TC_I     equ 58              ; του αντιπάλου (M10)
AI_TC_J     equ 27
AI_X        equ 242             ; οι μονάδες του: πάνω-αριστερά (boot.asm)
AI_Y        equ 350

; ------------------------------------------------------------ εκκίνηση

; A = τύπος -> HL = η εγγραφή του στο bld_types (18 A). Κρατάει DE, BC.
bt_hl:  push de
        ld l,a
        ld h,0
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ld de,bld_types
        add hl,de
        pop de
        ret

; A = θέση -> IY = η εγγραφή του κτιρίου.
brec_iy:
        cp BLD_N1
        jr nc,.b
        rlca
        rlca
        rlca
        rlca
        ld iyl,a
        ld a,BLD_TAB >> 8
        ld iyh,a
        ret
.b:     sub BLD_N1
        rlca
        rlca
        rlca
        rlca
        add a,BLD_TAB2 & 255
        ld iyl,a
        ld a,BLD_TAB2 >> 8
        ld iyh,a
        ret

; IY = εγγραφή -> A = η θέση της.
bidx:   ld a,iyh
        cp BLD_TAB >> 8
        ld a,iyl
        jr z,.a
        sub BLD_TAB2 & 255
        rrca
        rrca
        rrca
        rrca
        add a,BLD_N1
        ret
.a:     rrca
        rrca
        rrca
        rrca
        ret

; IY -> η επόμενη εγγραφή (από το τέλος του πρώτου κομματιού στο δεύτερο).
; Κρατάει BC, DE, HL.
bnext:  push de
        ld de,B_SIZE
        add iy,de
        pop de
        ld a,iyh
        cp (BLD_TAB >> 8) + 1
        ret nz
        ld iy,BLD_TAB2
        ret

; A = τύπος, D = i0, E = j0, C = κατάσταση -> IY = νέο κτίριο του παίκτη, η
; κάτοψη στον χάρτη. Carry αν δεν χωράει άλλο.
bld_new:
        ld (bn_t),a
        ld iy,BLD_TAB
        ld b,BLD_MAX
.f:     ld a,(iy+B_TYPE)
        inc a
        jr z,.got
        call bnext
        djnz .f
        scf
        ret
.got:   ld a,BLD_MAX + 1        ; bld_top = max(bld_top, θέση + 1)
        sub b
        ld hl,bld_top
        cp (hl)
        jr c,.top
        ld (hl),a
.top:   ld a,1                  ; occlude.asm: η λίστα ξανά
        ld (occ_dirty),a
        ld (iy+B_ST),c
        ld (iy+B_OWN),0
        ld (iy+B_I),d
        ld (iy+B_J),e
        ld (iy+B_PROG),0
        ld (iy+B_QN),0
        ld a,(bn_t)
        ld (iy+B_TYPE),a
        call bt_hl
        ld a,(hl)               ; n
        ld (bn_n),a
        dec a                   ; βάθος = i0 + j0 + 2 (n - 1)
        add a,a
        add a,d
        add a,e
        ld (iy+B_DEP),a
        push hl
        ld l,a                  ; κάτω από την εικόνα: 4 βάθος + 8
        ld h,0
        add hl,hl
        add hl,hl
        ld bc,8
        add hl,bc
        ld (iy+B_WYB),l
        ld (iy+B_WYB+1),h
        ld a,d                  ; αριστερά: 2 (i0 - j0) + 192 - 2 n
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,192
        add hl,bc
        ld a,(bn_n)
        add a,a
        ld c,a
        ld b,0
        or a
        sbc hl,bc
        ld (iy+B_WX),l
        ld (iy+B_WX+1),h
        pop hl
        push hl
        ld bc,BT_W
        add hl,bc
        ld a,(hl)
        ld (iy+B_W),a
        inc hl
        ld a,(hl)
        ld (iy+B_H),a
        pop hl
        ld bc,BT_IMG
        add hl,bc
        ld a,(hl)
        ld (iy+B_IMG),a
        inc hl
        ld a,(hl)
        ld (iy+B_IMG+1),a
        ld a,(bn_n)             ; η κάτοψη στον χάρτη
        ld b,a
.r:     push bc
        push de
        ld a,(bn_n)
        ld b,a
.t:     push bc
        call map_ptr
        ld a,(iy+B_ST)
        or a
        ld a,FOUND_BYTE
        jr z,.w
        ld a,(hl)
        and #F0
        or BLD_RES
.w:     ld (hl),a
        inc d
        pop bc
        djnz .t
        pop de
        inc e
        pop bc
        djnz .r
        or a
        ret

; ------------------------------------------------------------ σχεδίαση

; Τα κτίρια που τέμνουν την περιοχή rg_x0..rg_x1 (bytes οθόνης), rg_y0..
; rg_y1 (γραμμές) -> cand (low bytes των εγγραφών), κατά βάθος· cand_k = 0,
; cand_n = πόσα μένουν.
bld_cands:
        xor a
        ld (cand_n),a
        ld (cand_k),a
        ld (cand_c),a
        ld iy,BLD_TAB
        ld a,(bld_top)          ; ως την ψηλότερη θέση που πιάστηκε
        ld b,a
.l:     push bc
        ld a,(iy+B_TYPE)
        inc a
        jp z,.n
        ld a,(iy+B_ST)          ; θεμέλιο: καμία εικόνα
        or a
        jp z,.n
        ld l,(iy+B_WX)          ; sx < x1
        ld h,(iy+B_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.x1
        ld a,h
        or a
        jp nz,.n
        ld a,(rg_x1)
        ld c,a
        ld a,l
        cp c
        jp nc,.n
.x1:    ld e,(iy+B_W)           ; sx + w > x0
        ld d,0
        add hl,de
        bit 7,h
        jp nz,.n
        ld a,h
        or a
        jr nz,.x0
        ld a,(rg_x0)
        ld c,a
        ld a,l
        cp c
        jp c,.n
        jp z,.n
.x0:    ld l,(iy+B_WYB)         ; κάτω > y0
        ld h,(iy+B_WYB+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        bit 7,h
        jr nz,.n
        ld a,h
        or a
        jr nz,.y0
        ld a,(rg_y0)
        ld c,a
        ld a,l
        cp c
        jr c,.n
        jr z,.n
.y0:    ld e,(iy+B_H)           ; πάνω < y1
        ld d,0
        or a
        sbc hl,de
        bit 7,h
        jr nz,.add
        ld a,h
        or a
        jr nz,.n
        ld a,(rg_y1)
        ld c,a
        ld a,l
        cp c
        jr nc,.n
.add:   ld a,(cand_c)           ; με εισαγωγή, κατά βάθος: ζεύγη (θέση,
        cp CAND_MAX             ; βάθος)
        jr nc,.n
        ld e,a
        inc a
        ld (cand_c),a
        ld (cand_n),a
        ld d,0
        ld hl,cand
        add hl,de
        add hl,de
        ld c,(iy+B_DEP)
.ins:   ld a,e                  ; HL = cand + 2 e
        or a
        jr z,.put
        dec hl                  ; το βάθος του προηγούμενου
        ld a,(hl)
        cp c
        jr c,.put1
        jr z,.put1
        inc hl                  ; μετακινείται ένα πάνω: βάθος -> 2e + 1
        inc hl
        ld (hl),a
        dec hl
        dec hl
        dec hl
        ld a,(hl)               ; θέση -> 2e
        inc hl
        inc hl
        ld (hl),a
        dec hl
        dec hl                  ; HL = cand + 2 (e - 1)
        dec e
        jr .ins
.put1:  inc hl
.put:   call bidx
        ld (hl),a
        inc hl
        ld (hl),c
.n:     call bnext
        pop bc
        dec b
        jp nz,.l
        ret

; HL = σειρά ρόμβων (με πρόσημο) -> bld_flush με 0..255. Για τους βρόχους
; σειρών (res.asm, scroll.asm). Κρατάει όλους τους καταχωρητές εκτός AF.
row_flush:
        ld a,(cand_n)
        or a
        ret z
        push hl
        ld a,h
        or a
        ld a,l
        jr z,.ok
        ld a,h                  ; αρνητική: 0, ≥ 256: 255
        rla
        sbc a,a
        cpl
.ok:    call bld_flush
        pop hl
        ret

; A = σειρά r: τα υποψήφια με βάθος < r, με τη σειρά. Κρατάει BC, DE, IX.
bld_flush:
        ld (bf_r),a
.l:     ld a,(cand_n)
        or a
        ret z
        push bc
        push de
        ld a,(cand_k)
        ld e,a
        ld d,0
        ld hl,cand
        add hl,de
        add hl,de
        ld a,(hl)
        call brec_iy
        ld a,(bf_r)
        cp (iy+B_DEP)
        jr c,.no
        jr z,.no
        ld hl,cand_k
        inc (hl)
        ld hl,cand_n
        dec (hl)
        call blit_bld
        pop de
        pop bc
        jr .l
.no:    pop de
        pop bc
        ret

; HL (με πρόσημο), C = μέγιστο -> A = HL στο 0..C.
clamp_c:
        bit 7,h
        jr nz,.z
        ld a,h
        or a
        ld a,c
        ret nz
        ld a,l
        cp c
        ret c
        ld a,c
        ret
.z:     xor a
        ret

; IY = κτίριο: η εικόνα του, ψαλιδισμένη στην περιοχή rg_*. Με την C6 μέσα.
blit_bld:
        ld l,(iy+B_WX)          ; sx
        ld h,(iy+B_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        ld (bb_sx),hl
        ld c,(iy+B_W)
        ld a,(rg_x0)            ; c0 = x0 - sx στο 0..w
        call .rel
        ld (bb_c0),a
        ld a,(rg_x1)            ; c1 = x1 - sx στο 0..w
        call .rel
        ld b,a
        ld a,(bb_c0)
        sub b
        ret nc
        neg
        ld (bb_cn),a
        ld l,(iy+B_WYB)         ; sy = κάτω - h - cam_y
        ld h,(iy+B_WYB+1)
        ld e,(iy+B_H)
        ld d,0
        or a
        sbc hl,de
        ld de,(cam_y)
        or a
        sbc hl,de
        ld (bb_sx),hl           ; (προσωρινά: sy)
        ld c,(iy+B_H)
        ld a,(rg_y0)
        call .rel
        ld (bb_l0),a
        ld a,(rg_y1)
        call .rel
        ld b,a
        ld a,(bb_l0)
        sub b
        ret nc
        neg
        ld (bb_ln),a
        ld a,(bb_sx)            ; η πρώτη γραμμή οθόνης: sy + l0
        ld hl,bb_l0
        add a,(hl)
        ld (bb_y),a
        ld l,(iy+B_WX)          ; ξανά το sx (low): + c0
        ld a,(cam_x)
        ld h,a
        ld a,l
        sub h
        ld hl,bb_c0
        add a,(hl)
        ld (bb_x),a
        ld a,(iy+B_W)           ; πηγή: εικόνα + l0 * w + c0 (χωρίς μάσκα:
        ld (bb_w2),a            ; ένα byte ανά 2 pixels, M9)
        ld e,a
        ld d,0
        ld l,(iy+B_IMG)
        ld h,(iy+B_IMG+1)
        ld a,(bb_l0)
        or a
        jr z,.s0
        ld b,a
.m:     add hl,de
        djnz .m
.s0:    ld a,(bb_c0)
        ld e,a
        add hl,de
        push hl
        ld a,(bb_x)
        ld b,a
        ld a,(bb_y)
        call line_x             ; DE = η πρώτη γραμμή στην οθόνη
        pop hl
        ld a,(bb_cn)            ; μετά από κάθε γραμμή: + (w - cn)
        ld c,a
        ld a,(bb_w2)
        sub c
        ld (bb_w2),a
        push ix
        ld a,(bb_ln)
        ld ixh,a                ; IXH: οι γραμμές, IXL: τα bytes
.line:  push de
        ld a,c
        ld ixl,a
        ld b,MASK_PG >> 8       ; η μάσκα από τα δεδομένα (pen 0 = διάφανο)
.b:     ld c,(hl)
        inc hl
        ld a,(bc)
        ex de,hl
        and (hl)
        or c
        ld (hl),a
        ex de,hl
        inc e
        call z,de_carry
        dec ixl
        jr nz,.b
        pop de                  ; η επόμενη γραμμή: D + 8, ή η επόμενη σειρά
        ld a,d
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        ld a,(bb_w2)
        ld c,a
        ld b,0
        add hl,bc
        ld a,(bb_cn)
        ld c,a
        dec ixh
        jr nz,.line
        pop ix
        ret
.rel:   ld e,a                  ; A - (bb_sx) στο 0..C
        ld d,0
        ld hl,(bb_sx)
        ex de,hl
        or a
        sbc hl,de
        jp clamp_c

; Η περιοχή: όλο το παράθυρο χάρτη.
rg_full:
        xor a
        ld (rg_x0),a
        ld (rg_y0),a
        ld a,80
        ld (rg_x1),a
        ld a,VIEW_H
        ld (rg_y1),a
        ret

; ------------------------------------------------------------ επανασχεδίαση

; Ένα κτίριο άλλαξε (θεμέλιο, ολοκλήρωση): οι στήλες του ξαναζωγραφίζονται
; σε κομμάτια, ΜΙΑ ανά καρέ (rq_step, από το bld_tick), με το col_redraw του
; M6. Σε συντεταγμένες κόσμου: αν κυλήσει η κάμερα στο μεταξύ, οι στήλες
; που μένουν βρίσκονται σωστά. Το ίδιο για έναν πόρο που άδειασε (rq_set).
; IY = κτίριο.
bld_redraw:
        push iy                 ; (το rq_free ζωγραφίζει: αλλάζει το IY)
        call rq_free
        pop iy
        ld l,(iy+B_WX)
        ld h,(iy+B_WX+1)
        ld (rq_x),hl
        ld l,(iy+B_WYB)
        ld h,(iy+B_WYB+1)
        ld (rq_yb),hl
        ld a,(iy+B_TYPE)        ; ύψος: της εικόνας, τουλάχιστον της κάτοψης
        call bt_hl
        ld a,(hl)               ; (4 n γραμμές + τα sprites από πίσω: + 16)
        add a,a
        add a,a
        add a,16
        ld c,a
        ld a,(iy+B_H)
        cp c
        jr nc,.h
        ld a,c
.h:     ld (rq_h),a
        ld a,(iy+B_W)
        rrca                    ; στήλες των 2 bytes
        ld (rq_n),a
        ret

RQ_ROWS     equ 12              ; γραμμές ανά καρέ (πολλαπλάσιο του 4)
        assert RQ_ROWS == 12, 'rq_step: 3k x 4'

; Μία επανασχεδίαση τη φορά: αν υπάρχει άλλη στη μέση, τελειώνει τώρα.
rq_free:
        ld a,(rq_n)
        inc a
        ret z
        call rq_step
        jr rq_free

; HL = x, DE = y (κόσμος) της γωνίας ενός sprite πόρου 4 x 16: οι 2 στήλες
; του, στο rq.
rq_set: push hl
        push de
        call rq_free
        pop de
        pop hl
        ld (rq_x),hl
        ld hl,16
        add hl,de
        ld (rq_yb),hl
        ld a,16
        ld (rq_h),a
        ld a,2
        ld (rq_n),a
        ret

rq_step:
        ld a,(rq_n)
        inc a
        ret z                   ; καμία
        ld b,1
.c:     push bc
        ld hl,(rq_x)            ; η στήλη στην οθόνη
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp 80 - 1
        jr nc,.skip
        push af
        ld hl,(rq_yb)           ; κάτω, πάνω (στο 0..VIEW_H, πολλαπλάσια του 4)
        ld de,(cam_y)
        or a
        sbc hl,de
        push hl
        ld c,VIEW_H
        call clamp_c
        add a,3
        and #FC
        ld (col_y1),a
        pop hl
        ld a,(rq_h)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        call clamp_c
        and #FC
        ld (col_y0),a
        ld hl,col_y1
        cp (hl)
        pop bc                  ; B = η στήλη
        jr nc,.skip
        ld a,(rq_half)          ; ΣΕ ΚΟΜΜΑΤΙΑ ΤΩΝ RQ_ROWS ΓΡΑΜΜΩΝ (M9), ένα
        ld c,a                  ; ανά καρέ: μία στήλη ψηλού κτιρίου με τις
        add a,a                 ; μονάδες γύρω ξεπερνούσε τα 40 ms.
        add a,c                 ; y0 += RQ_ROWS x κομμάτι
        add a,a
        add a,a
        ld c,a
        ld a,(col_y0)
        add a,c
        ld (col_y0),a
        cp (hl)
        jr nc,.skip             ; (τίποτα άλλο σε αυτή τη στήλη)
        add a,RQ_ROWS
        cp (hl)
        jr nc,.last
        ld (hl),a               ; όχι το τελευταίο: ως εκεί, και η ίδια
        ld a,b                  ; στήλη στο επόμενο καρέ
        call col_redraw
        ld hl,rq_half
        inc (hl)
        pop bc
        ret
.last:  ld a,b
        call col_redraw
.skip:  xor a
        ld (rq_half),a
        ld hl,(rq_x)
        inc hl
        inc hl
        ld (rq_x),hl
        ld hl,rq_n
        dec (hl)
        pop bc
        jr z,.done
        dec b
        jp nz,.c
        ret
.done:  ld (hl),255
        ret

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

; IY = κτίριο -> D, E = το ελεύθερο πλακίδιο γύρω του πιο κοντά στο
; (sp_ui, sp_uj). Carry αν κανένα.
bld_ring:
        ld a,(iy+B_TYPE)
        call bt_hl
        ld c,(hl)
        inc c
        inc c
        ld a,(iy+B_I)
        dec a
        ld d,a
        ld a,(iy+B_J)
        dec a
        ld e,a
        jp near_free

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

; ------------------------------------------------------------ παραγωγή

; Σε κάθε καρέ μονάδων (μετά την απόφαση): ένα κομμάτι επανασχεδίασης, και
; οι ουρές των έτοιμων κτιρίων. Όταν μια μονάδα είναι έτοιμη, βγαίνει στο
; ελεύθερο πλακίδιο δίπλα στο κτίριο πιο κοντά στη μπροστινή του γωνία.
bld_tick:
        call rq_step
        call age_step
        ld hl,ai_tick           ; ο αντίπαλος (bank7.asm, M10)
        call far7
        ld a,(res_n)            ; έρευνες (bank7.asm, M9)
        or a
        jr z,.q
        ld hl,res_tick
        call far7
        ld a,(age_req)
        or a
        call nz,age_load
.q:     ld a,(bq_tot)           ; καμία ουρά: τίποτα άλλο
        or a
        ret z
        ld iy,BLD_TAB
        ld a,(bld_top)          ; ως την ψηλότερη θέση που πιάστηκε
        ld b,a
.l:     push bc
        ld a,(iy+B_TYPE)
        inc a
        jr z,.n
        ld a,(iy+B_QN)
        or a
        jr z,.n
        ld a,(iy+B_ST)
        or a
        jr z,.n
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UTIME
        add hl,de
        inc (iy+B_PROG)
        ld a,(iy+B_PROG)
        cp (hl)
        jr c,.n
        call bld_spawn
        jr c,.hold
        dec (iy+B_QN)
        ld hl,bq_tot
        dec (hl)
        ld (iy+B_PROG),0
        jr .n
.hold:  dec (iy+B_PROG)         ; καμία θέση: ξανά στο επόμενο καρέ
.n:     call bnext
        pop bc
        djnz .l
        ret

; Η Εποχή του Χαλκού τελείωσε (res_end): οι εικόνες της από τη δισκέτα
; (disk.asm), και η εποχή στους πίνακες και στα κτίρια (age_apply).
age_load:
        ld hl,age_req
        ld a,(hl)
        ld (hl),0
        cp 3
        ld hl,age4_name         ; Σιδήρου: μόνο οι εικόνες
        jr nz,.ld
        ld hl,hopl_name         ; Χαλκού: ο οπλίτης, στην C6 (εκεί που θα
        call disk_load          ; έρθουν οι εικόνες), και από εκεί στη
        ret c                   ; θέση 3 της C5
        ld hl,IMG0
        ld de,SPR_BASE + 3 * SPR_STRIDE
        ld bc,SPR_STRIDE
        rst 8                   ; (bcopy_src, bank7.asm)
        ld hl,age3_name
.ld:    call disk_load
        ret c
        ld hl,age_apply
        jp far7

; Μετά το age_apply: όσα κτίρια άλλαξαν εικόνα (έτοιμα, ο τύπος τους στο
; age_chg) ξαναζωγραφίζονται ένα-ένα, με το bld_redraw (μισή στήλη ανά
; καρέ) — τα άλλα όχι.
age_step:
        ld a,(age_q)
        cp 255
        ret z
        ld a,(rq_n)             ; μία επανασχεδίαση τη φορά
        inc a
        ret nz
        ld a,(age_q)
.l:     ld hl,bld_top
        cp (hl)
        jr nc,.end
        push af
        call brec_iy
        pop af
        inc a
        ld c,a
        ld a,(iy+B_TYPE)
        cp 255
        jr z,.n
        ld hl,(age_chg)         ; bit B_TYPE
        inc a
.bt:    dec a
        jr z,.bt1
        srl h
        rr l
        jr .bt
.bt1:   bit 0,l
        jr z,.n
        ld a,(iy+B_ST)
        or a
        jr z,.n
        ld a,c
        ld (age_q),a
        jp bld_redraw
.n:     ld a,c
        jr .l
.end:   ld a,255
        ld (age_q),a
        ret

; IY = κτίριο -> μια νέα μονάδα του τύπου του, σε ελεύθερη θέση του πίνακα
; (ομάδα TEAM_FREE). Carry αν δεν υπάρχει θέση ή πλακίδιο.
bld_spawn:
        xor a
.f:     ld c,a
        call idx_ix
        ld a,(ix+U_TEAM)
        inc a
        jr z,.got
        ld a,c
        inc a
        cp UNITS
        jr nz,.f
        scf
        ret
.got:   ld a,(iy+B_TYPE)
        call bt_hl
        ld c,(hl)               ; στόχος: η μπροστινή γωνία
        ld a,(iy+B_I)
        add a,c
        ld (sp_ui),a
        ld a,(iy+B_J)
        add a,c
        ld (sp_uj),a
        call bld_ring
        ret c
        call tile_xy
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld (ix+U_WY),e
        ld (ix+U_WY+1),d
        ld (ix+U_TY),e
        ld (ix+U_TY+1),d
        ld a,(iy+B_OWN)         ; της ομάδας του κτιρίου (M10)
        ld (ix+U_TEAM),a
        xor a
        call nt_put             ; στόχος (η θέση ίσως ήταν ουδέτερης)
        ld (ix+U_FL),a
        ld (ix+U_DRAWN),a
        ld (ix+U_STEP),a
        ld (ix+U_FACE),a
        ld (ix+U_JOB),a
        ld (ix+U_FIELD),a
        ld (ix+U_WF),a
        ld (ix+U_STUCK),a
        dec a
        ld (ix+U_SY),a
        ld (ix+U_TGT),a
        ld (ix+U_LOOK),a
        ld l,(ix+U_IDX)         ; χωρίς φορτίο
        ld h,J_CARRY >> 8
        ld (hl),0
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UNIT
        add hl,de
        ld a,(hl)
        call set_look
        ld hl,hp_set            ; η υγεία της (bank7.asm)
        call far7
        call unit_pxy
        call unit_tile
        call bucket_update
        ld a,(iy+B_OWN)
        or a
        jr nz,.vis
        ld hl,(hud_val + 8)     ; ο πληθυσμός (του παίκτη)
        inc hl
        ld (hud_val + 8),hl
        ld hl,hud_dirty
        set 4,(hl)
.vis:   call unit_activity      ; φαίνεται ήδη;
        call vis_test
        call z,unit_update
        or a
        ret

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

; IX = η γωνία του κουτιού: όταν δεν σέρνεται κουτί, το σημάδι του
; επιλεγμένου κτιρίου (οι αγκύλες), στη μπροστινή γωνία του. -> NZ αν
; φαίνεται.
bld_mark:
        ld a,(sel_bld)
        cp 255
        ret z
        call brec_iy
        ld a,(iy+B_TYPE)
        call bt_hl
        ld a,(hl)
        dec a
        ld c,a
        ld a,(iy+B_I)
        add a,c
        ld d,a
        ld a,(iy+B_J)
        add a,c
        ld e,a
        call tile_xy
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld (ix+U_WY),e
        ld (ix+U_WY+1),d
        ld hl,SPR_MARK
        or 1
        ret

; ------------------------------------------------------------ επιλογή

; Κλικ που δεν βρήκε μονάδα: κτίριο κάτω από τον κέρσορα (πλακίδιο
; κτιρίου) -> sel_bld.
bld_pick:
        ld a,255
        ld (sel_bld),a
        ld hl,(cw_x)
        ld de,(cw_y)
        call feet_tile
        ld a,h
        or d
        ret nz
        ld a,l
        cp MAPW
        ret nc
        ld a,e
        cp MAPW
        ret nc
        ld d,l
        push de
        call map_ptr
        ld a,(hl)
        pop de
        and 15
        cp BLD_RES
        ret nz
        ld iy,BLD_TAB           ; ποιο: d - i0 στο 0..n-1, e - j0 επίσης
        ld b,0
.l:     ld a,(iy+B_TYPE)
        cp 255
        jr z,.n
        call bt_hl
        ld c,(hl)
        ld a,d
        sub (iy+B_I)
        cp c
        jr nc,.n
        ld a,e
        sub (iy+B_J)
        cp c
        jr nc,.n
        ld a,b
        ld (sel_bld),a
        ret
.n:     call bnext
        inc b
        ld a,b
        cp BLD_MAX
        jr nz,.l
        ret

        assert (BLD_TAB2 & 255) + (BLD_MAX - BLD_N1) * B_SIZE <= 256, 'BLD_TAB2 crosses a page'
        assert BLD_TAB2 >= UNIT_TAB + (UNITS + 2) * U_SIZE, 'BLD_TAB2 over UNIT_TAB'
        assert BLD_TAB == SWAP_TAB, 'BLD_TAB is the init-only SWAP_TAB'
