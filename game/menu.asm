; menu.asm — το μενού έναρξης (M12): πολιτισμός, εκστρατεία (M13) ή
; φόρτωμα της παρτίδας.
;
; ΜΟΝΟ ΣΤΗΝ ΕΚΚΙΝΗΣΗ ΑΠΟ ΤΗ ΔΙΣΚΕΤΑ (όχι στο snapshot των ελέγχων: εκεί οι
; Έλληνες, χωρίς ερώτηση). Τρέχει στη θέση του, μέσα στα δεδομένα της
; εκκίνησης (main.asm), μετά το units_gfx — η οθόνη είναι ελεύθερη — και
; πριν το INIT (#F000) και το HUD γράψουν από πάνω.
;
; Βελάκια πάνω/κάτω, και SPACE, RETURN, COPY ή ENTER. Ένας πολιτισμός: το
; γράμμα του στα ονόματα των αρχείων των εποχών (age3_name, age4_name). Το
; φόρτωμα: load_req = 1 (fog_init, init.asm).
;
; ΕΚΣΤΡΑΤΕΙΑ (M13): η πρόοδος από το PROG.BIN (ένα byte ανά εκστρατεία: η
; επόμενη πίστα), η πίστα (LG1.BIN ...) στη θέση του χάρτη — η κεφαλίδα της
; πέφτει στο LV_HDR (#A400, το lv_init του init.asm την παίρνει πριν το
; bld_init γράψει εκεί) — και η οθόνη της πίστας ώσπου να πατηθεί πλήκτρο.
; Μετά από νίκη ή ήττα, το mod_camp (savegame.asm) γράφει την πρόοδο, αφήνει
; στο LV_FLAG ποια πίστα ακολουθεί, και ξαναφορτώνει το POLIS.BIN: εδώ, η
; πίστα κατευθείαν, χωρίς μενού.

        include "../data/menu.asm"

LV_FLAG     equ UNIT_TAB        ; #A5, #5A, εκστρατεία, πίστα (το units_init
                                ; το σβήνει)

menu:
        ifdef SNA               ; (ο κύριος κώδικας ίδιος και στα δύο: τα
        ret                     ; σύμβολα των ελέγχων είναι του snapshot)
        endif
        ld hl,LV_FLAG           ; η επόμενη πίστα της εκστρατείας (mod_camp)
        ld a,(hl)
        ld (hl),0
        cp #A5
        jr nz,.ui
        inc hl
        ld a,(hl)
        cp #5A
        jr nz,.ui
        inc hl
        ld a,(hl)
        ld (mn_camp),a
        inc hl
        ld a,(hl)
        jp lv_go
.ui:    xor a                   ; καμία κεφαλίδα: η παρτίδα του χάρτη της
        ld (LV_HDR),a           ; εκκίνησης (lv_init)
        call mn_cls
        ld hl,menu_lines
        call mn_text
        ld a,MENU_DEF
        ld (mn_sel),a
        ld a,255
        ld (mn_held),a          ; ό,τι είναι πατημένο από πριν: όχι
.mark:  ld a,MG_ARROW
        call mn_mark
.k:     call mn_keys
        jr z,.k
        ld a,(keyrows + 0)
        rra
        jr c,.up
        rra
        rra
        jr c,.down
        call mn_rel
        ld a,(mn_sel)           ; επιλογή
        cp MENU_N - 1
        jr z,.load
        sub MENU_CULT
        jr nc,.camp
        add a,MENU_CULT
        ld hl,cult_let
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ld (age3_name + 4),a
        ld (age4_name + 4),a
        ret
.camp:  inc a                   ; 1, 2
        ld (mn_camp),a
        xor a                   ; η πίστα από την πρόοδο
        jp lv_go
.load:  ld a,1
        ld (load_req),a
        ret
.up:    ld a,MG_BLANK
        call mn_mark
        ld a,(mn_sel)
        or a
        jr nz,.u
        ld a,MENU_N
.u:     dec a
        ld (mn_sel),a
        jr .mark
