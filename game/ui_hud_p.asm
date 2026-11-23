; ui_hud_p.asm — (M22) τα κουμπιά του HUD: στο UI_P = start (#0040), μετά
; τα εικονίδια του SPLIT SQUAD και του PAUSE (data/ui_p.asm). Ο κώδικας
; του start ως το start_dead έχει ήδη τρέξει όταν το ui_load γράφει εδώ, και
; δεν ξανατρέχει (η εκστρατεία ξαναφορτώνει όλο το POLIS.BIN)· δεν σώζεται
; με την παρτίδα. Μόνο με την C0.

; -> A = το κουμπί κάτω από τον κέρσορα (hb_i: θέση) — το PAUSE ως 9 (η
; ετικέτα CONTINUE) όσο το παιχνίδι είναι σταματημένο.
hb_btn: ld a,(hb_i)
        call hb_vb
        cp 8
        ret nz
        ld a,(paused)
        add a,8
        ret

; PAUSE / CONTINUE (hb_do: 8, 9): το παιχνίδι σταματά ή συνεχίζει — όχι
; μετά το τέλος της παρτίδας.
hb_pause:
        ld a,(game_end)
        or a
        ret nz
        ld hl,paused
        ld a,(hl)
        xor 1
        ld (hl),a
        ret

; (M22) Τα καρέ χωρίς έλεγχο των φανερών: οι μονές θέσεις, και μετά το
; hb_lab (UI_I).
hb_odd: ld hl,hb_lab
        push hl
        jp hb_od2

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
