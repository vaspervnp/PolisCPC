; sound.asm — ο ήχος: η μουσική και τα εφέ (M12· από το M21 στη διακοπή).
; Στον κύριο κώδικα: τον καλούν η διακοπή (snd_isr), η C7 (hit, ζημιά
; κτιρίου, βέλη, proj_on), η σελίδα του HUD και το μενού.
;
; ΜΟΝΟ Η ΔΙΑΚΟΠΗ ΓΡΑΦΕΙ ΣΤΟ AY (στο VSYNC, 50 Hz). Το πληκτρολόγιο
; (read_matrix) περνάει κι αυτό από τις θύρες του AY: το διαβάζει με di.
; Το mus_play / mus_stop (που μπορεί να τρέξουν με τις διακοπές κλειστές,
; στο start) γράφουν με psg_lock = 1: η διακοπή χάνει εκείνο το καρέ.
;
; ΚΑΝΑΛΙΑ. A: η μελωδία· B: το μπάσο (game/player.asm)· C: τα εφέ
; (sound_fx.asm, fx_tick), με τόνο ή θόρυβο. Το R7 (fx_r7) γράφεται σε κάθε
; καρέ: A και B τόνος, τα bits του C από το εφέ, τα 6-7 πάντα 0 (η θύρα A
; του AY είναι είσοδος: το πληκτρολόγιο).
;
; Ο PLAYER ΕΙΝΑΙ ΔΥΟ ΦΟΡΕΣ (player.asm): στο μενού (mn_mus, με τη μουσική
; του, στο MENU_AT) και στη σελίδα του HUD (hud_mus, με τη μουσική του
; παιχνιδιού και τα εφέ, sound_fx.asm). Ο κύριος κώδικας δεν χωράει άλλο.
; Η διακοπή καλεί όποιον δείχνει το mus_vec, με την C0 στο #4000 (ram_now:
; ποια τράπεζα να ξαναβάλει μετά — setram).
;
; ΤΑ ΕΦΕ (M21). Μόνο ό,τι γίνεται ΜΕΣΑ στην οθόνη: το snd_at δίνει από τη
; θέση στον κόσμο πόσο μακριά είναι από το κέντρο (εκτός: τίποτα), και η
; ένταση του εφέ πέφτει με την απόσταση. Από όσα ζητήθηκαν σε ένα καρέ
; παίζει το πιο δυνατό, και μόνο αν είναι πιο δυνατό από ό,τι ακούγεται
; ήδη στο C.
FX_CLICK    equ 0               ; το SPACE (όχι στον κόσμο: πάντα)
FX_HIT      equ 1               ; μονάδα που χτυπιέται
FX_BHIT     equ 2               ; κτίριο που χτυπιέται
FX_SHOOT    equ 3               ; βέλος (τοξότης, πύργος)
FX_DONE     equ 4               ; κτίριο έτοιμο
FX_NEW      equ 5               ; νέα μονάδα από κτίριο

; Από τη διακοπή (screen.asm), στο VSYNC: AF και BC είναι ήδη φυλαγμένοι.
snd_isr:
        ld a,(psg_lock)
        or a
        ret nz
        push de
        push hl
        push ix
        ld a,(fx_r7)
        ld c,a
        ld a,7
        call psg_w
        ld a,(mus_vec + 1)
        or a
        jr z,.x
        ld bc,GA * 256 + RAM_BASE
        out (c),c
        call mus_jp
        ld a,(ram_now)
        ld b,GA
        out (c),a
.x:     pop ix
        pop hl
        pop de
        ret

; A = καταχωρητής του AY, C = τιμή. Κρατάει DE, HL.
psg_w:  ld b,#F4
        out (c),a
        ld b,#F6
        ld a,#C0
        out (c),a
        xor a
        out (c),a
        ld b,#F4
        out (c),c
        ld b,#F6
        ld a,#80
        out (c),a
        xor a
        out (c),a
        ret

; HL = κεφαλίδα τραγουδιού, DE = ο player του (mn_mus.tick / hud_mus.tick).
; Από τον κύριο κώδικα· η διακοπή δεν τον καλεί ώσπου να γραφτούν όλα.
mus_play:
        call mus_stop
        ld a,(hl)
        inc hl
        ld (mus_step),a
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        ld (mus_ch),bc          ; A: ptr και αρχή
        ld (mus_ch + 4),bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (mus_ch + 8),bc      ; B
        ld (mus_ch + 12),bc
        ld a,1
        ld (mus_ch + 2),a
        ld (mus_ch + 10),a
        ld (mus_clk),a
        ld (mus_vec),de
        ret

