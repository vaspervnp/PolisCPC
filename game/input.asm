; input.asm — ο κέρσορας, η επιλογή και η εντολή κίνησης. M4.
;
;   Q A O P ή joystick   ο κέρσορας (2 bytes / 6 γραμμές ανά καρέ). Στην
;                        άκρη της οθόνης, ό,τι σπρώχνει πέρα κυλάει τον χάρτη
;   SPACE ή fire 1       πάτημα + άφημα στο ίδιο σημείο: επιλογή της μονάδας
;                        κάτω από τον κέρσορα· με σύρσιμο: κουτί επιλογής
;   RETURN, ENTER, COPY, fire 2  οι επιλεγμένες στον κέρσορα, σε σχηματισμό
;
; Τα βελάκια μένουν για την κύλιση (scroll.asm). Το «σημείο» του κέρσορα
; είναι το πάνω-αριστερό pixel του sprite (cur_x bytes, cur_y γραμμές
; οθόνης). Η μονάδα «πατάει» στο (WX + 2, WY + 14): εκεί τη στέλνει η εντολή,
; εκεί την πιάνει το κουτί.

SEL_MAX     equ 32
SELLIST     equ #A840           ; 32 x δείκτης εγγραφής (μετά τα RECTS)
CUR_DX      equ 2
CUR_DY      equ 6

; Τα bits του cin (1 = πατημένο).
IN_UP       equ 0
IN_DOWN     equ 1
IN_LEFT     equ 2
IN_RIGHT    equ 3
IN_FIRE     equ 4
IN_CMD      equ 5

cursor_input:
        call bld_input          ; τα πλήκτρα των κτιρίων (buildings.asm)
        ld a,9                  ; joystick: 0 πάνω, 1 κάτω, 2 αριστερά,
        call read_row           ; 3 δεξιά, 4 fire 2, 5 fire 1
        ld e,a
        and #0F
        ld d,a
        bit 5,e
        jr z,.j1
        set IN_FIRE,d
.j1:    bit 4,e
        jr z,.j2
        set IN_CMD,d
.j2:    ld a,8                  ; Q (3), A (5)
        call read_row
        bit 3,a
        jr z,.k1
        set IN_UP,d
.k1:    bit 5,a
        jr z,.k2
        set IN_DOWN,d
.k2:    ld a,4                  ; O (2)
        call read_row
        bit 2,a
        jr z,.k3
        set IN_LEFT,d
.k3:    ld a,3                  ; P (3)
        call read_row
        bit 3,a
        jr z,.k4
        set IN_RIGHT,d
.k4:    ld a,5                  ; SPACE (7)
        call read_row
        bit 7,a
        jr z,.k5
        set IN_FIRE,d
.k5:    ld a,2                  ; RETURN (2)
        call read_row
        bit 2,a
        jr z,.k6
        set IN_CMD,d
.k6:    ld a,1                  ; COPY (1)
        call read_row
        bit 1,a
        jr z,.k8
        set IN_CMD,d
.k8:    xor a                   ; ENTER του αριθμητικού (0): πολλοί emulators
        call read_row           ; δίνουν εκεί το Enter του PC
        bit 6,a
        jr z,.k7
        set IN_CMD,d
.k7:    ld a,d
        ld (cin),a

        bit IN_LEFT,d           ; ο κέρσορας, και η κύλιση στις άκρες
        jr z,.nl
        ld a,(cur_x)
        sub CUR_DX
        jr nc,.lok
        ld a,-1
        ld (sdx),a
        xor a
.lok:   ld (cur_x),a
.nl:    bit IN_RIGHT,d
        jr z,.nr
        ld a,(cur_x)
        add a,CUR_DX
        cp 77
        jr c,.rok
        ld a,1
        ld (sdx),a
        ld a,76
.rok:   ld (cur_x),a
.nr:    bit IN_UP,d
        jr z,.nu
        ld a,(cur_y)
        sub CUR_DY
        jr nc,.uok
        ld a,-1
        ld (sdy),a
        xor a
.uok:   ld (cur_y),a
.nu:    bit IN_DOWN,d
        jr z,.nd
        ld a,(cur_y)
        add a,CUR_DY
        cp VIEW_H - 16 + 1
        jr c,.dok
        ld a,1
        ld (sdy),a
        ld a,VIEW_H - 16
