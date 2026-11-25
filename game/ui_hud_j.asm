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

; (2026-11-25, ζήτημα του χρήστη: «εκτός από το τι είναι να φαίνεται και με
; ποιο κουμπί ενεργοποιείται».) Κάθε κουμπί του HUD και με το γράμμα του
; (hk_tab, ui_hud_l.asm), από όπου κι αν είναι ο κέρσορας — μόνο όταν το
; κουμπί φαίνεται (hb_vis· το PAUSE πάντα), μία φορά ανά πάτημα (hk_prev).
; Από το hb_lab (ui_hud_i.asm), σε κάθε καρέ μονάδων: όχι με μενού ανοιχτό
; (main.asm: το um_go πριν από το units_tick). Στη σελίδα του HUD, με την C0.
hb_hot:
        ld hl,hk_tab
        ld bc,9 * 256           ; B = 9 κουμπιά, C = το κουμπί
.l:     ld a,(hl)
        inc hl
        call read_row
        and (hl)
        inc hl
        jr nz,.k
        inc c
        djnz .l
        ld (hk_prev),a          ; (A = 0) κανένα
        ret
.k:     ld hl,hk_prev
        ld a,(hl)
        ld (hl),1
        or a
        ret nz                  ; κρατιέται από πριν
        ld a,c
        cp 8
        jp z,hb_do              ; PAUSE / CONTINUE: πάντα
        ld b,a
        inc b
        ld a,(hb_vis)
.s:     rrca
        djnz .s
        ret nc                  ; δεν φαίνεται: τίποτα
        ld a,c
        jp hb_do
