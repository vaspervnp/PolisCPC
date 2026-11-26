; ui_hud_d.asm — (M20) τα κουμπιά του HUD: η ετικέτα (μετά τις τεχνολογίες,
; στο UI_C).

; Από τον κύριο βρόχο, μετά το καρέ μονάδων, όσο hb_on: η ετικέτα του
; κουμπιού στις 8 πρώτες γραμμές του χάρτη (κάθε φορά: οι μονάδες από κάτω
; ίσως ζωγραφίστηκαν από πάνω της).
hb_label:
        call hb_btn             ; όλη η λωρίδα σβήνει μόνο με νέο κουμπί ή
        ld de,hb_on             ; με το μπάσιμο (hb_on = 1)· αλλιώς μόνο τα
        ld hl,ui_blbl           ; γράμματα ξανά, πάνω στον εαυτό τους (αλλιώς
                                ; η ακτίνα ίσως πετύχει τη λωρίδα σβησμένη:
                                ; τρεμόπαιγμα). Και όταν η οθόνη κύλησε από
                                ; κάτω της (το καρέ μονάδων: v_shx, v_shy) ή
                                ; ξαναζωγραφίστηκε (main.asm: hb_on = 1).
; (2026-11-26: και η δουλειά του χωρικού, jobmsg.asm) A = ποια (hb_lw: τα
; κουμπιά 0-9, οι δουλειές #10 + k), HL = ο πίνακας των κειμένων (A AND 15),
; DE = η κατάσταση (1: σβήσιμο, και μετά 2).
hb_lblgo: push hl
        ld hl,hb_lw
        cp (hl)
        ld (hl),a
        jr nz,.f
        ld a,(v_shx)
        ld hl,v_shy
        or (hl)
        jr nz,.f
        ld a,(de)
        dec a
        jr nz,.t
.f:     ld a,2
        ld (de),a
        ld bc,0
        ld de,80 * 256 + 8
        ld a,UI_BG
        call ui_fill
.t:     pop hl
        ld a,(hb_lw)
        and 15
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
; (2026-11-26) B = πόσα, C = το byte, HL = τα γράμματα (το jm_tick: ένα ανά
; καρέ) -> HL, C μετά από αυτά.
hb_lblg:
        push bc
        ld a,(hl)
        inc hl
        push hl
        ld b,0
        ld ix,pn_title
        add a,a                 ; (2026-11-25) το γράμμα του πλήκτρου (bit 7,
        jr nc,.n                ; make_ui.py): με το χρώμα του κειμένου
        ld ixl,pn_text & 255
.n:     rrca
        call ui_glyph
        pop hl
        pop bc
        inc c
        inc c
        inc c
        djnz hb_lblg
        ret
        assert pn_title >> 8 == pn_text >> 8, 'pn_text: ld ixl'

; (το sn_ctr στο UI_P: ui_hud_p.asm, 2026-11-25)