.down:  ld a,MG_BLANK
        call mn_mark
        ld a,(mn_sel)
        inc a
        cp MENU_N
        jr c,.d
        xor a
.d:     ld (mn_sel),a
        jr .mark

; A = η πίστα (0: η επόμενη της προόδου), mn_camp = η εκστρατεία (1, 2):
; η πίστα στον χάρτη, η κεφαλίδα της στο LV_HDR, η οθόνη της. Χωρίς το
; αρχείο της: η παρτίδα του χάρτη της εκκίνησης.
lv_go:  push af
        ld hl,prog_name         ; η πρόοδος (χωρίς αρχείο: από την αρχή)
        call disk_load
        ld hl,(LOAD_AT)
        jr nc,.p
        ld hl,0
.p:     ld (mn_prog),hl
        ld hl,mn_prog - 1
        call mn_campb
        pop af
        or a
        jr nz,.n
        ld a,(hl)               ; 1-4 (0 ή άλλο: η 1)
        dec a
        cp 4
        jr c,.n1
        xor a
.n1:    inc a
.n:     ld (mn_num),a
        add a,"0"
        ld (lv_name + 2),a
        ld hl,camp_let - 1
        call mn_campb
        ld a,(hl)
        ld (lv_name + 1),a
        ld hl,lv_name
        call disk_load
        di                      ; (το disk_load τις ανοίγει)
        jr c,.none
        ld hl,LOAD_AT           ; ο χάρτης και η κεφαλίδα του
        ld de,MAP
        call dzx0
        ld a,(mn_camp)
        ld (LV_HDR + H_CAMP),a
        ld a,(mn_num)
        ld (LV_HDR + H_NUM),a
        ld hl,(mn_prog)
        ld (LV_HDR + H_PROG),hl
        call mn_cls             ; η οθόνη της πίστας
        ld hl,LV_HDR + H_TEXT
        call mn_text
        ld a,255
        ld (mn_held),a
.w:     call mn_keys
        jr z,.w
        call mn_rel
        di
        ret
.none:  xor a
        ld (LV_HDR),a
        ret

; HL = πίνακας - 1 -> HL += mn_camp.
mn_campb:
        ld a,(mn_camp)
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; Η οθόνη μαύρη.
mn_cls: ld hl,SCREEN
        ld de,SCREEN + 1
        ld bc,#3FFF
        ld (hl),0
        ldir
        ret

; HL = γραμμές κειμένου (menu_lines: γραμμή, byte, pen, πλήθος, γλύφοι,
; ... 255) -> στην οθόνη.
mn_text:
.ln:    ld a,(hl)
        cp 255
        ret z
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

; -> NZ και τα πλήκτρα στο keyrows όταν πατήθηκε κάποιο του μενού που δεν
; κρατιόταν ήδη (πάνω, κάτω, ENTER, COPY, RETURN, SPACE).
mn_keys:
        call wait_vsync
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
        dec c
        inc c
        jr z,.new
        xor a                   ; κρατιέται ακόμα από πριν
        ret
.new:   or a
        ret

; Ως να αφεθούν όλα: αλλιώς το SPACE θα ήταν και το πρώτο κλικ του
; παιχνιδιού.
mn_rel: call wait_vsync
        call read_matrix
        ld a,(keyrows + 0)
        ld hl,keyrows + 1
        or (hl)
        inc hl
        or (hl)
        ld hl,keyrows + 5
        or (hl)
        jr nz,mn_rel
        ret

; A = γλύφος: το βέλος (ή κενό) μπροστά από την επιλογή mn_sel.
mn_mark:
        push af
        ld a,(mn_sel)
        ld hl,menu_iy
        add a,l
        ld l,a
        jr nc,.y
        inc h
.y:     ld a,(hl)
        ld (mn_y),a
        ld a,MENU_X
        ld (mn_x),a
        ld a,MENU_PEN
        ld (mn_pl),a
        pop af

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
mn_camp:    db 0
mn_num:     db 0
mn_prog:    dw 0
prog_name:  db "PROG    BIN"
lv_name:    db "LG1     BIN"
