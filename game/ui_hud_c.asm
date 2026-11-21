; ui_hud_c.asm — (M20) τα κουμπιά του HUD: ο αδρανής χωρικός (μετά τα
; κείμενα, στο UI_S).

hb_idle:
        ld a,(hb_iv)            ; IDLE VILLAGER: ο επόμενος χωρικός σου χωρίς
        ld c,a                  ; δουλειά και χωρίς βήμα — επιλεγμένος, και
        ld b,UNITS              ; η κάμερα πάνω του
.il:    inc c
        ld a,c
        cp UNITS
        jr c,.i1
        ld c,0
.i1:    ld a,c
        call idx_ix
        push ix
        pop iy
        call is_villager
        jr nz,.in
        ld a,(ix+U_JOB)
        or a
        jr nz,.in
        bit F_MOVE,(ix+U_FL)
        jp z,hb_got
.in:    djnz .il
        ret
