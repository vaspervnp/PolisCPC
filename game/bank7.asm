; bank7.asm — ό,τι τρέχει από την τράπεζα C7 (M8): η μάχη, και το occ_list.
;
; Η C7 έχει τα μεταγλωττισμένα sprites (13,5 KB) και μετά χώρο. Ο κώδικας
; εδώ συναρμολογείται για το C7_CODE, ταξιδεύει στο POLIS.BIN μετά το
; code_end, και στην εκκίνηση (units_gfx) περνάει στην C7 μαζί με τα sprites.
; Καλείται με το far7 (HL = ρουτίνα, units.asm): με την C7 στο #4000.
;
; ΔΕΝ ΒΛΕΠΕΙ τη σελίδα του HUD (κάδοι, PX/PN, πίνακες των χωρικών, ο πίνακας
; NT) ούτε τις C5/C6: αυτά τα κάνει ο κύριος κώδικας, με ό,τι του επιστρέφει
; εδώ (A = η μονάδα που μόλις πέθανε -> died_a: έξω από τον κάδο της).
;
; Η ΜΑΧΗ (M8)
;   Στρατιώτες (σετ 1, 2) που δεν περιπλανιούνται και δεν εκτελούν εντολή του
;   παίκτη κοιτάνε, σε κάθε απόφασή τους (~1 φορά στα 21 καρέ), τον
;   κοντινότερο εχθρό (find_nearest, οι κάδοι του M5). Μέσα στην εμβέλεια:
;   χτυπάνε — η πόζα της επίθεσης, και η ζημιά αμέσως, ή (τοξότες) ένα βέλος.
;   Μέσα στο οπτικό πεδίο (SIGHT): πάνε προς τα εκεί. Η απόφαση είναι και ο
;   ψυχρός χρόνος: ένα χτύπημα ανά απόφαση.
;   Υγεία 0: πόζα θανάτου (3 καρέ), ~4 s πτώμα, και η θέση ελεύθερη.
;   Πόζα = U_FACE bit 7: τότε το U_STEP είναι το ίδιο το καρέ του σετ.
;   Βέλη: ΟΧΙ μονάδες (ένα sprite 8 x 16 που πετάει πάνω από τη συμπλοκή θα
;   ξανάβαζε σε κάθε καρέ να ζωγραφιστούν όσες ακουμπάει). Μια λίστα ARROWS,
;   ζωγραφισμένη με XOR (2 pixels x 2 γραμμές) ΠΑΝΩ από όλα στο τέλος του
;   καρέ μονάδων (proj_on) και σβησμένη, πάλι με XOR, στην αρχή του επόμενου
;   (proj_off), πριν αγγίξει οτιδήποτε την οθόνη. Χτυπάνε όταν φτάσουν.
;   Οι νεκροί κάθε κλήσης μπαίνουν στο dq: ο κύριος κώδικας (died_flush) τους
;   βγάζει από τους κάδους.

C7_HP       equ #7E00           ; 128: η υγεία ανά μονάδα
C7_ANIM     equ #7E80           ; 128: ο μετρητής της πόζας

ARROWS      equ #A5E0           ; PR_N x (x dw, y dw, στόχος (255 κανείς),
PR_N        equ 4               ; ζημιά, sx, sy (255: δεν ζωγραφίστηκε))
SIGHT       equ 120             ; 2 |dx| + |dy|
ATK_T       equ 8               ; καρέ της πόζας επίθεσης (ένα καρέ)
DIE_T       equ 100             ; καρέ από τον θάνατο ώς την ελεύθερη θέση
DIE_1       equ DIE_T - 6       ; το 2ο καρέ θανάτου
DIE_2       equ DIE_T - 12      ; το 3ο (πτώμα)
PROJ_DX     equ 3               ; το βέλος ανά καρέ μονάδων: bytes,
PROJ_DY     equ 6               ; γραμμές

        assert OCC_L + OCC_MAX * 10 <= ARROWS && ARROWS + PR_N * 8 <= ACT_TAB, 'ARROWS'

; ανά σετ (U_SET): υγεία, ζημιά, εμβέλεια (2 |dx| + |dy|), βέλος
stats:      db 25, 3, 14, 0     ; χωρικός
            db 60, 8, 14, 0     ; σπαθοφόρος
            db 35, 6, 80, 1     ; τοξότης
            db 25, 3, 14, 0     ; χωρικός με φορτίο