; Σιωπή: η διακοπή αφήνει τον player (το μενού φεύγει από τη μνήμη), οι
; εντάσεις των A, B στο 0. Κρατάει DE, HL.
mus_stop:
        xor a
        ld (mus_vec + 1),a
        ld c,a
        inc a
        ld (psg_lock),a
        ld a,8
        call psg_w
        ld a,9                  ; (ο C μένει 0: psg_w)
        call psg_w
        xor a
        ld (psg_lock),a
        ret

; ------------------------------------------------------------ τα εφέ

; HL = WX, DE = WY (κόσμος) -> carry αν είναι εκτός οθόνης, αλλιώς A =
; πόσο μακριά από το κέντρο (|dx| / 8 + |dy| / 16, 0-8). Κρατάει B.
snd_at: push bc
        ld bc,(cam_x)
        or a
        sbc hl,bc
        ld a,h
        or a
        jr nz,.out
        ld a,l
        cp 80
        jr nc,.out
        sub 40
        jr nc,.x
        neg
.x:     rrca
        rrca
        rrca
        and 7
        ld c,a
        ex de,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.out
        ld a,l
        cp 144
        jr nc,.out
        sub 72
        jr nc,.y
        neg
.y:     rrca
        rrca
        rrca
        rrca
        and 15
        add a,c                 ; (NC: ως 15)
        pop bc
        ret
.out:   pop bc
        scf
        ret

; A = εφέ στη θέση της μονάδας IY / της μονάδας IX / του κτιρίου IY.
; Κρατάει όλα εκτός AF.
snd_unit:
        push hl
        push de
        push bc
        ld l,(iy+U_WX)
        ld h,(iy+U_WX+1)
        ld e,(iy+U_WY)
        ld d,(iy+U_WY+1)
        jr snd_pos
snd_ix: push hl
        push de
        push bc
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        jr snd_pos
snd_bld:
        push hl
        push de
        push bc
        ld l,(iy+B_WX)
        ld h,(iy+B_WX+1)
        ld e,(iy+B_WYB)
        ld d,(iy+B_WYB+1)
snd_pos:
        ld c,a
        call snd_at
        jr c,.no
        ld b,a
        ld a,c
        call snd_req
.no:    pop bc
        pop de
        pop hl
        ret

; A = εφέ, B = απόσταση από το κέντρο: η ένταση του, και αν είναι η
; δυνατότερη του καρέ, το επόμενο εφέ (snd_pf, snd_pv). Κρατάει DE, HL.
snd_req:
        push hl
        ld c,a
        ld hl,fx_vol            ; (μέσα σε μία σελίδα)
        add a,l
        ld l,a
        ld a,(hl)               ; η ένταση στο κέντρο
        sub b
        jr c,.no
        jr z,.no
        ld hl,snd_pv
        cp (hl)
        jr c,.no
        jr z,.no
        ld b,a
        ld a,c
        ld (snd_pf),a           ; πρώτα το εφέ, μετά η ένταση (η διακοπή
        ld (hl),b               ; διαβάζει την ένταση)
.no:    pop hl
        ret

fx_vol:     db 9, 13, 12, 11, 12, 11        ; η ένταση στο κέντρο (FX_*)
        assert (fx_vol & 255) <= 250, 'fx_vol: one page'


; Μία φορά ανά καρέ μονάδων (proj_on): το SPACE κάνει κλικ.
snd_tick:
        ld a,(keyrows + 5)      ; SPACE: γραμμή 5, bit 7
        and #80
        ld hl,snd_kp
        ld c,(hl)
        ld (hl),a
        ret z
        cp c
        ret z
        xor a                   ; FX_CLICK, στο κέντρο
        ld b,a
        jr snd_req

snd_div:    db 6                ; οι διακοπές ως το επόμενο καρέ του ήχου
ram_now:    db RAM_BASE         ; η τράπεζα στο #4000 (setram)
psg_lock:   db 0                ; 1: ο κύριος κώδικας γράφει / διαβάζει το AY
mus_jp:     db #C3              ; jp ο player (mus_vec = 0: σιωπή)
mus_vec:    dw 0
mus_clk:    db 0                ; καρέ ως το επόμενο βήμα
mus_step:   db 0                ; καρέ ανά βήμα
mus_ch:     db 0, 0, 0, 0, 0, 0, 10 * 4, 1      ; A: ptr, cnt, ένταση, -,
            db 0, 0, 0, 0, 0, 0, 9 * 4, 0       ; αρχή, V0 (τέταρτα), οκτάβα
snd_pf:     db 0                ; το εφέ που ζητήθηκε σε αυτό το καρέ
snd_pv:     db 0                ; η ένταση του (0: κανένα)
snd_kp:     db 0                ; το SPACE στο προηγούμενο καρέ
fx_r7:      db #3C              ; το R7: A, B τόνος· C από το εφέ
