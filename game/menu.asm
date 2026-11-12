; menu.asm — το μενού έναρξης (M12): πολιτισμός ή φόρτωμα της παρτίδας.
;
; ΜΟΝΟ ΣΤΗΝ ΕΚΚΙΝΗΣΗ ΑΠΟ ΤΗ ΔΙΣΚΕΤΑ (όχι στο snapshot των ελέγχων: εκεί οι
; Έλληνες, χωρίς ερώτηση). Τρέχει στη θέση του, μέσα στα δεδομένα της
; εκκίνησης (main.asm), μετά το units_gfx — η οθόνη είναι ελεύθερη — και
; πριν το INIT (#F000) και το HUD γράψουν από πάνω.
;
; Βελάκια πάνω/κάτω, και SPACE, RETURN, COPY ή ENTER. Ένας πολιτισμός: το
; γράμμα του στα ονόματα των αρχείων των εποχών (age3_name, age4_name). Το
; φόρτωμα: load_req = 1 (fog_init, init.asm).

        include "../data/menu.asm"

menu:
        ifdef SNA               ; (ο κύριος κώδικας ίδιος και στα δύο: τα
        ret                     ; σύμβολα των ελέγχων είναι του snapshot)
        endif
        ld hl,SCREEN
        ld de,SCREEN + 1
        ld bc,#3FFF
        ld (hl),0
        ldir
        ld hl,menu_lines
.ln:    ld a,(hl)
        cp 255
        jr z,.drawn
        ld (mn_y),a
        inc hl
        ld a,(hl)
        ld (mn_x),a
        inc hl
        ld a,(hl)
        ld (mn_pl),a
        inc hl
        ld b,(hl)
        inc hl
.ch:    ld a,(hl)
        inc hl
        push hl
        push bc
        call mn_glyph
        pop bc
        pop hl
        ld a,(mn_x)
        add a,3
        ld (mn_x),a
        djnz .ch
        jr .ln
.drawn: ld a,MENU_DEF
        ld (mn_sel),a
        ld a,255
        ld (mn_held),a          ; ό,τι είναι πατημένο από πριν: όχι
.mark:  ld a,MG_ARROW
        call mn_mark
.k:     call wait_vsync
        call read_matrix
        ld a,(keyrows + 0)      ; πάνω (0), κάτω (2), ENTER (6)
        and #45
        ld c,a
        ld a,(keyrows + 1)      ; COPY (1)
        and #02
        or c
        ld c,a
        ld a,(keyrows + 2)      ; RETURN (2)
        and #04
        or c
        ld c,a
        ld a,(keyrows + 5)      ; SPACE (7)
        and #80
        or c
        ld hl,mn_held
        ld c,(hl)
        ld (hl),a
        jr z,.k                 ; τίποτα
        ld a,c
        or a
        jr nz,.k                ; κρατιέται ακόμα από πριν
        ld a,(keyrows + 0)
        rra
        jr c,.up
        rra
        rra
        jr c,.down
        ld a,(mn_sel)           ; επιλογή
        cp MENU_N - 1
        jr z,.load
        ld hl,cult_let
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ld (age3_name + 4),a
        ld (age4_name + 4),a
        jr .rel
.load:  ld a,1
        ld (load_req),a
.rel:   call wait_vsync         ; ως να αφεθούν: αλλιώς το SPACE θα ήταν
        call read_matrix        ; και το πρώτο κλικ του παιχνιδιού
        ld a,(keyrows + 0)
        ld hl,keyrows + 1
        or (hl)
        inc hl
        or (hl)
        ld hl,keyrows + 5
        or (hl)
        jr nz,.rel
        ret
.up:    ld a,MG_BLANK
        call mn_mark
        ld a,(mn_sel)
        or a
        jr nz,.u
        ld a,MENU_N
.u:     dec a
        ld (mn_sel),a
        jp .mark
.down:  ld a,MG_BLANK
        call mn_mark
        ld a,(mn_sel)
        inc a
        cp MENU_N
        jr c,.d
        xor a
.d:     ld (mn_sel),a
        jp .mark

; A = γλύφος: το βέλος (ή κενό) μπροστά από την επιλογή mn_sel.
mn_mark:
        push af
        ld a,(mn_sel)
        ld c,a
        add a,a                 ; y = MENU_Y0 + 16 x επιλογή
        add a,a
        add a,a
        add a,a
        add a,MENU_Y0
        ld (mn_y),a
        ld a,MENU_X
        ld (mn_x),a
        ld a,MENU_PEN
        ld (mn_pl),a
        pop af
        assert MENU_DY == 16, 'MENU_DY'

; A = γλύφος -> στο (mn_x, mn_y), με το pen mn_pl, 7 γραμμές x 2.
mn_glyph:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; 7 x A
        ld de,menu_font
        add hl,de
        ld a,(mn_y)
        ld c,a
        ld b,7
.row:   ld a,(hl)
        inc hl
        rlca                    ; τα 5 bits στα 7..3
        rlca
        rlca
        ld e,a
        call mn_line
        inc c
        call mn_line
        inc c
        djnz .row
        ret

; C = γραμμή οθόνης, E = τα bits: 3 bytes στο mn_x. Κρατάει BC, E, HL.
mn_line:
        push bc
        push hl
        push de
        ld l,c
        ld h,0
        add hl,hl
        ld bc,line_addr
        add hl,bc
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld a,(mn_x)
        add a,l
        ld l,a
        jr nc,.x
        inc h
.x:     ld b,3
.b:     ld c,0
        rl e
        jr nc,.r
        ld a,(mn_pl)
        ld c,a
.r:     rl e
        jr nc,.s
        ld a,(mn_pl)
        srl a
        or c
        ld c,a
.s:     ld (hl),c
        inc hl
        djnz .b
        pop de
        pop hl
        pop bc
        ret

mn_x:       db 0
mn_y:       db 0
mn_pl:      db 0
mn_sel:     db 0
mn_held:    db 0
