; occlude.asm — μονάδα πίσω από κτίριο: μόνο το περίγραμμά της (M7).
;
; Τα κτίρια είναι φόντο (και στον καθρέφτη) και οι μονάδες ζωγραφίζονται
; πάντα από πάνω. Όταν όμως μια μονάδα στέκεται ΠΙΣΩ από ένα κτίριο (το
; πλακίδιο των ποδιών της δεν είναι μπροστά από την κάτοψη ούτε στο i ούτε
; στο j) και η εικόνα του καλύπτει τα πόδια της (το byte 2 της γραμμής 14
; του sprite), ζωγραφίζεται ΜΟΝΟ το περίγραμμά της: τα pixels της
; σιλουέτας με διάφανο γείτονα (πάνω, κάτω, αριστερά, δεξιά), στο pen της
; ομάδας (OUTLINE, src/make_map.py). Όλη — και ό,τι λίγο εξέχει από το κτίριο.
;
; (Το ακριβές, ανά pixel με τη μάσκα του κτιρίου, δοκιμάστηκε: ~4-5 ms ανά
; κρυμμένη μονάδα, και με 2-3 ανά καρέ γύρω από το Κέντρο Πόλης τα καρέ
; έφταναν 45-60 ms. Αποφασίστηκε 2026-11-12: όλη περίγραμμα, ~1 ms.)
;
; Πώς: στην αρχή του units_draw, τα έτοιμα κτίρια του παραθύρου γίνονται μια
; λίστα με ορθογώνια σε συντεταγμένες οθόνης (occ_list) — για όσες μονάδες
; ζωγραφίζονται, ο έλεγχος είναι 4 συγκρίσεις ανά κτίριο. Για την κάλυψη,
; ΕΝΑ byte μάσκας από την εικόνα (C6). Το περίγραμμα κάθε καρέ είναι έτοιμο
; στην C5 (OCC_E, src/make_edges.py)· ζωγραφίζεται πάνω σε ό,τι υπάρχει: ο
; χώρος της μονάδας έχει ήδη σβηστεί από τον καθρέφτη (ή έχει ήδη το ίδιο).

OCC_L       equ #A590           ; OCC_MAX x (x0, x1, y0, y1, ki, kj, εγγραφή):
OCC_MAX     equ 8               ; το ορθογώνιο οθόνης για το (SX, SY) της
                                ; μονάδας, και τα όρια του «πίσω» (occ_bld)
SPR_ARROW   equ SPR_CURSOR + 3 * 128 ; στην C5: ένα βέλος (αχρησιμοποίητο, M8)
OCC_E       equ SPR_CURSOR + 4 * 128 ; στην C5: 16 bytes ανά καρέ (make_edges.py)
OCC_OM      equ OCC_E + #700    ; στην C5: η μάσκα (και +256 το pen) ανά byte·
                                ; +512 ξανά, με το pen της ομάδας 1
TR1         equ OCC_OM + #400   ; στην C5: byte -> byte, τα pens της ομάδας 1
C5_TAIL     equ 4 * 128 + #700 + 5 * 256 ; ό,τι πάει στην C5 από το SPR_CURSOR

        assert OCC_L + OCC_MAX * 10 <= ACT_TAB, 'OCC_L'
        assert SPR_STRIDE == 25 * 128, 'OCC_E: 25 frames per set'
        assert 4 * 25 * 16 <= #700 && (OCC_OM & 255) == 0, 'OCC_OM'
        assert SPR_CURSOR + C5_TAIL <= #8000, 'C5_TAIL'

; (Το occ_list, που φτιάχνει το OCC_L, ζει στην C7: game/bank7.asm.)

; IX = μονάδα που ζωγραφίζεται (U_OADDR έτοιμο), με την C5 μέσα. Αν κάποιο
; κτίριο την κρύβει: τη ζωγραφίζει (μόνο το περίγραμμα) και NZ· αλλιώς Z.
; Κρατάει IX, και την C5 μέσα.
occ_draw:
        ld a,(occ_c)
        or a
        ret z
        ld b,a
        xor a                   ; τα πόδια της (occ_uv): όταν χρειαστούν
        ld (occ_uvd),a
        ld hl,OCC_L
.l:     ld a,(ix+U_SX)
        cp (hl)
        jr c,.n0
        inc hl
        cp (hl)
        jr nc,.n1
        inc hl
        ld a,(ix+U_SY)
        cp (hl)
        jr c,.n2
        inc hl
        cp (hl)
        jr nc,.n3
        inc hl
        push hl
        push bc
        call occ_bld
        pop bc
        pop hl
        jr nz,occ_make
        jr .n4