.dok:   ld (cur_y),a
.nd:
        ld a,(cin_prev)         ; πατήματα και αφήματα
        ld e,a
        ld a,d
        ld (cin_prev),a
        cpl
        and e
        ld c,a                  ; C = αφέθηκαν
        ld a,e
        cpl
        and d
        ld b,a                  ; B = πατήθηκαν
        bit IN_FIRE,b
        jr z,.nf
        push bc
        call cur_world          ; η γωνία του κουτιού εδώ
        ld hl,(cw_x)
        ld (ANCHOR_REC + U_WX),hl
        ld hl,(cw_y)
        ld (ANCHOR_REC + U_WY),hl
        ld a,1
        ld (box_on),a
        ld (anc_force),a
        pop bc
.nf:    bit IN_FIRE,c
        jr z,.nrel
        push bc
        xor a
        ld (box_on),a
        call do_select
        pop bc
.nrel:  bit IN_CMD,b
        ret z
        jp do_command

; Ο κέρσορας στον κόσμο -> cw_x, cw_y (ποτέ αρνητικά).
cur_world:
        ld hl,(cam_x)
        ld a,(cur_x)
        ld e,a
        ld d,0
        add hl,de
        ld (cw_x),hl
        ld hl,(cam_y)
        ld a,(cur_y)
        ld e,a
        add hl,de
        bit 7,h
        jr z,.y
        ld hl,0
.y:     ld (cw_y),hl
        ret

; Άφημα του fire. Ξε-επιλογή όλων (από τη λίστα SELLIST), και μετά: αν ο
; κέρσορας είναι σχεδόν εκεί που πατήθηκε, η μονάδα κάτω του (η πιο
; μπροστινή)· αλλιώς όσες ΦΑΙΝΟΝΤΑΙ (το ORDER) και πατάνε μέσα στο κουτί.
do_select:
        ld a,1                  ; η γωνία / το σημάδι αλλάζει
        ld (anc_force),a
        ld a,255                ; κανένα κτίριο (το κλικ μπορεί να βρει)
        ld (sel_bld),a
        call cur_world
        ld a,(sel_n)
        or a
        jr z,.d0
        ld b,a
        ld hl,SELLIST
.d:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        pop ix
        res F_SEL,(ix+U_FL)
        set F_REDRAW,(ix+U_FL)
        djnz .d
        xor a
        ld (sel_n),a
.d0:        ld hl,(cw_x)            ; κλικ ή κουτί;
        ld de,(ANCHOR_REC + U_WX)
        or a
        sbc hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.box
        ld a,l
        cp 3
        jr nc,.box
        ld hl,(cw_y)
        ld de,(ANCHOR_REC + U_WY)
        or a
        sbc hl,de
        call abs_hl
        ld a,h
        or a
        jr nz,.box
        ld a,l
        cp 8
        jr nc,.box
        ; ΚΛΙΚ: από τη μπροστινή (τέλος του ORDER) προς τα πίσω
        ld a,(ord_n)
        or a
        jp z,bld_pick
        ld b,a
        add a,a
        ld l,a
        ld h,0
        ld de,ORDER
        add hl,de
.cl:    dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        push de
        pop ix
        ld a,(cur_x)
        sub (ix+U_SX)
        cp 4
        jr nc,.cn
        ld a,(cur_y)
        sub (ix+U_SY)
        cp 16
        jr nc,.cn
        jp unit_select
.cn:    djnz .cl
        jp bld_pick             ; καμία μονάδα: κτίριο;
.box:   ; ΚΟΥΤΙ: x0..x1, y0..y1 στον κόσμο
        ld hl,(cw_x)
        ld de,(ANCHOR_REC + U_WX)
        call order_hl_de
        ld (bx0),hl
        ld (bx1),de
        ld hl,(cw_y)
        ld de,(ANCHOR_REC + U_WY)
        call order_hl_de
        ld (by0),hl
        ld (by1),de
        ld a,(ord_n)
        or a
        ret z
        ld b,a
        ld hl,ORDER
.b:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        pop ix
        ld l,(ix+U_WX)          ; τα πόδια: (WX + 2, WY + 14)
        ld h,(ix+U_WX+1)
        inc hl
        inc hl
        ld de,(bx0)
        call cmp_hl_de          ; carry: hl < de
        jr c,.bn
        ex de,hl
        ld hl,(bx1)
        call cmp_hl_de
        jr c,.bn
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld de,14
        add hl,de
        ld de,(by0)
        call cmp_hl_de
        jr c,.bn
        ex de,hl
        ld hl,(by1)
        call cmp_hl_de
        jr c,.bn
        call unit_select
