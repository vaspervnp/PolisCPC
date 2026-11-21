; player.asm — ο player της μουσικής (M21), ΧΩΡΙΣ δικές του καθολικές
; ετικέτες: μπαίνει δύο φορές, μετά από μια ετικέτα που του δίνει όνομα —
; mn_mus (menu.asm, στο MENU_AT) και hud_mus (sound_fx.asm, στη σελίδα του
; HUD). Τον καλεί η διακοπή (sound.asm, snd_isr: mus_vec = X.tick), με τα
; AF, BC, DE, HL, IX ελεύθερα. Τα δεδομένα του (mus_ch, ...) στον κύριο
; κώδικα.
;
; Η ΜΟΡΦΗ (src/make_music.py). Κεφαλίδα: καρέ ανά βήμα (ένα όγδοο), dw η
; αρχή του A, dw η αρχή του B. Κάθε νότα ένα byte: διάρκεια (bits 7-5: 1 2
; 3 4 6 8 12 16 βήματα) και τόνος (bits 4-0: 0 = παύση, 1-30 = ημιτόνια
; από το E2, 31 = πάλι από την αρχή του καναλιού). Το A παίζει μία οκτάβα
; ψηλότερα. Η ένταση κάθε νότας αρχίζει από το V0 του καναλιού και πέφτει
; ένα κάθε 4 καρέ ως το 3: απαλά.
;
; Το M ανοίγει / κλείνει τη μουσική (mus_mask): το τραγούδι προχωράει, μόνο
; οι εντάσεις των A, B μένουν 0. Τα εφέ ακούγονται πάντα.

.tick:  ld a,(keyrows + 4)      ; M (γραμμή 4, bit 6): η μουσική ναι / όχι
        and #40                 ; (το keyrows το γράφει ο κύριος κώδικας:
        ld hl,mus_km            ; read_matrix)
        ld c,(hl)
        ld (hl),a
        jr z,.k
        cp c
        jr z,.k
        ld a,(mus_mask)         ; (κοινό στο μενού και στο παιχνίδι)
        xor 15
        ld (mus_mask),a
.k:     ld hl,mus_clk
        dec (hl)
        jr nz,.env
        ld a,(mus_step)
        ld (hl),a
        ld ix,mus_ch
        ld e,0
        call .note
        ld ix,mus_ch + 8
        ld e,1
        call .note
.env:   ld ix,mus_ch            ; το σβήσιμο, και οι εντάσεις
        ld e,8
        call .vol
        ld ix,mus_ch + 8
        ld e,9
.vol:   ld a,(ix+3)
        cp 3 * 4 + 1
        jr c,.w
        dec a
        ld (ix+3),a
.w:     rrca
        rrca
        ld hl,mus_mask          ; 15, ή 0 με τη μουσική κλειστή (M)
        and (hl)
        ld c,a
        ld a,e
        jp psg_w

; IX = κανάλι (ptr, cnt, ένταση, -, αρχή, V0, οκτάβα), E = 0 (A) / 1 (B).
.note:  dec (ix+2)
        ret nz
        ld l,(ix+0)
        ld h,(ix+1)
.rd:    ld a,(hl)
        inc hl
        ld d,a
        and 31
        cp 31
        jr nz,.n
        ld l,(ix+4)             ; πάλι από την αρχή
        ld h,(ix+5)
        jr .rd
.n:     ld (ix+0),l
        ld (ix+1),h
        ld b,a                  ; B = τόνος
        ld a,d                  ; η διάρκεια
        rlca
        rlca
        rlca
        and 7
        ld hl,.dur
        call .ix
        ld (ix+2),a
        ld a,b
        or a
        jr nz,.t
        ld (ix+3),a             ; παύση: ένταση 0
        ret
.t:     dec a                   ; ημιτόνιο -> οκτάβα (C), νότα (A)
        ld c,(ix+7)
.o:     cp 12
        jr c,.p
        sub 12
        inc c
        jr .o
.p:     add a,a
        ld hl,.per
        call .ix
        inc hl
        ld h,(hl)
        ld l,a
        inc c
.s:     dec c
        jr z,.u
        srl h
        rr l
        jr .s
.u:     ld a,(ix+6)             ; η αρχή της νότας
        ld (ix+3),a
        ld a,e                  ; R0 / R2 = l, R1 / R3 = h
        add a,a
        ld c,l
        push af
        call psg_w
        pop af
        inc a
        ld c,h
        jp psg_w

; HL + A -> HL, A = (HL).
.ix:    add a,l
        ld l,a
        jr nc,.ix1
        inc h
.ix1:   ld a,(hl)
        ret

.dur:   db 1, 2, 3, 4, 6, 8, 12, 16
; Οι περίοδοι του AY (1 MHz / 16 / f) για E2 ... D#3.
.per:   dw 758, 716, 676, 638, 602, 568, 536, 506, 478, 451, 426, 402
