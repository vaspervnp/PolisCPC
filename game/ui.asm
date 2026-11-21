; ui.asm — τα μενού στη μέση της οθόνης (M20, 2026-11-21).
;
; ΣΤΙΣ ΚΡΥΦΕΣ ΣΕΙΡΕΣ ΤΗΣ ΣΕΛΙΔΑΣ ΤΟΥ HUD, στο UI_AT (#7230-#76FF: άγραφο σε
; ολόκληρη παρτίδα)· η γραμματοσειρά και τα κείμενα (data/ui_a, b, c.asm,
; src/make_ui.py) σε τρεις άλλες ελεύθερες περιοχές της (main.asm). Ο rasm το συναρμολογεί σε δικό του χώρο (main.asm), και
; το build.sh το βάζει στη δισκέτα ως UI.BIN· το start το φορτώνει μετά το
; hud_init (που καθαρίζει τη σελίδα). Στο snapshot των ελέγχων το γράφει ο
; ίδιος ο έλεγχος (tests/m1_check.py, wait_phase). Τρέχει μόνο με την C0 στο
; #4000, όπως το BOOT.
;
;   um_on = 2   ζωγράφισε το μενού του um_kind (-> 1): οι γραμμές του (um_items)
;   um_on = 1   ανοιχτό: Q / A / βελάκια / joystick αλλάζουν γραμμή, SPACE /
;               RETURN / ENTER / COPY / fire διαλέγουν· το παιχνίδι περιμένει
;   um_on = 0   κλειστό
;
; Το άνοιγμα: um_open (A = το είδος), από την επιλογή — RETURN στους
; επιλεγμένους χωρικούς (BUILD), SPACE σε δικό σου κτίριο, RETURN στη δική
; σου ομάδα. Το κλείσιμο: το ορθογώνιο από τον καθρέφτη (mirror_rect) και οι
; μονάδες ξανά (units_forget) — όχι ολόκληρη σχεδίαση.


UI_COLS     equ 24              ; γλύφοι σε μια σειρά (src/make_ui.py)
; Όσο το μενού είναι ανοιχτό οι μονάδες σταματούν: οι πίνακές του στο RECTS
; (units.asm), μετά το UI_T (οι τεχνολογίες, res_list: ως 2 + 9 x 8).
UM_TAB      equ UI_T + 80
um_act      equ UM_TAB          ; ανά γραμμή: η πράξη,
um_arg      equ um_act + 16     ; το όρισμα,
um_ok       equ um_arg + 16     ; διαλέγεται
um_buf      equ um_ok + 16      ; το κείμενο μιας σειράς (UI_COLS γλύφοι)
um_cv       equ um_buf + UI_COLS ; το κόστος της (4 dw)
        assert um_cv + 8 <= SELLIST, 'um_* past RECTS'
MA_CLOSE    equ 0               ; οι πράξεις των γραμμών
MA_BUILD    equ 1
MA_TRAIN    equ 2
MA_TECH     equ 3
MA_SPLIT    equ 4
MA_BUSY     equ 5
UM_MAX      equ 16
UM_X        equ 2               ; byte, πλάτος (bytes)
UM_W        equ 76
UM_TX       equ UM_X + 2        ; το κείμενο: η στήλη 0 (ο δείκτης)
UI_FRAME    equ #0F             ; τα pens, όπως το tutorial (data/tutor.asm)
UI_BG       equ #C0

um_on:      db 0
um_kind:    db 0
um_n:       db 0                ; γραμμές (μαζί το CLOSE)
um_i:       db 0                ; η τρέχουσα
um_y:       db 0                ; η πρώτη γραμμή του παραθύρου
um_h:       db 0
um_held:    db 0
pn_title:   db #C0, #85, #4A, #0F
pn_text:    db #C0, #C1, #C2, #C3
pn_dim:     db #C0, #81, #42, #03

; A = είδος: το μενού ανοίγει στο επόμενο καρέ (um_go).
um_open:
        ld (um_kind),a
        ld a,2
        ld (um_on),a
        ret