; ανά όψη (S E N W): τα 2 καρέ της επίθεσης (W: δεν υπάρχουν, του βαδίσματος)
atk_fr:     db 12, 14, 16, 21
            db 13, 15, 17, 23

; IX -> HL = η γραμμή της στο stats
st_hl:  ld a,(ix+U_SET)
        and 3
        add a,a
        add a,a
        ld hl,stats
        jr tab_a

; A = όψη + 0/4 -> A = καρέ επίθεσης
atk_a:  ld hl,atk_fr
tab_a:  add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret

; IX -> HL = &HP[idx] (+128: ANIM)
hp_hl:  ld l,(ix+U_IDX)
        ld h,C7_HP >> 8
        ret

; A = δείκτης -> IY = η εγγραφή του (κρατάει IX)
idx_iy: push ix
        call idx_ix
        push ix
        pop iy
        pop ix
        ret

; Στην εκκίνηση: η υγεία όλων, από το σετ τους.
hp_init:
        ld hl,ARROWS            ; κανένα βέλος
        ld b,PR_N * 8
.a:     ld (hl),255
        inc hl
        djnz .a
        xor a
.l:     push af
        call idx_ix
        call hp_set
        pop af
        inc a
        cp UNITS
        jr nz,.l
        ret

; IX: η υγεία της από το σετ (και bld_spawn).
hp_set: call st_hl
        ld a,(hl)
        call hp_hl
        ld (hl),a
        ret

; IX = στρατιώτης, U_TGT = ο κοντινότερος εχθρός (find_nearest). Όποια
; πέθανε: στο dq.
combat_think:
        bit 7,(ix+U_FACE)       ; πόζα εκτός οθόνης: τελειώνει (δεν την
        jr z,.p0                ; προχωράει κανείς)
        ld a,(ix+U_SY)
        inc a
        call z,pose_end
.p0:    ld a,(ix+U_TGT)
        cp 255
        jr z,.none
        call idx_iy
        bit F_WANDER,(iy+U_FL)
        jr nz,.none
        ld a,(iy+U_TEAM)
        cp 2
        jr nc,.none
        bit F_MOVE,(ix+U_FL)    ; εκτελεί εντολή του παίκτη: όχι
        jr z,.go
        ld a,(ix+U_FIELD)
        or a
        jr nz,.none
.go:    call c_dist             ; HL = 2 |dx| + |dy|
        ld de,SIGHT + 1
        or a
        sbc hl,de
        jr nc,.none
        add hl,de
        push hl
        call st_hl
        inc hl
        inc hl
        ld e,(hl)               ; εμβέλεια
        ld d,0
        pop hl
        or a
        sbc hl,de
        jr c,attack
        jr z,attack
        ld l,(iy+U_WX)          ; κυνήγι: ως 4 bytes από τον στόχο, από την
        ld h,(iy+U_WX+1)        ; πλευρά της
        ld de,4
        ld a,(c_dx + 1)
        bit 7,a
        jr nz,.cr
        ld de,-4
.cr:    add hl,de
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld l,(iy+U_WY)
        ld h,(iy+U_WY+1)
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        ld (ix+U_FIELD),0
        ld (ix+U_STUCK),0
        set F_MOVE,(ix+U_FL)
.none:  ret

; Χτυπάει (IX, IY = ο στόχος, c_dx / c_dy). Όποια πέθανε: στο dq.
attack: res F_MOVE,(ix+U_FL)
        ld hl,(c_dx)            ; όψη: οριζόντια αν 2 |dx| > |dy|
        call abs_hl
        add hl,hl
        push hl
        ld hl,(c_dy)
        call abs_hl
        pop de
        or a
        sbc hl,de
        jr nc,.vert
        ld a,(c_dx + 1)         ; E (1) ή W (3)
        rlca
        and 1
        add a,a
        inc a
        jr .face
.vert:  ld a,(c_dy + 1)         ; S (0) ή N (2)
        rlca
        and 1
        add a,a
.face:  ld c,a
        or #80
        ld (ix+U_FACE),a
        ld a,c
        add a,4                 ; το καρέ του χτυπήματος
        call atk_a
        ld (ix+U_STEP),a
        ld (ix+U_LOOK),255
        call hp_hl
        set 7,l
        ld (hl),ATK_T
        call st_hl
        inc hl
        ld b,(hl)               ; η ζημιά
        inc hl
        inc hl
        ld a,(hl)
        or a
        jr z,.hit
        call proj_new           ; τοξότης: βέλος — ή, χωρίς θέση, αμέσως
        ret nc
.hit:   call hit
        jp dq_add

; IY = ο στόχος, B = ζημιά -> A = ο δείκτης του αν πέθανε, αλλιώς 255.
hit:    ld l,(iy+U_IDX)
        ld h,C7_HP >> 8
        ld a,(hl)
        sub b
        jr c,.dead
        jr z,.dead
        ld (hl),a
        ld a,255
        ret
.dead:  ld (hl),0
        set 7,l
        ld (hl),DIE_T
        ld a,(iy+U_FL)          ; ούτε κίνηση, ούτε επιλογή, ούτε δουλειά
        and 1 << F_ORD
        ld (iy+U_FL),a
        ld (iy+U_JOB),0
        ld (iy+U_FACE),#80      ; πόζα θανάτου
        ld (iy+U_STEP),18
        ld (iy+U_LOOK),255
        ld a,(iy+U_TEAM)
        set 7,(iy+U_TEAM)
        or a
        jr nz,.r
        ld hl,(hud_val + 8)     ; του παίκτη: ο πληθυσμός -1
        dec hl
        ld (hud_val + 8),hl
        ld hl,hud_dirty
        set 4,(hl)
.r:     ld a,(iy+U_IDX)
        ret

; IX = τοξότης, B = ζημιά: ένα βέλος από το στήθος της. Carry αν δεν
; χωράει άλλο.
proj_new:
        ld hl,ARROWS + 4
        ld de,8
        ld c,PR_N
.f:     ld a,(hl)
        inc a
        jr z,.got
        add hl,de
        dec c
        jr nz,.f
        scf
        ret
.got:   ld a,(ix+U_TGT)
        ld (hl),a
        inc hl
        ld (hl),b
        ld de,-5
        add hl,de
        ld a,(ix+U_WX)
        inc a
        ld (hl),a
        inc hl
        ld a,(ix+U_WX+1)
        adc a,0
        ld (hl),a
        inc hl
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        ex de,hl
        ld bc,6
        add hl,bc
        ex de,hl
        ld (hl),e
        inc hl
        ld (hl),d
        or a
        ret

; Στο τέλος του καρέ μονάδων: κάθε βέλος ως PROJ_DX / PROJ_DY προς τον στόχο
; (byte WX + 1, γραμμή WY + 8)· φτάνει: χτυπάει. Αλλιώς, αν φαίνεται, XOR.
proj_on:
        push ix
        ld ix,ARROWS
        ld b,PR_N
.l:     push bc
        ld a,(ix+4)
        cp 255
        call nz,pr_one
        ld de,8
        add ix,de
        pop bc
        djnz .l
        pop ix
        ret

pr_one: call idx_iy
        ld a,(iy+U_TEAM)
        cp 2
        jr nc,.free             ; ο στόχος έπεσε ήδη
        ld l,(iy+U_WX)
        ld h,(iy+U_WX+1)
        inc hl
        ld e,(ix+0)
        ld d,(ix+1)
        or a
        sbc hl,de
        ld d,PROJ_DX
        call clamp_step
        ld c,a
        sub l
        ld b,a                  ; 0: φτάνει στο x
        ld l,(iy+U_WY)
        ld h,(iy+U_WY+1)
        ld de,8
        add hl,de
        ld e,(ix+2)
        ld d,(ix+3)
        or a
        sbc hl,de
        ld d,PROJ_DY
        call clamp_step
        push af
        sub l
        or b
        jr nz,.move
        pop af
        ld b,(ix+5)
        call hit
        call dq_add
.free:  ld (ix+4),255
        ret
.move:  pop af
        ld l,(ix+2)
        ld h,(ix+3)
        call add_s8
        ld (ix+2),l
        ld (ix+3),h
        ld a,c
        ld l,(ix+0)
        ld h,(ix+1)
        call add_s8
        ld (ix+0),l
        ld (ix+1),h
        ld de,(cam_x)           ; φαίνεται; sx 0..79, sy 0..142
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        ld c,l
        ld a,l
        cp 80
        ret nc
        ld l,(ix+2)
        ld h,(ix+3)
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp VIEW_H - 1
        ret nc
        ld (ix+7),a
        ld (ix+6),c

