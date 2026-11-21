; ui_hud_d.asm — (M20) τα κουμπιά του HUD: η ετικέτα (μετά τις τεχνολογίες,
; στο UI_C).

; Από τον κύριο βρόχο, μετά το καρέ μονάδων, όσο hb_on: η ετικέτα του
; κουμπιού στις 8 πρώτες γραμμές του χάρτη (κάθε φορά: οι μονάδες από κάτω
; ίσως ζωγραφίστηκαν από πάνω της).
hb_label:
        ld a,(hb_i)             ; όλη η λωρίδα σβήνει μόνο με νέο κουμπί ή
        ld hl,hb_lw             ; με το μπάσιμο (hb_on = 1)· αλλιώς μόνο τα
        cp (hl)                 ; γράμματα ξανά, πάνω στον εαυτό τους (αλλιώς
        ld (hl),a               ; η ακτίνα ίσως πετύχει τη λωρίδα σβησμένη:
        jr nz,.f                ; τρεμόπαιγμα). Και όταν η οθόνη κύλησε από
        ld a,(v_shx)            ; κάτω της (το καρέ μονάδων: v_shx, v_shy) ή
        ld hl,v_shy             ; ξαναζωγραφίστηκε (main.asm: hb_on = 1).
        or (hl)
        jr nz,.f
        ld a,(hb_on)
        dec a
        jr nz,.t
.f:     ld a,2
        ld (hb_on),a
        ld bc,0
        ld de,80 * 256 + 8
        ld a,UI_BG
        call ui_fill
.t:     ld a,(hb_i)
        ld hl,ui_blbl
        call um_ptrn
        ld a,(hl)               ; στη μέση: (80 - 3 n) / 2
        inc hl
        ld b,a
        add a,a
        add a,b
        neg
        add a,80
        srl a
        ld c,a
.g:     push bc
        ld a,(hl)
        inc hl
        push hl
        ld b,0
        ld ix,pn_title
        call ui_glyph
        pop hl
        pop bc
        inc c
        inc c
        inc c
        djnz .g
        ret
hb_lw:  db 0