; Από τον κύριο βρόχο, όσο um_on. Carry: το καρέ μονάδων δεν τρέχει.
um_go:  ld a,(um_on)
        cp 2
        jr nz,.open
        call um_items
        jp c,um_off             ; τίποτα να δείξει (σπίτι, χωράφι...)
        call um_draw
        ld a,1
        ld (um_on),a
        ld a,255                ; ό,τι είναι πατημένο: πρώτα να αφεθεί
        ld (um_held),a
        scf
        ret
.open:  call read_matrix
        call um_keys
        ld hl,um_held
        ld c,(hl)
        ld (hl),a
        ld b,a
        ld a,c
        cpl
        and b                   ; A = μόλις πατήθηκαν
        rra
        jr c,.up
        rra
        jr c,.down
        rra
        jr c,.sel
        scf
        ret
.up:    ld a,(um_i)
        ld c,a
.u:     ld a,c
        or a
        jr nz,.u1
        ld a,(um_n)
.u1:    dec a
        ld c,a
        call um_okc
        jr z,.u
        jr .mv
.down:  ld a,(um_i)
        ld c,a
.d:     inc c
        ld a,(um_n)
        cp c
        jr nz,.d1
        ld c,0
.d1:    call um_okc
        jr z,.d
.mv:    push bc
        ld a,(um_i)             ; ο δείκτης: σβήνεται, και στη νέα γραμμή
        call um_ptr0
        pop bc
        ld a,c
        ld (um_i),a
        call um_ptr
        scf
        ret
.sel:   ld a,(um_i)
        ld c,a
        call um_okc
        scf
        ret z
        ld b,0
        ld hl,um_arg
        add hl,bc
        ld e,(hl)
        ld hl,um_act
        add hl,bc
        ld d,(hl)
        push de
        call um_close
        pop de
        ld a,d                  ; η πράξη
        dec a
        jr z,.build
        dec a
        jr z,.train
        dec a
        jr z,.tech
        dec a
        jr z,.split
        jr um_off
.build: ld a,e
        ld (bmode),a
        call cur_look
        jr um_off
.train: call bld_train
        jr um_off
.tech:  ld a,e                  ; η τεχνολογία της γραμμής του UI_T
        call um_tent
        ld c,(hl)
        ld hl,res_go            ; (bank7.asm)
        call far7
        jr um_off
.split: call sq_split

; Κλειστό — ΜΕΤΑ την πράξη (το um_on είναι αυτό που βλέπουν οι έλεγχοι).
; Carry: σε αυτό το καρέ όχι μονάδες.
um_off: xor a
        ld (um_on),a
        scf
        ret

; C = γραμμή -> NZ αν διαλέγεται. Κρατάει BC.
um_okc: ld hl,um_ok
        ld e,c
        ld d,0
        add hl,de
        ld a,(hl)
        or a
        ret

; -> A: bit 0 πάνω, 1 κάτω, 2 επιλογή — τα πλήκτρα του κέρσορα (read_cin,
; input.asm: Q A, joystick, SPACE RETURN ENTER COPY, fire) και τα βελάκια.
um_keys:
        call read_cin
        ld c,a
        and 3                   ; IN_UP, IN_DOWN: τα bits 0, 1
        ld b,a
        ld a,c
        and 1 << IN_FIRE | 1 << IN_CMD
        jr z,.n
        set 2,b
.n:     ld a,(keyrows + 0)      ; τα βελάκια: πάνω (0), κάτω (2)
        ld c,a
        and 1
        or b
        ld b,a
        ld a,c
        rrca
        and 2
        or b
        ret

; Το κλείσιμο: τα βέλη σβήνουν, το ορθογώνιο από τον καθρέφτη, οι μονάδες
; ξανά από την αρχή στο επόμενο καρέ.
um_close:
        ld hl,proj_off
        call far7
        ld a,(um_y)
        ld b,a
        ld c,UM_X
        ld a,(um_h)
        ld e,a
        ld d,UM_W
        call mirror_rect
        jp units_forget

; ------------------------------------------------------------ οι γραμμές

