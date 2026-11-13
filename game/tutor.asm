; tutor.asm — το tutorial: ο Ηρόδοτος εξηγεί το επόμενο βήμα, σε παράθυρο
; στη μέση της οθόνης.
;
; ΣΤΗΝ C6, στο TUT_AT (#5700-#5F7F: μετά τις εικόνες της Εποχής των
; Εργαλείων, πριν την ομίχλη). Ο rasm το συναρμολογεί σε δικό του χώρο
; (main.asm) και το build.sh το βάζει στη δισκέτα ως TUTOR.BIN (ZX0). Το
; μενού (TUTORIAL) το φορτώνει, βάζει tut_on = 1, tut_win = 2 και κλείνει
; τον αντίπαλο.
;
; Ο κύριος βρόχος (main.asm), σε κάθε καρέ μονάδων όσο tut_on: far6 στο
; tut_go. Όσο tut_win != 0 το καρέ μονάδων δεν τρέχει: το παιχνίδι
; περιμένει.
;   tut_win = 2   ζωγράφισε το παράθυρο του βήματος tut_step (-> 1)
;   tut_win = 1   ανοιχτό: RETURN / SPACE / COPY / ENTER το κλείνει
;                 (ξαναζωγραφίζεται ο χάρτης: redraw)· μετά το τελευταίο
;                 βήμα, tut_on = 0
;   tut_win = 0   κλειστό: ο έλεγχος του βήματος (tut_goals) — όταν
;                 πετύχει, το επόμενο βήμα (-> 2)
;
; Το κείμενο, το πορτρέτο, η γραμματοσειρά: data/tutor.asm
; (src/make_tutor.py). Η Εποχή του Χαλκού γράφει πάνω στην C6 ως το #6200
; (age_load): τότε το tutorial σταματά (tut_go: age_req / εποχή).

        include "../data/tutor.asm"

; Από τον κύριο βρόχο (far6), με την C6 στο #4000. Carry όσο το παράθυρο
; είναι (ή θα γίνει) ανοιχτό: το καρέ μονάδων δεν τρέχει.
tut_go:
        call tut_run
        ld a,(tut_win)
        cp 1
        ccf
        ret

tut_run:
        ld a,(hud_val + 10)     ; άλλη εποχή: τα δεδομένα δεν είναι πια εδώ
        cp START_AGE
        jr nz,tut_off
        ld a,(tut_win)
        or a
        jr z,tut_goal
        dec a
        jr z,.open
        ld a,1                  ; 2: το παράθυρο
        ld (tut_win),a
        ld a,255
        ld (tut_held),a         ; ό,τι είναι πατημένο: πρώτα να αφεθεί
        jp tut_draw
.open:  call read_matrix
        call tut_keys
        ld hl,tut_held
        ld c,(hl)
        ld (hl),a
        or a
        ret z
        inc c                   ; ήταν ήδη πατημένο (ή 255: από πριν)
        dec c
        ret nz
        xor a                   ; κλείσιμο
        ld (tut_win),a
        inc a
        ld (redraw),a
        ld a,(tut_step)
        cp TUT_STEPS - 1
        ret c
tut_off:
        xor a
        ld (tut_on),a
        ld (tut_win),a
        ret
tut_goal:
        ld a,(tut_step)         ; ο έλεγχος του βήματος
        add a,a
        ld l,a
        ld h,0
        ld de,tut_goals
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call tut_jp
        ret nc
        ld hl,tut_step          ; έγινε: το επόμενο βήμα
        inc (hl)
        call tut_mark
        ld a,2
        ld (tut_win),a
        ret
tut_jp: jp (hl)

; -> A != 0 αν πατήθηκε RETURN, SPACE, COPY ή ENTER (keyrows).
tut_keys:
        ld a,(keyrows + 0)
        and #40                 ; ENTER
        ld c,a
        ld a,(keyrows + 1)
        and #02                 ; COPY
        or c
        ld c,a
        ld a,(keyrows + 2)
        and #04                 ; RETURN
        or c
        ld c,a
        ld a,(keyrows + 5)
        and #80                 ; SPACE
        or c
        ret

; Στην αρχή κάθε βήματος: ο πληθυσμός (για το g_train).
tut_mark:
        ld a,(hud_val + 8)
        ld (tut_pop),a
        ret

