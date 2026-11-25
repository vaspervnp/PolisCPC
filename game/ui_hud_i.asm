; ui_hud_i.asm — (M22) τα κουμπιά του HUD: τα φανερά από το hb_tick
; (hudvis.asm) με το SPLIT SQUAD, το ξαναζωγράφισμα όσων άλλαξαν, ο
; αδρανής χωρικός, η επόμενη γραμμή. Στο UI_I, μόνο με την C0.

; C = τα φανερά ως εδώ.
hb_upd: ld a,(sel_n)            ; SPLIT SQUAD (όπως το sq_split)
        dec a
        jr nz,.d
        ld ix,(SELLIST)
        ld a,(ix+U_TEAM)
        or a
        jr nz,.d
        ld a,(ix+U_SET)
        or a
        jr z,.d
        cp 3
        jr z,.d
        call sq_cnt
        cp 2
        jr c,.d
        set 3,c
.d:     ld hl,hb_vis            ; (M22) τα φανερά σε σειρά, από τη θέση 0:
        ld b,0                  ; ξαναζωγραφίζονται οι θέσεις που άλλαξε το
        call hb_sync            ; κουμπί τους — εδώ οι ζυγές, οι μονές στο
;                                 επόμενο καρέ (hb_odd): ως 4 σε ένα καρέ
;                                 ξεπερνούσαν τα 40 ms

; Από το hb_tick (main.asm) στα άλλα καρέ: στο 2ο των 4 ο αδρανής
; χωρικός· σε όλα η ετικέτα.
hb_lab: call hb_hot             ; (2026-11-25) τα γράμματα των κουμπιών
        ld a,(hb_ph)
        and 3
        cp 2
        call z,hb_scan
.l:     ld a,(hb_on)            ; ο κέρσορας στα κουμπιά: η ετικέτα — και αν
        or a                    ; η θέση του άδειασε, μία πίσω σε κάθε καρέ
        ret z                   ; (το SAVE GAME φαίνεται πάντα)
        ld a,(hb_i)
        call hb_vk
        jp c,hb_label
        dec a
        ld c,a
        call hb_move
        jp hb_label

; IDLE VILLAGER: 8 μονάδες ανά καρέ· στο τέλος του γύρου (128) το hb_idf.
hb_scan:
        ld a,(hb_ik)
        ld b,8
.l:     push bc
        push af
        call idx_ix
        push ix
        pop iy
        call is_villager
        jr nz,.n
        ld a,(ix+U_JOB)
        or a
        jr nz,.n
        bit F_MOVE,(ix+U_FL)
        jr nz,.n
        ld a,1 << 5
        ld (hb_if),a
.n:     pop af
        inc a
        and UNITS - 1
        pop bc
        jr z,.e
        djnz .l
        ld (hb_ik),a
        ret
.e:     ld (hb_ik),a
        ld hl,hb_if
        ld a,(hl)
        ld (hl),0
        ld (hb_idf),a
        ret

; HL = τα φανερά όπως είναι ζωγραφισμένα (hb_vis οι ζυγές, hb_old οι μονές),
; C = τα νέα, B = η πρώτη θέση: ξαναζωγραφίζονται B, B + 2, ... (E = παλιά).
hb_sync:
        ld a,(hl)
        cp c
        ret z
        ld e,a
        ld (hl),c
.k:     ld a,b
        call hb_nthe
        ld d,a
        ld a,b
        call hb_vb
        cp d
        jr z,.n
        push bc
        push de
        ld a,b
        call hb_draw
        pop de
        pop bc
.n:     inc b
        inc b
        bit 3,b
        jr z,.k
        ret