; IX = βέλος: XOR #FF στο byte sx των γραμμών sy, sy + 1.
pr_xor: ld a,(ix+7)
        ld b,(ix+6)
        call line_x
        ld a,(de)
        cpl
        ld (de),a
        ld a,d
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        ld a,(de)
        cpl
        ld (de),a
        ret

; Στην αρχή του καρέ μονάδων: τα βέλη που ζωγραφίστηκαν, σβήνουν (XOR ξανά).
proj_off:
        push ix
        ld ix,ARROWS
        ld b,PR_N
.l:     ld a,(ix+7)
        cp 255
        jr z,.n
        push bc
        call pr_xor
        pop bc
        ld (ix+7),255
.n:     ld de,8
        add ix,de
        djnz .l
        pop ix
        ret

; A = όποια πέθανε (255: καμία) -> στο dq, για το died_flush.
dq_add: cp 255
        ret z
        push hl
        ld hl,dq_n
        ld l,(hl)
        ld h,0
        push de
        ld de,dq
        add hl,de
        pop de
        ld (hl),a
        ld hl,dq_n
        ld a,(hl)
        cp DQ_MAX - 1
        adc a,0
        ld (hl),a
        pop hl
        ret

; Σε κάθε καρέ, για όσες φαίνονται σε πόζα (unit_update). -> C = 2 αν η θέση
; ελευθερώθηκε (unit_hide), αλλιώς 0. Αργό καρέ (πέρα από το T_LATE): η πόζα
; περιμένει — καμία αλλαγή καρέ, άρα καμία επανασχεδίαση.
pose_tick:
        ld a,(t0)
        ld c,a
        ld a,(int_t)
        sub c
        ld c,0
        cp T_LATE
        ret nc
        call hp_hl
        set 7,l
        dec (hl)
        ld a,(hl)
        bit 7,(ix+U_TEAM)
        jr nz,.die
        or a                    ; ΕΠΙΘΕΣΗ: ένα καρέ (το χτύπημα), ώς το τέλος
        jr z,.end
        jr .r
.fr:    ld (ix+U_STEP),a
        ld (ix+U_LOOK),255
.r:     ld a,255
        ret
.end:   call pose_end
        jr .r
.die:   or a                    ; ΘΑΝΑΤΟΣ: 18, 19, 20 (πτώμα), και ελεύθερη
        jr z,.free
        cp DIE_1
        ld a,19
        jr z,.fr
        ld a,(hl)
        cp DIE_2
        ld a,20
        jr z,.fr
        jr .r
.free:  call unit_free
        ld c,2
        jr .r

pose_end:
        ld a,(ix+U_FACE)
        and 3
        ld (ix+U_FACE),a
        ld (ix+U_STEP),0
        ld (ix+U_LOOK),255
        ret

; IX: η θέση ελεύθερη, μακριά από τον κόσμο (όπως οι ελεύθερες του M7).
unit_free:
        ld (ix+U_TEAM),TEAM_FREE
        ld a,(ix+U_FL)
        and 1 << F_ORD
        ld (ix+U_FL),a
        xor a
        ld (ix+U_FACE),a
        ld (ix+U_STEP),a
        ld (ix+U_JOB),a
        ld (ix+U_TGT),255
        ld (ix+U_WY+1),2000 >> 8
        ld (ix+U_TY+1),2000 >> 8
        ret

; Απόφαση νεκρής (IX). Όσο φαίνεται, το pose_tick· εκτός οθόνης αφήνει τη
; θέση αμέσως.
dead_think:
        ld a,(ix+U_SY)
        inc a
        ret nz
        jp unit_free

; IX, IY -> c_dx, c_dy (στόχος - αυτή), HL = 2 |dx| + |dy|.
c_dist: ld l,(iy+U_WX)
        ld h,(iy+U_WX+1)
        ld e,(ix+U_WX)
        ld d,(ix+U_WX+1)
        or a
        sbc hl,de
        ld (c_dx),hl
        call abs_hl
        add hl,hl
        push hl
        ld l,(iy+U_WY)
        ld h,(iy+U_WY+1)
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        or a
        sbc hl,de
        ld (c_dy),hl
        call abs_hl
        pop de
        add hl,de
        ret

