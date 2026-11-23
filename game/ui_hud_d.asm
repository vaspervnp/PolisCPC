; ui_hud_d.asm — (M20) τα κουμπιά του HUD: η ετικέτα (μετά τις τεχνολογίες,
; στο UI_C).

; Από τον κύριο βρόχο, μετά το καρέ μονάδων, όσο hb_on: η ετικέτα του
; κουμπιού στις 8 πρώτες γραμμές του χάρτη (κάθε φορά: οι μονάδες από κάτω
; ίσως ζωγραφίστηκαν από πάνω της).
hb_label:
        call hb_btn             ; όλη η λωρίδα σβήνει μόνο με νέο κουμπί ή
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
.t:     call hb_btn             ; (M22: το κουμπί της θέσης)
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


; (M22) Από το sn_try (jobs.asm), αντί για το job_src: D = si, E = sj (η
; παλιά πηγή, το κέντρο του παραθύρου της αναζήτησης), και το κέντρο της
; απόστασης (sn_cj, sn_ci): η παλιά πηγή — για χωρικό του αντιπάλου το
; σπίτι του (sn_home, sn_ct2): από τις πηγές κοντά στην παλιά διαλέγει την
; πιο κοντινή στο Κέντρο του, και φεύγει μακριά μόνο όταν κοντά δεν έχει.
sn_ctr: call job_src
        ld (sn_cj),de
        ld a,(ix+U_TEAM)
        or a
        ret z
        jp sn_ct2
sn_cj:  db 0
sn_ci:  db 0
