; ui_hud_j.asm — (M22) τα κουμπιά του HUD: μετά το εικονίδιο του BUILD, στο
; UI_J. Μόνο με την C0.

; A = κουμπί -> carry αν φαίνεται (hb_vis). Κρατάει A, BC, DE, HL.
hb_vk:  push bc
        ld c,a
        ld b,a
        inc b
        ld a,(hb_vis)
.r:     rrca
        djnz .r
        ld a,c
        pop bc
        ret
