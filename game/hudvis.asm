; hudvis.asm — (M22, 2026-11-22) τα κουμπιά του HUD φαίνονται μόνο όταν
; έχουν νόημα. Κάθε καρέ (από τον κύριο βρόχο, με την C0) το hb_tick
; υπολογίζει ποια (bit k = κουμπί k, mockup.BUTTONS):
;
;   0 BUILD         χωρικοί επιλεγμένοι
;   1 TRAIN         ένα έτοιμο κτίριό σου που βγάζει μονάδα
;   2 RESEARCH      ένα έτοιμο κτίριό σου με έρευνες (UB_RES, make_ui.py)
;   3 SPLIT SQUAD   μία δική σου ομάδα στρατιωτών, 2 ή περισσότεροι
;   4 NEXT AGE      ως την Εποχή του Σιδήρου
;   5 IDLE VILLAGER υπάρχει αδρανής χωρικός (hb_scan: 8 μονάδες ανά καρέ)
;   6 SAVE GAME     πάντα
;   7 CANCEL        όσο τοποθετείται κτίριο
;
; και ξαναζωγραφίζει όσα άλλαξαν (hb_draw): κρυμμένο = το φόντο του HUD,
; φανερό = το πλαίσιο και το εικονίδιο (από τα UI_H, UI_I, UI_J: μόνο οι
; γραμμές με σχέδιο). Ο κέρσορας των κουμπιών περνάει μόνο από φανερά
; (ui_hud.asm, hb_step).

        include "../data/ui_vis.asm"

hb_tick:
        ld hl,hb_ph             ; (M22) ένα καρέ στα 4 τα φανερά, σε άλλο
        inc (hl)                ; ο αδρανής χωρικός (hb_lab), σε κάθε καρέ η
        ld a,(hl)               ; ετικέτα: όχι πάνω από ~0,5 ms σε κανένα
        and 3
        jp nz,hb_lab
        ld c,1 << 6             ; SAVE GAME
        ld a,(bmode)            ; CANCEL
        inc a
        jr z,.c
        set 7,c
.c:     ld a,(hud_val + 10)     ; NEXT AGE
        cp 4
        jr nc,.a
        set 4,c
.a:     ld a,(hb_idf)           ; IDLE VILLAGER (1 << 5 ή 0)
        or c
        ld c,a
        push bc
        call sel_villager       ; BUILD
        pop bc
        jr nc,.b
        set 0,c
.b:     ld a,(sel_bld)          ; TRAIN, RESEARCH
        cp 255
        jr z,.q
        push bc
        call brec_iy
        pop bc
        ld a,(iy+B_OWN)
        or a
        jr nz,.q
        ld a,(iy+B_ST)
        or a
        jr z,.q
        ld a,(iy+B_TYPE)
        push bc
        ld b,a
        inc b
        ld hl,UB_RES            ; RESEARCH: το bit του τύπου
.rs:    srl h
        rr l
        djnz .rs
        pop bc
        jr nc,.t
        set 2,c
.t:     ld a,(iy+B_TYPE)        ; TRAIN: αν βγάζει μονάδα
        call bt_hl
        ld de,BT_UNIT
        add hl,de
        ld a,(hl)
        inc a
        jr z,.q
        set 1,c
.q:     jp hb_upd               ; SPLIT SQUAD, και όσα άλλαξαν (ui_hud_i.asm)

; (οι μεταβλητές hb_vis, hb_ik, hb_if, hb_idf: main.asm, μετά το zeros — όχι
; εδώ, πριν από το align 16)