; ------------------------------------------------------------ οι έλεγχοι
; Carry = το βήμα έγινε.

g_now:  scf
        ret

; Επιλεγμένος ένας χωρικός του παίκτη.
g_sel:  ld a,(sel_n)
        or a
        ret z
        ld ix,(SELLIST)
        ld a,(ix+U_TEAM)
        or a
        ret nz
        ld a,(ix+U_SET)
        or a
        jr z,.y
        cp 3
        ret nz
.y:     scf
        ret

; Ένας χωρικός του παίκτη μαζεύει (πηγαίνει, δουλεύει ή γυρίζει).
g_gather:
        ld ix,UNIT_TAB
        ld b,UNITS
        ld de,U_SIZE
.l:     ld a,(ix+U_TEAM)
        or a
        jr nz,.n
        ld a,(ix+U_JOB)
        dec a
        cp 3                    ; J_GO, J_WORK, J_BACK
        ret c
.n:     add ix,de
        djnz .l
        or a
        ret

; Ένα κτίριο του παίκτη του τύπου C (και ST >= E: 0 θεμέλιο, 1 έτοιμο).
; Carry αν υπάρχει.
tut_bld:
        ld a,(bld_top)
        or a
        ret z
        ld b,a
.l:     ld a,b
        dec a
        push bc
        push de
        call brec_iy
        pop de
        pop bc
        ld a,(iy+B_TYPE)
        cp c
        jr nz,.n
        ld a,(iy+B_OWN)
        or a
        jr nz,.n
        ld a,(iy+B_ST)
        cp e
        jr c,.n
        scf
        ret
.n:     djnz .l
        or a
        ret

g_house:
        ld c,BTY_HOUSE
        ld e,0
        jr tut_bld

g_barr: ld c,BTY_BARRACKS
        ld e,0
        jr tut_bld

; Ένας χωρικός στην ουρά του Κέντρου Πόλης, ή ο πληθυσμός μεγάλωσε.
g_train:
        ld a,(tut_pop)
        ld c,a
        ld a,(hud_val + 8)
        cp c
        jr z,.q
        ccf                     ; περισσότεροι: carry
        ret
.q:     ld a,(bld_top)
        or a
        ret z
        ld b,a
.l:     ld a,b
        dec a
        push bc
        call brec_iy
        pop bc
        ld a,(iy+B_TYPE)
        or a                    ; BTY_TOWN_CENTER
        jr nz,.n
        ld a,(iy+B_OWN)
        or a
        jr nz,.n
        ld a,(iy+B_QN)
        or a
        jr z,.n
        scf
        ret
.n:     djnz .l
        or a
        ret

; Ένας σπαθοφόρος του παίκτη.
g_sword:
        ld ix,UNIT_TAB
        ld b,UNITS
        ld de,U_SIZE
.l:     ld a,(ix+U_TEAM)
        or a
        jr nz,.n
        ld a,(ix+U_SET)
        dec a
        jr nz,.n
        scf
        ret
.n:     add ix,de
        djnz .l
        or a
        ret

; ------------------------------------------------------------ το παράθυρο

; B = γραμμή του χάρτη, C = byte -> HL = η διεύθυνση στην οθόνη (line_addr:
; η κύλιση του CRTC). Κρατάει BC, DE.
tut_adr: push de
        ld l,b
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        add a,c
        ld l,a
        pop de
        ret nc
; HL: το επόμενο byte πέρασε τα 256 — μέσα στο ίδιο κομμάτι των 2 KB.
tut_wrap:
        inc h
        ld a,h
        and 7
        ret nz
        ld a,h
        sub 8
        ld h,a
        ret

; HL = byte της οθόνης -> το επόμενο της ίδιας γραμμής.
tut_inc:
        inc l
        ret nz
        jr tut_wrap

; B = γραμμή, C = byte, D = πλάτος, E = ύψος, A = το byte: γέμισμα.
tut_fill:
        ld (.v + 1),a
.y:     push bc
        push de
        call tut_adr
.v:     ld a,0
.x:     ld (hl),a
        inc l
        jr nz,.c
        call tut_wrap
        ld a,(.v + 1)