; A = πράξη, C = όρισμα, B = διαλέγεται (0 / 1): μια γραμμή ακόμα.
um_add: push af
        ld a,(um_n)
        ld e,a
        ld d,0
        inc a
        ld (um_n),a
        ld hl,um_arg
        add hl,de
        ld (hl),c
        ld hl,um_ok
        add hl,de
        ld (hl),b
        ld hl,um_act
        add hl,de
        pop af
        ld (hl),a
        ret

; -> οι γραμμές του um_kind· carry αν δεν υπάρχει καμία πράξη.
um_items:
        xor a
        ld (um_n),a
        ld a,(um_kind)
        or a
        jr z,.build
        dec a
        jr z,.bld
        ld a,MA_SPLIT           ; ομάδα: ο χωρισμός
        ld bc,#0100
        call um_add
        jp .close
.build: ld c,0                  ; τα κτίρια της εποχής
.b:     push bc
        ld a,c
        call bt_hl
        inc hl
        ld a,(hud_val + 10)
        cp (hl)
        jr c,.bn
        ld a,c
        call bld_can            ; (boot.asm)
        ld a,0
        rla
        xor 1
        pop bc
        push bc
        ld b,a
        ld a,MA_BUILD
        call um_add
.bn:    pop bc
        inc c
        ld a,c
        cp BT_N
        jr nz,.b
        jp .close
.bld:   ld a,(sel_bld)          ; κτίριο: η μονάδα του, οι τεχνολογίες του
        call brec_iy
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UNIT
        add hl,de
        ld a,(hl)
        inc a
        jr z,.nt
        call bld_can.cost       ; (HL: πριν το κόστος) πληρώνεται;
        ld a,0
        rla
        xor 1
        ld b,a
        ld c,0
        ld a,MA_TRAIN
        call um_add
.nt:    ld hl,res_list          ; (bank7.asm) -> UI_T
        call far7
        ld a,(UI_T + 1)
        inc a
        jr z,.tl
        ld bc,0                 ; ερευνά ήδη: μια γραμμή, που δεν διαλέγεται
        ld a,MA_BUSY
        call um_add
        jr .tc
.tl:    ld a,(UI_T)
        or a
        jr z,.tc
        ld b,a
        ld c,0
.t:     push bc
        ld a,c
        call um_tent
        inc hl
        call um_affw            ; B = πληρώνεται
        pop bc
        push bc
        ld b,a
        ld a,MA_TECH
        call um_add
        pop bc
        inc c
        djnz .t
.tc:    ld a,(um_n)
        or a
        scf
        ret z                   ; κτίριο χωρίς τίποτα
.close: ld bc,#0100
        ld a,MA_CLOSE
        call um_add
        ld c,0                  ; η πρώτη που διαλέγεται
.f:     call um_okc
        jr nz,.fi
        inc c
        jr .f
.fi:    ld a,c
        ld (um_i),a
        or a
        ret

; A = n -> HL = η εγγραφή n του UI_T (ο αριθμός της τεχνολογίας, το κόστος).
um_tent:
        ld e,a
        add a,a
        add a,a
        add a,a
        add a,e
        add a,2
        ld l,a
        ld h,0
        ld de,UI_T
        add hl,de
        ret

; HL -> 4 x κόστος (dw) -> A = 1 αν το φτάνει η μπάρα, αλλιώς 0.
um_affw:
        ld de,hud_val
        ld b,4
.c:     ld a,(de)
        sub (hl)
        inc de
        inc hl
        ld a,(de)
        sbc a,(hl)
        jr c,.no
        inc de
        inc hl
        djnz .c
        ld a,1
        ret
.no:    xor a
        ret

; ------------------------------------------------------------ σχεδίαση