.n0:    inc hl
.n1:    inc hl
.n2:    inc hl
.n3:    inc hl
.n4:    ld de,6
        add hl,de
        djnz .l
        xor a
        ret

; Ένα byte της γραμμής: τα 2 bits του (το ζευγάρι m του C) -> οθόνη = (οθόνη
; AND μάσκα) OR pen, από τις σελίδες OCC_OM (H). Κανένα: τίποτα.
        macro OBYTE m
        ld a,c
        and {m}
        jr z,$ + 9               ; (τα 7 bytes που ακολουθούν)
        ld l,a
        ld a,(de)
        and (hl)
        inc h
        or (hl)
        dec h
        ld (de),a
        mend

; IX, με την C5 μέσα: μόνο το περίγραμμα, κατευθείαν στην οθόνη. -> NZ.
occ_make:
        push ix
        call unit_frame         ; HL = το καρέ της, στοιχισμένο
        ld a,h                  ; IY = το περίγραμμά του: OCC_E + (HL - #4000) / 8
        sub #40
        ld d,a
        ld e,l
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        ld iy,OCC_E
        add iy,de
        ld e,(ix+U_OADDR)
        ld d,(ix+U_OADDR+1)
        ld a,(ix+U_TEAM)        ; το pen της ομάδας: H = OCC_OM, ή + 2
        and 1                   ; σελίδες για την ομάδα 1
        add a,a
        add a,OCC_OM >> 8
        ld h,a
        ld b,16
.row:   ld a,(iy+0)             ; C: τα bits της γραμμής, 2 ανά byte
        inc iy
        or a
        jr z,.next
        ld c,a
        push de
        OBYTE #C0
        inc e
        call z,de_carry
        OBYTE #30
        inc e
        call z,de_carry
        OBYTE #0C
        inc e
        call z,de_carry
        OBYTE #03
        pop de
.next:  ld a,d                  ; η επόμενη γραμμή: D + 8, ή η επόμενη σειρά
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        djnz .row
        pop ix
        or 1
        ret

; HL = τα ki, kj και η εγγραφή ενός κτιρίου του OCC_L, που η μονάδα IX
; ακουμπάει. -> NZ αν είναι πίσω του και η εικόνα του καλύπτει τα πόδια
; της (byte WX + 2, γραμμή WY + 14).
occ_bld:
        ld a,(occ_uvd)
        or a
        call z,occ_uv
        ld e,(hl)               ; 2 fx + fy < ki
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(occ_u)
        or a
        sbc hl,de
        pop hl
        jr nc,.no
        ld e,(hl)               ; fy - 2 fx + 1024 < kj
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld hl,(occ_v)
        or a
        sbc hl,de
        pop hl
        jr nc,.no
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        push hl
        pop iy
        ld a,(iy+B_WYB)         ; η γραμμή της εικόνας: WY + 14 - (κάτω - h)
        sub (iy+B_H)
        ld c,a
        ld a,(ix+U_WY)
        add a,14
        sub c
        cp (iy+B_H)
        jr nc,.no
        ld e,a
        ld a,(ix+U_WX)          ; το byte: WX + 2 - x
        add a,2
        sub (iy+B_WX)
        cp (iy+B_W)
        jr nc,.no
        add a,a                 ; εικόνα + γραμμή x 2w + 2 byte
        ld c,a
        ld b,0
        ld l,(iy+B_IMG)
        ld h,(iy+B_IMG+1)
        add hl,bc
        push hl
        ld a,(iy+B_W)
        ld h,e                  ; HL = γραμμή x 2w
        ld l,0
        ld d,l
        add a,a
        ld e,a
        ld b,8
.m:     add hl,hl
        jr nc,.m0
        add hl,de
.m0:    djnz .m
        pop de
        add hl,de
        ld a,RAM_RES
        call setram
        ld c,(hl)               ; η μάσκα: #FF = διάφανο
        ld a,RAM_SPR
        call setram
        ld a,c
        inc a
        ret                     ; NZ: καλύπτεται
.no:    xor a
        ret

; IX -> occ_u = 2 fx + fy, occ_v = fy - 2 fx + 1024 (τα πόδια: WX + 2, WY + 14).
; Κρατάει HL.
occ_uv: push hl
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        inc hl
        inc hl
        add hl,hl
        ex de,hl
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld bc,14
        add hl,bc
        push hl
        add hl,de
        ld (occ_u),hl
        pop hl
        ld bc,1024
        add hl,bc
        or a
        sbc hl,de
        ld (occ_v),hl
        ld a,1
        ld (occ_uvd),a
        pop hl
        ret