.bn:    pop hl
        pop bc
        djnz .b
        ret

; IX -> επιλεγμένη, στη λίστα (ως SEL_MAX).
unit_select:
        ld a,(ix+U_TEAM)        ; μόνο του παίκτη: όχι εχθρός, νεκρή,
        or a                    ; ελεύθερη (M8)
        ret nz
        ld hl,sel_n
        ld a,(hl)
        cp SEL_MAX
        ret nc
        inc (hl)
        set F_SEL,(ix+U_FL)
        set F_REDRAW,(ix+U_FL)
        add a,a
        ld l,a
        ld h,0
        ld de,SELLIST
        add hl,de
        push ix
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; RETURN: οι επιλεγμένες στον κέρσορα, σε σχηματισμό 4 στηλών (5 bytes)
; και σειρών (12 γραμμές), με τον κέρσορα στο κέντρο της πρώτης σειράς.
; Πάνω σε πόρο, οι χωρικοί αντί γι' αυτό πάνε να μαζέψουν (gather.asm).
do_command:
        ld a,(bmode)            ; διαλέγεις θέση για κτίριο
        inc a
        jp nz,bld_place
        call cur_world
        ld a,(sel_n)
        or a
        ret z
        ld hl,ord_cmd           ; εχθρός κάτω από τον κέρσορα: επίθεση
        call far7               ; (bank7.asm)· και η κίνηση ως εκεί
        ld hl,(cw_x)            ; το κελί του στόχου, και το flow field του
        ld de,(cw_y)
        call feet_tile
        ld (n_i),hl
        ld (n_j),de
        call res_at             ; πόρος εκεί; (gather.asm)
        ld (cmd_kind),a
        call tile_cell
        ld (cmd_cell),a
        call field_build
        ld a,(mv_n)             ; οι προηγούμενες βγαίνουν από το MOVERS
        or a
        jr z,.m0
        ld b,a
        ld hl,MOVERS
.m:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        pop iy
        res F_MVR,(iy+U_FL)
        djnz .m
.m0:    ld hl,SELLIST           ; όσες πήραν την εντολή: και στο MOVERS
        ld de,MOVERS
        ld a,(sel_n)
        ld (mv_n),a
        add a,a
        ld c,a
        ld b,0
        ldir
        ld hl,SELLIST
        ld c,0                  ; C = πόσες έχουν πάρει θέση
.u:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        pop ix
        ld a,c                  ; TX = cw_x - 2 - 7 + (k AND 3) * 5
        and 3
        ld b,a
        add a,a
        add a,a
        add a,b
        sub 9
        ld hl,(cw_x)
        call add_s8
        ld de,WORLD_W
        call clamp_world
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld a,c                  ; TY = cw_y - 14 + ((k >> 2) AND 7) * 12
        rrca
        rrca
        and 7
        ld b,a
        add a,a
        add a,b
        add a,a
        add a,a
        sub 14
        ld hl,(cw_y)
        call add_s8
        ld de,WORLD_H
        call clamp_world
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        push bc                 ; το κελί του δικού της στόχου
        ld l,(ix+U_TX)
        ld h,(ix+U_TX+1)
        inc hl
        inc hl
        push hl
        ld l,(ix+U_TY)
        ld h,(ix+U_TY+1)
        ld de,14
        add hl,de
        ex de,hl
        pop hl
        call feet_tile
        ld (n_i),hl
        ld (n_j),de
        call tile_cell
        ld (ix+U_OCELL),a
        pop bc
        set F_MOVE,(ix+U_FL)
        res F_WANDER,(ix+U_FL)
        xor a                   ; και στόχος πια (NT)
        call nt_put
        ld a,(field_f)
        ld (ix+U_FIELD),a
        ld a,(cmd_cell)
        ld (ix+U_TCELL),a
        ld (ix+U_STUCK),0
        set F_MVR,(ix+U_FL)
        ld (ix+U_JOB),0         ; πόρος, και είναι χωρικός: δουλειά
        ld a,(cmd_kind)
        inc a
        jr z,.nj
        ld a,(ix+U_SET)         ; χωρικός: σετ 0, ή 3 όταν κουβαλάει
        or a
        jr z,.vil
        cp SET_CARRY
        jr nz,.nj
.vil:
        push bc
        call job_start
        pop bc
.nj:    pop hl
        inc c
        ld a,(sel_n)
        cp c
        jp nz,.u
        ret