um_draw:
        ld a,(um_n)             ; ύψος: (τίτλος, κενό, γραμμές) x 8 + 6
        add a,2
        add a,a
        add a,a
        add a,a
        add a,6
        ld (um_h),a
        ld e,a
        neg
        add a,VIEW_H
        srl a
        ld (um_y),a
        ld b,a
        ld c,UM_X
        ld d,UM_W
        ld a,UI_FRAME
        call ui_fill
        ld a,(um_y)
        add a,2
        ld b,a
        ld c,UM_X + 1
        ld d,UM_W - 2
        ld a,(um_h)
        sub 4
        ld e,a
        ld a,UI_BG
        call ui_fill
        call um_title           ; ο τίτλος
        ld b,0
        ld ix,pn_title
        call um_row
        ld a,(um_n)
        ld b,a
        ld c,0
.r:     push bc
        call um_text
        pop bc
        push bc
        ld ix,pn_text
        call um_okc
        jr nz,.p
        ld ix,pn_dim
.p:     ld a,c
        add a,2
        ld b,a
        call um_row
        pop bc
        inc c
        djnz .r
        ld a,(um_i)
        jr um_ptr

; A = γραμμή: ο δείκτης (>) στη στήλη 0· um_ptr0: σβήνεται.
um_ptr: call um_ly
        ld c,UM_TX
        ld ix,pn_title
        ld a,UG_PTR
        jp ui_glyph
um_ptr0:
        call um_ly
        ld c,UM_TX
        ld de,#0307
        ld a,UI_BG
        jp ui_fill

; A = γραμμή του μενού -> B = η γραμμή της οθόνης.
um_ly:  add a,2
um_lyr: add a,a
        add a,a
        add a,a
        ld b,a
        ld a,(um_y)
        add a,3
        add a,b
        ld b,a
        ret

; B = σειρά του παραθύρου (0 ο τίτλος), IX = pen: το um_buf, από τη στήλη 1.
um_row: ld a,b
        call um_lyr
        ld c,UM_TX + 3
        ld hl,um_buf + 1
        ld a,UI_COLS - 1
.g:     push af
        ld a,(hl)
        inc hl
        push hl
        push bc
        call ui_glyph
        pop bc
        pop hl
        inc c
        inc c
        inc c
        pop af
        dec a
        jr nz,.g
        ret

; HL -> πλήθος, γλύφοι: στο um_buf από τη στήλη 1 (το um_buf πρώτα κενό).
um_name:
        ld a,(hl)
        inc hl
        ld c,a
        ld b,0
        ld de,um_buf + 1
        ldir
        ret

um_clr: ld hl,um_buf
        ld b,UI_COLS
.c:     ld (hl),UG_SPACE
        inc hl
        djnz .c
        ret

; A = n -> HL = ο δείκτης n του πίνακα HL.
um_ptrn:
        add a,a
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

um_title:
        call um_clr
        ld a,(um_kind)
        or a
        ld hl,ui_w_build
        jr z,.n
        dec a
        jr nz,.sq
        ld a,(sel_bld)          ; το όνομα του κτιρίου
        call brec_iy
        ld a,(iy+B_TYPE)
        ld hl,ui_bld
        call um_ptrn
        jr .n
.sq:    ld ix,(SELLIST)         ; της ομάδας: το όνομα της μονάδας
        ld a,(ix+U_SET)
        ld hl,ui_unit
        call um_ptrn
.n:     jp um_name

; C = γραμμή: το κείμενό της στο um_buf (όνομα αριστερά, κόστος δεξιά).
um_text:
        push bc
        call um_clr
        pop bc
        ld b,0
        ld hl,um_arg
        add hl,bc
        ld e,(hl)
        ld hl,um_act
        add hl,bc
        ld a,(hl)
        or a
        ld hl,ui_w_close
        jp z,um_name
        dec a
        jr z,.build
        dec a
        jr z,.train
        dec a
        jr z,.tech
        dec a
        ld hl,ui_w_split
        jp z,um_name
        ld hl,ui_w_busy
        jp um_name
.build: ld a,e
        push af
        ld hl,ui_bld
        call um_ptrn
        call um_name
        pop af
        call bt_hl
        inc hl
        inc hl
        inc hl
        jr um_costb