.c:     dec d
        jr nz,.x
        pop de
        pop bc
        inc b
        dec e
        jr nz,.y
        ret

tut_draw:
        ld bc,TW_Y * 256 + TW_X
        ld de,TW_W * 256 + TW_H
        ld a,TW_FRAME
        call tut_fill
        ld bc,(TW_Y + 1) * 256 + TW_X
        ld de,1 * 256 + TW_H - 2
        ld a,TW_FRAME_L
        call tut_fill
        ld bc,(TW_Y + 1) * 256 + TW_X + 1
        ld de,(TW_W - 2) * 256 + TW_H - 2
        ld a,TW_BG
        call tut_fill
        ld bc,(TW_Y + 1) * 256 + TW_X + TW_W - 1
        ld de,1 * 256 + TW_H - 2
        ld a,TW_FRAME_R
        call tut_fill
        ld hl,tut_por           ; το πορτρέτο
        ld bc,TP_Y * 256 + TP_X
        ld a,TP_H
.py:    push af
        push bc
        push hl
        call tut_adr
        ex de,hl                ; DE = η οθόνη
        pop hl                  ; HL = το πορτρέτο
        ld b,TP_W
.px:    ld a,(hl)
        ld (de),a
        inc hl
        ex de,hl
        call tut_inc
        ex de,hl
        djnz .px
        pop bc
        inc b
        pop af
        dec a
        jr nz,.py
        ld hl,tut_title         ; ο τίτλος
        ld bc,TT_TITLE_Y * 256 + TT_X
        ld ix,tp_title
        call tut_str
        ld hl,tut_hint
        ld bc,TT_HINT_Y * 256 + TT_HINT_X
        ld ix,tp_hint
        call tut_str
        ld a,(tut_step)         ; το κείμενο: TUT_ROWS x TUT_COLS
        ld e,a
        ld d,0
        ld hl,0
        ld b,TUT_ROWS * TUT_COLS
.m:     add hl,de
        djnz .m
        ld de,tut_texts
        add hl,de
        ld bc,TT_Y0 * 256 + TT_X
        ld a,TUT_ROWS
.r:     push af
        push bc
        ld ix,tp_text
        ld a,TUT_COLS
        call tut_line
        pop bc
        ld a,b
        add a,TT_DY
        ld b,a
        pop af
        dec a
        jr nz,.r
        ret

; HL -> πλήθος, γλύφοι. B = γραμμή, C = byte, IX = τα bytes του pen.
tut_str:
        ld a,(hl)
        inc hl
; A = πλήθος, HL -> γλύφοι. -> HL μετά.
tut_line:
.g:     push af
        ld a,(hl)
        inc hl
        push hl
        push bc
        call tut_glyph
        pop bc
        pop hl
        ld a,c
        add a,3
        ld c,a
        pop af
        dec a
        jr nz,.g
        ret

; A = γλύφος, B = γραμμή, C = byte, IX = (φόντο|φόντο, φόντο|pen,
; pen|φόντο, pen|pen): 7 γραμμές του γλύφου, η καθεμία δύο φορές, 3 bytes.
tut_glyph:
        cp TG_SPACE             ; το κενό: το φόντο είναι ήδη εκεί
        ret z
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de               ; 7 x
        ld de,tut_font
        add hl,de
        ld e,7
.row:   ld a,(hl)
        inc hl
        push hl
        rlca                    ; τα 5 bits στα 7-3: ζεύγη (7,6) (5,4) (3,-)
        rlca
        rlca
        ld d,a
        ld a,2                  ; δύο γραμμές της οθόνης
.two:   push af
        push bc
        push de
        call tut_adr
        ld a,3
.b:     push af
        ld a,d                  ; τα δύο ψηλά bits -> 0..3
        rlca
        rlca
        and 3
        push hl
        ld (.pk + 2),a
.pk:    ld a,(ix+0)
        pop hl
        ld (hl),a
        call tut_inc
        ld a,d
        add a,a
        add a,a
        ld d,a
        pop af
        dec a
        jr nz,.b
        pop de
        pop bc
        inc b
        pop af
        dec a
        jr nz,.two
        pop hl
        dec e
        jr nz,.row
        ret

tut_held:   db 0
tut_pop:    db 0
tut_end:
