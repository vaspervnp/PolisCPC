; ui_hud_j.asm — (M22) τα κουμπιά του HUD: μετά το εικονίδιο του BUILD, στο
; UI_J. Μόνο με την C0.

; A = θέση -> A = το κουμπί της: το A-οστό φανερό του hb_vis (255: άδεια).
hb_vb:  push de
        ld d,a
        ld a,(hb_vis)
        ld e,a
        ld a,d
        call hb_nthe
        pop de
        ret

; A = θέση -> carry αν έχει κουμπί. Κρατάει A, BC, DE, HL.
hb_vk:  push bc
        ld c,a
        call hb_vb
        cp 255
        ld a,c
        pop bc
        ret