.train: ld hl,ui_w_train        ; TRAIN <μονάδα>
        call um_name
        ld a,(sel_bld)
        call brec_iy
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UNIT
        add hl,de
        ld a,(hl)
        push hl
        ld hl,ui_unit
        call um_ptrn
        ld a,(hl)               ; στη στήλη 7: μετά το TRAIN και ένα κενό
        inc hl
        ld c,a
        ld b,0
        ld de,um_buf + 7
        ldir
        pop hl
        inc hl
        jr um_costb
.tech:  ld a,e
        call um_tent
        push hl
        ld a,(hl)
        ld hl,ui_tech
        call um_ptrn
        call um_name
        pop hl
        inc hl
        ld de,um_cv
        ld bc,8
        ldir
        jr um_cost

; HL -> 4 x κόστος (db) -> um_cv, και στο um_buf.
um_costb:
        ld de,um_cv
        ld b,4
.c:     ld a,(hl)
        ld (de),a
        inc de
        xor a
        ld (de),a
        inc de
        inc hl
        djnz .c
; Το um_cv στο um_buf, από τα δεξιά: «35F 15G» (τα μη μηδενικά, με τη σειρά).
um_cost:
        ld ix,um_buf + UI_COLS - 1
        ld iy,um_cv + 6
        ld hl,ui_cl + 3
        ld b,4
.k:     push bc
        push hl
        ld l,(iy+0)
        ld h,(iy+1)
        ld a,h
        or l
        jr z,.n
        ex (sp),hl              ; το γράμμα
        ld a,(hl)
        ex (sp),hl
        ld (ix+0),a
        dec ix
.d:     call div10              ; τα ψηφία, από το τελευταίο
        add a,UG_0
        ld (ix+0),a
        dec ix
        ld a,h
        or l
        jr nz,.d
        dec ix                  ; ένα κενό
.n:     pop hl
        dec hl
        dec iy
        dec iy
        pop bc
        djnz .k
        ret
ui_cl:      db UG_F, UG_W, UG_G, UG_S

; HL / 10 -> HL, A = το υπόλοιπο.
div10:  ld b,16
        xor a
.l:     add hl,hl
        rla
        cp 10
        jr c,.n
        sub 10
        inc l
.n:     djnz .l
        ret

; ------------------------------------------------------------ οθόνη

; B = γραμμή του χάρτη, C = byte -> HL = η διεύθυνση (line_addr). Κρατάει
; BC, DE.
ui_adr: push de
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
        jp mr_wrap

; B = γραμμή, C = byte, D = πλάτος, E = ύψος, A = το byte: γέμισμα.
ui_fill:
        ld (.v + 1),a
.y:     push bc
        push de
        call ui_adr
.v:     ld a,0
.x:     ld (hl),a
        inc l
        jr nz,.c
        call mr_wrap
        ld a,(.v + 1)
.c:     dec d
        jr nz,.x
        pop de
        pop bc
        inc b
        dec e
        jr nz,.y
        ret

; A = γλύφος, B = γραμμή, C = byte, IX = (φόντο|φόντο, φόντο|pen, pen|φόντο,
; pen|pen): 7 γραμμές του γλύφου, 3 bytes η καθεμία. Το κενό: τίποτα (το
; φόντο είναι ήδη εκεί).
ui_glyph:
        cp UG_SPACE
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
        ld de,ui_font
        add hl,de
        ld e,7
.row:   ld a,(hl)
        inc hl
        push hl
        rlca                    ; τα 5 bits στα 7-3: ζεύγη (7,6) (5,4) (3,-)
        rlca
        rlca
        ld d,a
        push bc
        call ui_adr
        ld a,3
.b:     push af
        ld a,d                  ; τα δύο ψηλά bits -> 0..3
        rlca
        rlca
        and 3
        ld (.pk + 2),a
.pk:    ld a,(ix+0)
        ld (hl),a
        inc l
        call z,mr_wrap
        ld a,d
        add a,a
        add a,a
        ld d,a
        pop af
        dec a
        jr nz,.b
        pop bc
        inc b
        pop hl
        dec e
        jr nz,.row
        ret