; ------------------------------------------------------------ occlude.asm

; Στην αρχή του units_draw: τα έτοιμα κτίρια που φαίνονται -> OCC_L. Μόνο
; όταν κινήθηκε η κάμερα ή άλλαξε κτίριο (occ_dirty: bld_new, ολοκλήρωση).
occ_list:
        ld hl,(cam_x)
        ld de,(occ_cx)
        or a
        sbc hl,de
        jr nz,.go
        ld hl,(cam_y)
        ld de,(occ_cy)
        sbc hl,de
        jr nz,.go
        ld a,(occ_dirty)
        or a
        ret z
.go:    xor a
        ld (occ_dirty),a
        ld hl,(cam_x)
        ld (occ_cx),hl
        ld hl,(cam_y)
        ld (occ_cy),hl
        ld hl,OCC_L
        ld (occ_w),hl
        xor a
        ld (occ_c),a
        ld iy,BLD_TAB
        ld a,(bld_top)
        ld b,a
.l:     push bc
        ld c,255                ; clamp_c: 0..255
        ld a,(iy+B_TYPE)
        inc a
        jp z,.n
        ld a,(iy+B_ST)          ; θεμέλιο: καμία εικόνα
        or a
        jp z,.n
        ld l,(iy+B_WYB)         ; ΓΡΗΓΟΡΑ ΕΞΩ: το κάτω του πάνω από την οθόνη
        ld h,(iy+B_WYB+1)       ; ή ≥ 256 γραμμές κάτω από την κάμερα
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,h
        or a
        jp nz,.n
        ld l,(iy+B_WX)          ; ή αριστερά πέρα από 256, ή δεξιά της
        ld h,(iy+B_WX+1)
        ld de,(cam_x)
        sbc hl,de               ; (carry 0)
        jr c,.xn
        ld a,h
        or a
        jp nz,.n
        ld a,l
        cp 80
        jp nc,.n
.xn:    ld l,(iy+B_WX)          ; x0 = sx - 3 (το SX της μονάδας ≥ x0)
        ld h,(iy+B_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        push hl
        ld de,-3
        add hl,de
        call clamp_c
        ld (occ_q),a
        pop hl                  ; x1 = sx + w (SX < x1)
        ld e,(iy+B_W)
        ld d,0
        add hl,de
        call clamp_c
        ld (occ_q + 1),a
        ld l,(iy+B_WYB)         ; y1 = κάτω - cam_y (SY < y1)
        ld h,(iy+B_WYB+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        push hl
        call clamp_c
        ld (occ_q + 3),a
        pop hl                  ; y0 = y1 - h - 15 (SY ≥ y0)
        ld e,(iy+B_H)
        ld d,0
        or a
        sbc hl,de
        ld de,-15
        add hl,de
        call clamp_c
        ld (occ_q + 2),a
        cp VIEW_H - 16 + 1      ; καμία μονάδα δεν το φτάνει: όχι στη λίστα
        jr nc,.n
        ld a,(occ_q)
        cp 77
        jr nc,.n
        ld a,(occ_q + 1)
        or a
        jr z,.n
        ld a,(occ_q + 3)
        or a
        jr z,.n
        ld a,(iy+B_TYPE)        ; πίσω του: i <= i1 = i0 + n - 1 και j <= j1,
        call bt_hl              ; δηλαδή (πόδια fx, fy) 2 fx + fy < 8 i1 + 391
        ld a,(hl)               ; και fy - 2 fx + 1024 < 8 j1 + 649
        dec a
        ld c,a
        ld a,(iy+B_I)
        call .k
        ld de,391
        add hl,de
        ld (occ_q + 4),hl
        ld a,(iy+B_J)
        call .k
        ld de,649
        add hl,de
        ld (occ_q + 6),hl
        ld hl,occ_q
        ld de,(occ_w)
        ld bc,8
        ldir
        ld a,iyl
        ld (de),a
        inc de
        ld a,iyh
        ld (de),a
        inc de
        ld (occ_w),de
        ld hl,occ_c
        inc (hl)
        ld a,(hl)
        cp OCC_MAX
        jr nc,.full
.n:     call bnext
        pop bc
        dec b
        jp nz,.l
        ret
.full:  pop bc
        ret
.k:     add a,c                 ; HL = 8 (A + C)
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ret

