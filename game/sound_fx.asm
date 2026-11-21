; sound_fx.asm — ο ήχος του παιχνιδιού στη σελίδα του HUD (M21): τα εφέ
; (fx_tick, fx_tab). Τρία κομμάτια του UI.BIN (main.asm): ο player
; (hud_mus) μετά το SVM_STORE ως το BKT0, αυτό εδώ μετά το SRC_TAB, και η
; μουσική του παιχνιδιού μετά το BOOT. Μόνο από τη διακοπή (snd_isr), με
; την C0 στο #4000.


; Το καρέ των εφέ: ένα καινούριο αν ζητήθηκε δυνατότερο από ό,τι
; ακούγεται (snd_pv, snd_pf: sound.asm), και το σβήσιμο του τρέχοντος.
; Κάθε εφέ (fx_tab): περίοδος (R4, R5), θόρυβος (R6), R7, πόσο γρήγορα
; σβήνει (τέταρτα έντασης ανά καρέ).
fx_tick:
        ld hl,snd_pv
        ld a,(hl)
        or a
        jr z,.run
        ld (hl),0
        ld b,a                  ; B = η νέα ένταση
        ld a,(fx_v4)
        rrca
        rrca
        and 15
        cp b
        jr nc,.run              ; ακούγεται κάτι δυνατότερο
        ld a,b
        add a,a
        add a,a
        ld (fx_v4),a
        ld a,(snd_pf)           ; 5 x
        ld l,a
        add a,a
        add a,a
        add a,l
        ld hl,fx_tab
        add a,l
        ld l,a
        jr nc,.h
        inc h
.h:     ld a,4                  ; R4, R5, R6
.r:     ld c,(hl)
        inc hl
        push af
        call psg_w
        pop af
        inc a
        cp 7
        jr nz,.r
        ld a,(hl)               ; το R7 το γράφει η διακοπή
        inc hl
        ld (fx_r7),a
        ld a,(hl)
        ld (fx_dec),a
.run:   ld a,(fx_v4)
        or a
        ret z
        ld hl,fx_dec
        sub (hl)
        jr nc,.v
        xor a
.v:     ld (fx_v4),a
        rrca
        rrca
        and 15
        ld c,a
        ld a,10
        jp psg_w

;           R4   R5  R6  R7   σβήσιμο
fx_tab: db #28, 0,  0,  #38, 6         ; κλικ
        db 0,   0,  10, #1C, 6         ; χτύπημα: θόρυβος
        db 0,   0,  24, #1C, 4         ; κτίριο: βαθύς θόρυβος
        db #40, 0,  0,  #38, 5         ; βέλος: ψηλός, σύντομος
        db #F0, 0,  0,  #38, 1         ; κτίριο έτοιμο: χαμηλός, μακρύς
        db #B4, 0,  0,  #38, 2         ; νέα μονάδα

fx_v4:      db 0                ; η ένταση του C, σε τέταρτα
fx_dec:     db 0
