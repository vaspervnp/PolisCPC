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
;
; ΕΝΤΟΛΗ ΕΠΙΘΕΣΗΣ (τα ανοιχτά του M8)
;   RETURN πάνω σε εχθρό: όσες είναι επιλεγμένες (και οι χωρικοί) τον έχουν
;   στόχο (C7_ORD), χωρίς όριο οπτικού πεδίου, ως να πέσει (ord_cmd). Κάθε
;   άλλη εντολή το σβήνει. Ο ΧΩΡΙΚΟΣ ΠΟΥ ΧΤΥΠΙΕΤΑΙ, χωρίς τέτοιο στόχο, τον
;   παίρνει: αφήνει τη δουλειά του και απαντάει (hit).

C7_HP       equ #7E00           ; 128: η υγεία ανά μονάδα
C7_ANIM     equ #7E80           ; 128: ο μετρητής της πόζας
C7_ORD      equ #7F00           ; 128: ο στόχος της εντολής (255 κανένας)

ARROWS      equ #A5E0           ; PR_N x (x dw, y dw, στόχος (255 κανείς),
PR_N        equ 4               ; ο τοξότης, sx, sy (255: δεν ζωγραφίστηκε))
SIGHT       equ 120             ; 2 |dx| + |dy|
ATK_T       equ 8               ; καρέ της πόζας επίθεσης (ένα καρέ)
DIE_T       equ 100             ; καρέ από τον θάνατο ώς την ελεύθερη θέση
DIE_1       equ DIE_T - 6       ; το 2ο καρέ θανάτου
DIE_2       equ DIE_T - 12      ; το 3ο (πτώμα)
PROJ_DX     equ 3               ; το βέλος ανά καρέ μονάδων: bytes,
PROJ_DY     equ 6               ; γραμμές

        assert OCC_L + OCC_MAX * 10 <= ARROWS && ARROWS + PR_N * 8 <= ACT_TAB, 'ARROWS'

; ανά ομάδα (0, 1) και σετ (U_SET): υγεία, ζημιά, εμβέλεια (2 |dx| + |dy|),
; βέλος. Οι τεχνολογίες (M9) αλλάζουν τα της ομάδας 0.
stats:      db 25, 3, 14, 0     ; χωρικός
            db 60, 8, 14, 0     ; σπαθοφόρος
            db 35, 6, 80, 1     ; τοξότης
            db 25, 3, 14, 0     ; χωρικός με φορτίο
            db 90, 10, 14, 0    ; οπλίτης (M9)
            db 25, 3, 14, 0     ; (ομάδα 1)
            db 60, 8, 14, 0
            db 35, 6, 80, 1
            db 25, 3, 14, 0
            db 90, 10, 14, 0
ST_SETS     equ 5
; Το καρέ του χτυπήματος: S E N = 13, 15, 17 του σετ· το W (το 15
; καθρεφτισμένο) στη θέση του 12 (src/make_edges.py).
ATK_W       equ 12

; IX -> HL = η γραμμή της στο stats (της ομάδας της)
st_hl:  push bc
        ld a,(ix+U_TEAM)
        and 1
        ld c,a
        add a,a
        add a,a
        add a,c                 ; x ST_SETS
        pop bc
        add a,(ix+U_SET)
        add a,a
        add a,a
        ld hl,stats
        jr tab_a

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

; Στην εκκίνηση: η υγεία όλων, από το σετ τους· καμία εντολή επίθεσης.
hp_init:
        ld hl,ARROWS            ; κανένα βέλος
        ld b,PR_N * 8
.a:     ld (hl),255
        inc hl
        djnz .a
        ld hl,C7_ORD
        ld b,UNITS
.o:     ld (hl),255
        inc hl
        djnz .o
        ld hl,RES_B             ; καμία έρευνα (M9)
        ld b,BLD_MAX
.r:     ld (hl),255
        inc hl
        djnz .r
        ld hl,BDMG              ; καμία ζημιά στα κτίρια (M10)
        ld b,BLD_MAX * 2
.z:     ld (hl),0
        inc hl
        djnz .z
        ld hl,bcopy_src         ; η αντιγραφή C6 -> C5 στο #0008 (rst 8)
        ld de,#0008
        ld bc,BCOPY_LEN
        ldir
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

; IX -> HL = &C7_ORD[idx], A = ο στόχος της εντολής (255 κανένας).
ord_get:
        ld l,(ix+U_IDX)
        ld h,C7_ORD >> 8
        ld a,(hl)
        ret

; IX = στρατιώτης, U_TGT = ο κοντινότερος εχθρός (find_nearest) — ή
; οποιαδήποτε με εντολή επίθεσης (C7_ORD). Όποια πέθανε: στο dq.
combat_think:
        bit 7,(ix+U_FACE)       ; πόζα εκτός οθόνης: τελειώνει (δεν την
        jr z,.p0                ; προχωράει κανείς)
        ld a,(ix+U_SY)
        inc a
        call z,pose_end
.p0:    call ord_get            ; ΕΝΤΟΛΗ: αυτός, όπου κι αν είναι, ώσπου
        cp 255                  ; να πέσει
        jr z,.auto
        bit 7,a                 ; ή κτίριο (M10)
        jp nz,bord
        ld (ix+U_TGT),a
        call idx_iy
        ld a,(iy+U_TEAM)
        cp 2
        jr nc,.end
        cp (ix+U_TEAM)          ; (ποτέ της ίδιας ομάδας)
        jr nz,.ord
.end:   ld (hl),255             ; έπεσε: η εντολή τελείωσε
        ret
.ord:   call c_dist
        jr .in
.auto:  ld a,(ix+U_TGT)
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
.in:    push hl
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
        bit F_MOVE,(ix+U_FL)    ; με εντολή του παίκτη ακόμα στον δρόμο της
        jr z,.ch                ; (flow field ως τον στόχο) και μακριά (πέρα
        ld a,(ix+U_FIELD)       ; από το SIGHT): τον ακολουθεί
        or a
        jr z,.ch
        add hl,de
        ld de,SIGHT + 1
        sbc hl,de               ; (carry 0: το add δεν ξεχείλισε)
        ret nc
.ch:    ld l,(iy+U_WX)          ; κυνήγι: ως 4 bytes από τον στόχο, από την
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
attack: call atk_pose
        call st_hl
        inc hl
        ld b,(hl)               ; η ζημιά
        inc hl
        inc hl
        ld a,(hl)
        ld c,(ix+U_IDX)         ; ποιος χτυπάει
        or a
        jr z,.hit
        call proj_new           ; τοξότης: βέλος — ή, χωρίς θέση, αμέσως
        ret nc
.hit:   call hit
        jp dq_add

; Η πόζα του χτυπήματος, με όψη προς το c_dx / c_dy.
atk_pose:
        res F_MOVE,(ix+U_FL)
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
        ld a,c                  ; το καρέ του χτυπήματος: 13 + 2 x όψη, ή
        cp 3                    ; το W (ATK_W)
        ld a,ATK_W
        jr z,.st
        ld a,c
        add a,a
        add a,13
.st:    ld (ix+U_STEP),a
        ld (ix+U_LOOK),255
        call hp_hl
        set 7,l
        ld (hl),ATK_T
        ret

; IY = ο στόχος, B = ζημιά, C = ποιος χτυπάει -> A = ο δείκτης του στόχου
; αν πέθανε, αλλιώς 255. Χωρικός χωρίς εντολή επίθεσης: απαντάει (C7_ORD).
hit:    ld l,(iy+U_IDX)
        ld h,C7_HP >> 8
        ld a,(hl)
        sub b
        jr c,.dead
        jr z,.dead
        ld (hl),a
        ld a,(iy+U_SET)         ; χωρικός: σετ 0 ή 3
        or a
        jr z,.v
        cp 3
        jr nz,.n
.v:     ld h,C7_ORD >> 8
        ld a,(hl)
        inc a
        jr nz,.n
        ld (hl),c
        ld (iy+U_JOB),0         ; αφήνει τη δουλειά
.n:     ld a,255
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

; IX = τοξότης: ένα βέλος από το στήθος της. Carry αν δεν χωράει άλλο.
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
        ld a,(ix+U_IDX)         ; ο τοξότης (το C είναι ο μετρητής)
        ld (hl),a
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
        ld c,(ix+5)             ; ο τοξότης, και η ζημιά του σετ του
        push ix
        ld a,c
        call idx_ix
        call st_hl
        inc hl
        ld b,(hl)
        pop ix
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
        call ord_get
        ld (hl),255
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

; RETURN (do_command, πριν την κίνηση): ο εχθρός κάτω από τον κέρσορα (όπως
; το κλικ: από τη μπροστινή του ORDER προς τα πίσω, ζωντανός, ομάδα 1)
; γίνεται ο στόχος όσων είναι επιλεγμένες — αλλιώς καμία εντολή επίθεσης.
ord_cmd:
        ld c,255
        ld a,(ord_n)
        or a
        jr z,.bld
        ld b,a
        add a,a
        ld l,a
        ld h,ORDER >> 8
        ld a,ORDER & 255
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
.l:     dec hl
        ld d,(hl)
        dec hl
        ld e,(hl)
        push de
        pop iy
        ld a,(iy+U_TEAM)
        dec a
        jr nz,.n
        bit F_WANDER,(iy+U_FL)  ; οι ουδέτερες που περιπλανιούνται: όχι
        jr nz,.n
        ld a,(cur_x)
        sub (iy+U_SX)
        cp 4
        jr nc,.n
        ld a,(cur_y)
        sub (iy+U_SY)
        cp 16
        jr nc,.n
        ld c,(iy+U_IDX)
        jr .set
.n:     djnz .l
.bld:   ld a,(sel_bld)          ; κτίριο του αντιπάλου κάτω από τον κέρσορα
        push af                 ; (M10): 128 + η θέση του
        call bld_pick
        ld a,(sel_bld)
        ld c,a
        pop af
        ld (sel_bld),a
        ld a,c
        inc a
        jr z,.set
        dec a
        call brec_iy
        ld a,(iy+B_OWN)
        or a
        ld a,c
        ld c,255
        jr z,.set
        or 128
        ld c,a
.set:   ld a,(sel_n)
        or a
        ret z
        ld b,a
        ld hl,SELLIST
.s:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push de
        pop iy
        ld e,(iy+U_IDX)
        ld d,C7_ORD >> 8
        ld a,c
        ld (de),a
        djnz .s
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


; ============================================================ ΕΡΕΥΝΑ (M9)
;
; U με κτίριο επιλεγμένο (έτοιμο, του παίκτη, χωρίς έρευνα): η ΠΡΩΤΗ
; τεχνολογία του τύπου του που δεν έχει γίνει, επιτρέπεται στην εποχή, έχει
; το προαπαιτούμενό της και πληρώνεται (res_start). Η πρόοδος ανά θέση
; κτιρίου (RES_B: ποια, RES_P: πόσα βήματα των 8 καρέ), στη μπάρα της
; κάρτας (res_card). Στο τέλος (res_tick) το αποτέλεσμα:
;   RK_AGE    η Εποχή του Χαλκού: age_req = 1, και ο κύριος κώδικας
;             φορτώνει το AGE3.BIN (disk.asm) και καλεί το age_apply
;   RK_STAT   + b στο stats της ομάδας 0 (θέση a = σετ x 4 + πεδίο)· στην
;             υγεία και σε όσες ζουν ήδη· στο σετ 0 και στο 3 (με φορτίο)
;   RK_CARRY  + b στο carry_max[a] (gather.asm): πόσο κουβαλάει ο χωρικός

RES_B       equ #7F80           ; 28: η τεχνολογία που ερευνάται (255 καμία)
RES_P       equ #7FA0           ; 28: η πρόοδος (βήματα των 8 καρέ)
RK_AGE      equ 0
RK_STAT     equ 1
RK_CARRY    equ 2
T_SIZE      equ 15

; κτίριο, εποχή, προαπαιτούμενο, κόστος (τροφή, ξύλο, χρυσό, πέτρα: dw),
; χρόνος (x 8 καρέ), είδος, a, b
        macro TECH bt, age, pre, f, w, g, s, t, k, a, b
        db {bt}, {age}, {pre}
        dw {f}, {w}, {g}, {s}
        db {t}, {k}, {a}, {b}
        mend
techs:  TECH BTY_TOWN_CENTER, 2, 255, 800, 0, 0, 0, 150, RK_AGE, 3, 0   ; Εποχή του Χαλκού
        TECH BTY_GRANARY, 2, 255, 200, 50, 0, 0, 50, RK_CARRY, 0, 5     ; Εξημέρωση: τροφή
        TECH BTY_MARKET, 2, 255, 120, 75, 0, 0, 50, RK_CARRY, 1, 5      ; Ξυλουργική: ξύλο
        TECH BTY_MARKET, 2, 255, 100, 120, 0, 0, 50, RK_CARRY, 2, 5     ; Χρυσωρυχείο: χρυσό
        TECH BTY_MARKET, 2, 255, 100, 0, 0, 50, 50, RK_CARRY, 3, 5      ; Λιθοξοΐα: πέτρα
        TECH BTY_STORAGE_PIT, 2, 255, 100, 0, 0, 0, 40, RK_STAT, 5, 2   ; Εργαλειοποιία: σπαθί +2
        TECH BTY_STORAGE_PIT, 2, 255, 75, 0, 0, 0, 40, RK_STAT, 4, 10   ; Δερμάτινη θωράκιση: +10
        TECH BTY_STORAGE_PIT, 3, 5, 200, 0, 120, 0, 60, RK_STAT, 5, 3   ; Μεταλλουργία: σπαθί +3
        TECH BTY_STORAGE_PIT, 3, 6, 100, 0, 50, 0, 60, RK_STAT, 4, 15   ; Θώρακας φολίδων: +15
        TECH BTY_ARCHERY, 2, 255, 100, 50, 0, 0, 40, RK_STAT, 9, 2      ; Τοξοβολία: τόξο +2
        TECH BTY_ARCHERY, 3, 9, 0, 180, 100, 0, 60, RK_STAT, 10, 16     ; Σύνθετο τόξο: βεληνεκές
        TECH BTY_TEMPLE, 3, 255, 120, 0, 60, 0, 50, RK_STAT, 0, 10      ; Ιατρική: χωρικός +10
        TECH BTY_ACADEMY, 3, 255, 150, 0, 100, 0, 60, RK_STAT, 16, 20   ; Φάλαγγα: οπλίτης +20
        TECH BTY_TOWN_CENTER, 3, 0, 1000, 0, 800, 0, 200, RK_AGE, 4, 0  ; Εποχή του Σιδήρου
T_N         equ ($ - techs) / T_SIZE
res_done:   dw 0                ; bit t: έγινε

; A = θέση κτιρίου -> HL = &RES_B[A]
res_hl: ld l,a
        ld h,RES_B >> 8
        ld a,RES_B & 255
        add a,l
        ld l,a
        ret

; A = τεχνολογία -> HL = η γραμμή της
tech_hl:
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl               ; x 15 = x 16 - 1
        add hl,hl
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        ld de,techs
        add hl,de
        ret

; A = τεχνολογία -> NZ αν έγινε
done_a: ld hl,(res_done)
        inc a
.s:     dec a
        jr z,.t
        srl h
        rr l
        jr .s
.t:     ld a,l
        and 1
        ret

; U: έρευνα στο επιλεγμένο κτίριο.
res_start:
        ld a,(sel_bld)
        cp 255
        ret z
        call brec_iy
        ld a,(iy+B_ST)          ; έτοιμο, του παίκτη
        or a
        ret z
        ld a,(iy+B_OWN)
        or a
        ret nz
        ld a,(sel_bld)
        call res_hl
        ld a,(hl)
        inc a
        ret nz                  ; ερευνά ήδη
        ld c,0
.t:     push bc
        ld a,c
        call tech_hl
        ld a,(iy+B_TYPE)
        cp (hl)
        jr nz,.n
        inc hl
        ld a,(hud_val + 10)     ; η εποχή
        cp (hl)
        jr c,.n
        inc hl
        ld a,(hl)               ; το προαπαιτούμενο
        cp 255
        jr z,.p
        push hl
        call done_a
        pop hl
        jr z,.n
.p:     ld a,c
        push hl
        call done_a
        pop hl
        jr nz,.n
        inc hl                  ; το κόστος
        call pay16
        jr c,.n
        pop bc
        ld a,(sel_bld)
        call res_hl
        ld (hl),c
        ld a,l
        add a,RES_P - RES_B
        ld l,a
        ld (hl),0
        ld hl,res_n
        inc (hl)
        ret
.n:     pop bc
        inc c
        ld a,c
        cp T_N
        jr nz,.t
        ret

; HL = 4 x dw κόστος: αν τα έχεις, πληρώνει (και η μπάρα). Carry αν όχι.
pay16:  push hl
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
        pop hl
        ld de,hud_val
        ld bc,#0401             ; C = το bit του αριθμού στη μπάρα
.d:     ld a,(hl)
        inc hl
        or (hl)
        jr z,.e
        ld a,(hud_dirty)
        or c
        ld (hud_dirty),a
.e:     dec hl
        ld a,(de)
        sub (hl)
        ld (de),a
        inc de
        inc hl
        ld a,(de)
        sbc a,(hl)
        ld (de),a
        inc de
        inc hl
        sla c
        djnz .d
        or a
        ret
.no:    pop hl
        scf
        ret

; Σε κάθε καρέ μονάδων, όσο res_n > 0: ένα βήμα κάθε 8 καρέ.
res_tick:
        ld a,(ticks)
        and 14                  ; (τα καρέ μονάδων είναι τα ζυγά ticks)
        ret nz
        push ix
        ld b,BLD_MAX
        ld hl,RES_B
.l:     ld a,(hl)
        cp 255
        jr z,.n
        push bc
        push hl
        ld c,a
        ld a,l
        add a,RES_P - RES_B
        ld l,a
        inc (hl)
        ld b,(hl)               ; B = πρόοδος
        ld a,c
        call tech_hl
        ld de,11                ; ο χρόνος
        add hl,de
        ld a,b
        cp (hl)
        pop hl
        push hl
        call nc,res_end
        pop hl
        pop bc
.n:     inc l
        djnz .l
        pop ix
        ret

; HL = &RES_B[θέση]: η τεχνολογία τελείωσε.
res_end:
        ld a,(hl)
        ld (hl),255
        ld hl,res_n
        dec (hl)
        push af
        ld c,a                  ; έγινε: bit c
        ld hl,1
        inc c
.b:     dec c
        jr z,.bs
        add hl,hl
        jr .b
.bs:    ld de,(res_done)
        ld a,l
        or e
        ld l,a
        ld a,h
        or d
        ld h,a
        ld (res_done),hl
        pop af
        call tech_hl
        ld de,12
        add hl,de
        ld a,(hl)               ; είδος
        inc hl
        ld c,(hl)               ; a
        inc hl
        ld b,(hl)               ; b
        cp RK_STAT
        jr z,.stat
        jr c,.age
        ld hl,carry_max         ; RK_CARRY (στην ίδια σελίδα: main.asm)
        ld a,l
        add a,c
        ld l,a
        ld a,(hl)
        add a,b
        ld (hl),a
        ret
.age:   ld a,c                  ; η νέα εποχή (3, 4)
        ld (age_req),a
        ret
.stat:  ld a,c                  ; stats[c] += b, και στο σετ 3 αν είναι σετ 0
        call .add
        ld a,c
        cp 4
        ret nc
        add a,12
.add:   ld hl,stats
        push af
        call tab_a              ; (HL = &stats[A])
        ld a,(hl)
        add a,b
        ld (hl),a
        pop af
        ld e,a
        and 3                   ; υγεία: και όσες ζουν, της ομάδας 0
        ret nz
        ld a,e
        rrca
        rrca
        ld e,a                  ; το σετ
        xor a
.u:     push af
        call idx_ix
        ld a,(ix+U_TEAM)
        or a
        jr nz,.un
        ld a,(ix+U_SET)
        cp e
        jr nz,.un
        call hp_hl
        ld a,(hl)
        add a,b
        ld (hl),a
.un:    pop af
        inc a
        cp UNITS
        jr nz,.u
        ret

; Το επιλεγμένο κτίριο -> A = τα pixels (0..12) της έρευνάς του, ή 255.
; (Όχι από το A: το far7 το χαλάει.)
res_card:
        ld a,(sel_bld)
        call res_hl
        ld a,(hl)
        cp 255
        ret z
        push hl
        call tech_hl
        ld de,11
        add hl,de
        ld e,(hl)               ; ο χρόνος
        ld d,0
        pop hl
        ld a,l
        add a,RES_P - RES_B
        ld l,a
        ld l,(hl)               ; πρόοδος x 12 / χρόνος
        ld h,d
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        add hl,hl
        add hl,hl
        ld b,-1
.d:     inc b
        or a
        sbc hl,de
        jr nc,.d
        ld a,b
        ret

; Μετά το φόρτωμα του AGE3.BIN / AGE4.BIN (disk.asm): η επόμενη εποχή —
; ύψος και εικόνα κάθε τύπου (age3_tab, age4_tab) στο bld_types και σε
; κάθε κτίριο, η μπάρα, ποιοι τύποι άλλαξαν εικόνα (age_chg), και αυτά
; τα κτίρια ξαναζωγραφίζονται ένα-ένα (age_q, buildings.asm).
age_apply:
        ld hl,hud_val + 10
        inc (hl)                ; η νέα εποχή
        ld a,(hl)
        ld de,age3_tab
        cp 3
        jr z,.g
        ld de,age4_tab
.g:     ld hl,0
        ld (age_chg),hl
        ld hl,bld_types + BT_H
        ld b,BT_N
.t:     ld a,(de)               ; ύψος
        ld (hl),a
        inc de
        push bc
        ld bc,BT_IMG - BT_H
        add hl,bc
        ld a,(de)
        ld (hl),a
        inc hl
        inc de
        ld a,(de)
        ld (hl),a
        inc de
        ld a,(de)               ; άλλαξε: bit (BT_N - B) του age_chg
        inc de
        push hl
        ld hl,(age_chg)
        rra
        rr h
        rr l
        ld (age_chg),hl
        pop hl
        ld bc,BT_SIZE - BT_IMG - 1 + BT_H
        add hl,bc
        pop bc
        djnz .t
        ld hl,(age_chg)         ; (μπήκαν από πάνω: στη θέση τους)
        ld b,16 - BT_N
.sh:    srl h
        rr l
        djnz .sh
        ld (age_chg),hl
        xor a
.b:     push af
        call brec_iy
        ld a,(iy+B_TYPE)
        cp 255
        jr z,.n
        call bt_hl
        ld de,BT_H
        add hl,de
        ld a,(hl)
        ld (iy+B_H),a
        ld de,BT_IMG - BT_H
        add hl,de
        ld a,(hl)
        ld (iy+B_IMG),a
        inc hl
        ld a,(hl)
        ld (iy+B_IMG+1),a
.n:     pop af
        inc a
        cp BLD_MAX
        jr nz,.b
        ld hl,hud_dirty
        set 5,(hl)
        ld a,1
        ld (occ_dirty),a
        xor a
        ld (age_q),a
        ret

        include "../data/age3.asm"      ; ανά τύπο ύψος, εικόνα (Χαλκού)

; ============================================================ ΤΟ ΔΕΜΑ (M9)
;
; Ο χωρικός με φορτίο (σετ 3) δεν έχει δικά του καρέ (η θέση της C5 πήγε
; στον οπλίτη): είναι ο χωρικός, και από πάνω, μετά τη σχεδίαση, οι 2
; γραμμές του δέματος (`-yyyy-` / `-DDDD-`: τα bytes 1 και 2, αδιαφανή) στη
; γραμμή ctop του καρέ (src/make_edges.py). Από το units_draw (far7s).
        include "../data/ctop.asm"

carry_ov:
        bit 7,(ix+U_TEAM)       ; πεθαίνει: χωρίς δέμα
        ret nz
        ld a,(ix+U_STEP)        ; το καρέ: πόζα = U_STEP, αλλιώς όψη x 4 +
        bit 7,(ix+U_FACE)       ; βήμα (W: 21 + βήμα)
        jr nz,.f
        rrca
        and 3
        ld c,a
        ld a,(ix+U_FACE)
        cp 3
        ld a,21
        jr z,.w
        ld a,(ix+U_FACE)
        add a,a
        add a,a
.w:     add a,c
.f:     ld hl,ctop
        call tab_a
        add a,(ix+U_SY)
        ld b,(ix+U_SX)
        inc b
        call line_x
        ld a,BUN0
        call .row
        ld a,d                  ; η επόμενη γραμμή
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        ld a,BUN1
.row:   push de
        ld (de),a
        inc e
        call z,de_carry
        ld (de),a
        pop de
        ret

; Η αντιγραφή C6 -> C5 (age_load, buildings.asm): στο #0008, που φαίνεται
; με κάθε τράπεζα (το hp_init την αντιγράφει εκεί). HL -> DE, BC bytes,
; ένα byte τη φορά (~12 µs). Γυρίζει με την C0.
bcopy_src:
        push bc
        ld bc,#7FC6
        out (c),c
        ld a,(hl)
        ld c,#C5
        out (c),c
        ld (de),a
        inc hl
        inc de
        pop bc
        dec bc
        ld a,b
        or c
        jr nz,bcopy_src
        ld bc,#7FC0
        out (c),c
        ret
BCOPY_LEN   equ $ - bcopy_src
        assert BCOPY_LEN <= #20, 'bcopy past #0028'

; ============================================================ ΚΤΙΡΙΑ ΣΤΗ ΜΑΧΗ (M10)
;
; Εντολή επίθεσης σε κτίριο: C7_ORD = 128 + η θέση του (ord_cmd, ή ο
; αντίπαλος). Ο στρατιώτης προτιμά έναν εχθρό μέσα στο οπτικό πεδίο· αλλιώς
; πάει στο ελεύθερο πλακίδιο γύρω από το κτίριο, και από απόσταση 1 (τόξο:
; BOW_T πλακίδια) χτυπάει: η ζημιά του στο BDMG του κτιρίου. Με όση υγεία
; έχει ο τύπος (bld_hp x 4): κατεδαφίζεται (bld_kill).

BDMG        equ RES_P + BLD_MAX + 4 ; 28 x dw: η ζημιά ανά θέση κτιρίου
        assert BDMG + BLD_MAX * 2 <= #8000, 'BDMG'
BOW_T       equ 5

; υγεία / 4 ανά τύπο
bld_hp:     db 150, 40, 75, 60, 60, 75, 75, 75, 25, 75, 75, 100, 100
        assert $ - bld_hp == BT_N, 'bld_hp'

; IX, A = η εντολή (bit 7), HL = &C7_ORD.
bord:   and 127
        push hl
        call brec_iy
        pop hl
        ld a,(iy+B_TYPE)        ; δεν υπάρχει πια, ή είναι δικό του
        inc a
        jr z,.end
        ld a,(iy+B_OWN)
        cp (ix+U_TEAM)
        jr nz,.ok
.end:   ld (hl),255
        ret
.ok:    ld a,(ix+U_SET)         ; στρατιώτης: ο κοντινότερος εχθρός πρώτα
        or a
        jr z,bld_fight
        cp 3
        jr z,bld_fight
        ld a,(ix+U_TGT)
        cp 255
        jr z,bld_fight
        push iy
        call idx_iy
        bit F_WANDER,(iy+U_FL)
        jr nz,.nb
        ld a,(iy+U_TEAM)
        cp 2
        jr nc,.nb
        call c_dist
        ld de,SIGHT + 1
        or a
        sbc hl,de
        jr nc,.nb
        add hl,de
        pop de
        jp combat_think.in
.nb:    pop iy

; IX, IY = κτίριο του εχθρού: κοντά, χτύπα· αλλιώς πήγαινε.
bld_fight:
        call unit_sp
        ld a,(iy+B_TYPE)
        call bt_hl
        ld c,(hl)               ; n
        ld a,(sp_ui)            ; η απόσταση (Chebyshev) από την κάτοψη
        ld b,(iy+B_I)
        call .d1
        ld e,a
        ld a,(sp_uj)
        ld b,(iy+B_J)
        call .d1
        cp e
        jr nc,.m
        ld a,e
.m:     ld e,a
        call st_hl              ; ως 1, ή BOW_T με τόξο
        inc hl
        inc hl
        inc hl
        ld a,(hl)
        or a
        ld a,1
        jr z,.r
        ld a,BOW_T
.r:     cp e
        jp nc,bld_hit
        bit F_MOVE,(ix+U_FL)
        jr z,.go
        ld a,(ix+U_TEAM)        ; του παίκτη, και περπατάει ίσια: μήπως
        or a                    ; ετοιμάστηκε το πεδίο της εντολής του;
        ret nz
        ld a,(ix+U_FIELD)
        cp FIELD_WALK
        ret nz
        call fld_of
        ret z
        ld (ix+U_FIELD),a
        ret
.go:    ld a,(ix+U_TEAM)        ; ο αντίπαλος: πρώτα τα σημεία της
        dec a                   ; διαδρομής (ai_route), με δείκτη το U_TCELL
        jr nz,.ring
.wp:    ld a,(ix+U_TCELL)
        cp AI_ROUTE_N
        jr nc,.ring
        add a,a
        ld hl,ai_route
        call tab_a
        ld d,a
        inc hl
        ld e,(hl)
        ld a,(sp_ui)            ; ως 2 πλακίδια: το επόμενο
        sub d
        call abs_a
        cp 3
        jr nc,.to
        ld a,(sp_uj)
        sub e
        call abs_a
        cp 3
        jr nc,.to
        inc (ix+U_TCELL)
        jr .wp
.to:    call tile_target
        jr .fw
.ring:  call bld_ring
        ret c
        call tile_target
        call fld_of
        jr nz,.f
.fw:    ld a,FIELD_WALK
.f:     ld (ix+U_FIELD),a
        ld (ix+U_WF),0
        ld (ix+U_STUCK),0
        set F_MOVE,(ix+U_FL)
        ret
.d1:    sub b                   ; A = u, B = i0, C = n -> max(0, i0 - u,
        jr c,.lo                ; u - (i0 + n - 1))
        inc a
        sub c
        ret nc
        xor a
        ret
.lo:    neg
        ret

; Τα κύματα του αντιπάλου: από τη βάση του νότια ως τη σειρά j = 44 (όλη
; ανοιχτή), δυτικά ως το i = 44, νότια ως το j = 56, και από εκεί ίσια στο
; κτίριο. (Με flow field έμπαιναν σε κοιλώματα του δάσους όπου η ακολούθηση
; τοίχου έκανε κύκλους· και θα έπαιρναν τα πεδία των εντολών του παίκτη.)
ai_route:   db 57, 44,  44, 44,  44, 56
AI_ROUTE_N  equ ($ - ai_route) / 2

; IX -> A = το flow field (1, 2) που πάει στο U_TCELL της (NZ), ή Z.
fld_of: ld a,(field_tc)
        cp (ix+U_TCELL)
        ld a,1
        jr z,.y
        ld a,(field_tc + 1)
        cp (ix+U_TCELL)
        ld a,2
        jr z,.y
        xor a
        ret
.y:     or a
        ret

; IX χτυπάει το κτίριο IY: η πόζα (όψη προς το κέντρο του) και η ζημιά.
bld_hit:
        ld a,(iy+B_TYPE)
        call bt_hl
        ld a,(hl)
        dec a
        srl a
        ld c,a
        ld a,(iy+B_I)
        add a,c
        ld d,a
        ld a,(iy+B_J)
        add a,c
        ld e,a
        call tile_xy
        ld c,(ix+U_WX)
        ld b,(ix+U_WX+1)
        or a
        sbc hl,bc
        ld (c_dx),hl
        ex de,hl
        ld c,(ix+U_WY)
        ld b,(ix+U_WY+1)
        or a
        sbc hl,bc
        ld (c_dy),hl
        call atk_pose
        call st_hl
        inc hl
        ld c,(hl)               ; η ζημιά
        call bidx
        add a,a
        add a,BDMG & 255
        ld l,a
        ld h,BDMG >> 8
        ld a,(hl)
        add a,c
        ld (hl),a
        ld e,a
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        ld d,a
        ld a,(iy+B_TYPE)        ; η υγεία του τύπου x 4
        ld hl,bld_hp
        call tab_a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        or a
        sbc hl,de
        jr z,bld_kill
        ret nc

; IY = κτίριο: κατεδαφίζεται. Οι στήλες του ξαναζωγραφίζονται (bld_redraw,
; με την C0), η κάτοψη γίνεται έδαφος (το χώμα του θεμελίου μένει), και ό,τι
; είχε (ουρά, έρευνα, επιλογή, ζημιά) σβήνει.
bld_kill:
        push iy
        ld hl,bld_redraw
        call call0
        pop iy
        ld a,(iy+B_TYPE)
        call bt_hl
        ld a,(hl)
        ld c,a                  ; C = n
        ld b,a
        ld e,(iy+B_J)
.r:     push bc
        ld d,(iy+B_I)
        push de
        call map_ptr
        pop de
        pop bc
        push bc
        ld b,c
.t:     ld a,(hl)
        and #F0
        ld (hl),a
        inc hl
        djnz .t
        pop bc
        inc e
        djnz .r
        ld (iy+B_TYPE),255
        ld a,1
        ld (occ_dirty),a
        ld a,(bq_tot)
        sub (iy+B_QN)
        ld (bq_tot),a
        ld (iy+B_QN),0
        call bidx
        ld c,a
        add a,a
        add a,BDMG & 255
        ld l,a
        ld h,BDMG >> 8
        xor a
        ld (hl),a
        inc hl
        ld (hl),a
        ld a,c
        call res_hl
        ld a,(hl)
        inc a
        jr z,.nr
        ld (hl),255
        ld hl,res_n
        dec (hl)
.nr:    ld a,(sel_bld)
        cp c
        ret nz
        ld a,255
        ld (sel_bld),a
        ret

; ============================================================ Ο ΑΝΤΙΠΑΛΟΣ (M10)
;
; Μηχανή καταστάσεων με σενάριο: χωρικοί -> τροφή (και ξύλο, χρυσός) ->
; σπίτια -> στρατώνας -> επίθεση σε κύματα. Σκέφτεται ΜΙΑ φορά το
; δευτερόλεπτο (AI_PER = 25 καρέ μονάδων), μοιρασμένα σε καρέ: 1-2 οι
; μονάδες (μισές στο καθένα), 3 τα κτίρια, 4 νίκη / ήττα, 5 οικονομία, 6
; κτίσιμο, 7 στρατός. Ό,τι αγγίζει τους πίνακες των χωρικών (σελίδα του
; HUD) γίνεται με την C0 (call0).
;
;   ΟΙΚΟΝΟΜΙΑ   ένας αδρανής χωρικός ανά δευτερόλεπτο πάει να μαζέψει, με
;               τη σειρά του ai_mix (ai_gather, boot.asm)· το Κέντρο Πόλης
;               βγάζει χωρικούς ώς AI_VIL, όσο χωράει ο πληθυσμός
;   ΚΤΙΣΙΜΟ     ένα κτίριο τη φορά, σε μία από τις θέσεις ai_spots, από τους
;               2 πρώτους χωρικούς: σπίτι όταν ο χώρος πέφτει κάτω από 3,
;               αλλιώς στρατώνας (με AI_VIL0 χωρικούς). Θεμέλιο που δεν
;               προχωράει για AI_STALL s: κι άλλοι δύο χωρικοί
;   ΣΤΡΑΤΟΣ     ο στρατώνας βγάζει σπαθοφόρους· όταν οι αδρανείς στο σπίτι
;               (ως HOME_R από το Κέντρο του) φτάσουν το ai_wave και πέρασε το
;               ai_cool: κύμα — στο Κέντρο Πόλης του παίκτη (αλλιώς σε
;               κτίριο, αλλιώς σε μονάδα του), από τα σημεία ai_route.
;               Όσοι του κύματος μείνουν χωρίς στόχο παίρνουν τον επόμενο.
;               Μετά από κάθε κύμα: ai_cool = AI_GAP, και το κύμα +2
;   ΤΕΛΟΣ       ομάδα χωρίς μονάδες και χωρίς Κέντρο Πόλης: game_end (1 νίκη,
;               2 ήττα), το παιχνίδι σταματά, και το περιθώριο γίνεται
;               πράσινο ή κόκκινο

AI_PER      equ 25              ; καρέ μονάδων ανά σκέψη
AI_VIL      equ 10
AI_VIL0     equ 5
AI_HOUSES   equ 8
AI_FIRST    equ 180             ; s ώς το πρώτο κύμα
AI_GAP      equ 60
AI_WMAX     equ 16
HOME_I      equ AI_TC_I + 2
HOME_J      equ AI_TC_J + 2
HOME_R      equ 18

ai_t:       db 0
ai_cool:    dw AI_FIRST
ai_wave:    db 6
ai_att:     db 0                ; κύμα σε εξέλιξη
ai_rr:      db 0
ai_tgt:     db 0
ap_t:       db 0
ap_n:       db 0
au_end:     db 0
an_blk:                         ; η απογραφή
an_vil:     db 0                ; χωρικοί του
an_sol:     db 0                ; στρατιώτες στο κύμα
an_idle:    db 0                ; αδρανείς στρατιώτες στο σπίτι
an_lost:    db 0                ; στο κύμα, μακριά, χωρίς στόχο
an_pop:     db 0                ; όλες του (ζωντανές)
an_p:       db 0                ; του παίκτη
ab_hs:      db 0                ; σπίτια έτοιμα
ab_fd:      db 0                ; θεμέλια
ab_q:       db 0                ; στις ουρές
AN_0        equ $ - an_blk
an_iv:      db 255              ; ένας αδρανής χωρικός
an_b1:      db 255              ; οι χτίστες
an_b2:      db 255
an_pu:      db 255              ; μια μονάδα του παίκτη
ab_tc:      db 255              ; θέσεις: Κέντρο Πόλης, στρατώνας
ab_bar:     db 255
ab_ptc:     db 255              ; του παίκτη: Κέντρο Πόλης, κάποιο κτίριο
ab_pb:      db 255
ab_fs:      db 255              ; ένα θεμέλιο του
AN_LEN      equ $ - an_blk
ai_fp:      db 0                ; η πρόοδός του στην προηγούμενη σκέψη
ai_fdt:     db 0                ; δευτερόλεπτα χωρίς πρόοδο

; τροφή, ξύλο, χρυσός: η σειρά των χωρικών
ai_mix:     db 0, 2, 0, 1, 0, 2, 0, 1   ; (ξύλο μόνο για σπίτια, στρατώνα)
; οι θέσεις των κτιρίων (i0, j0), γύρω από το Κέντρο (58, 27)
; (με 2 πλακίδια περιθώριο: κανένα στενό πέρασμα ανάμεσά τους)
ai_spots:   db 64, 23,  64, 28,  53, 22,  58, 22,  65, 33,  63, 18
            db 68, 18,  69, 23,  69, 28,  56, 17,  70, 33,  73, 14
AI_NSP      equ ($ - ai_spots) / 2

; Από το bld_tick, σε κάθε καρέ μονάδων.
ai_tick:
        ld a,(ai_on)
        or a
        ret z
        ld a,(game_end)
        or a
        ret nz
        ld hl,ai_t
        inc (hl)
        ld a,(hl)
        dec a
        jr z,ai_units
        dec a
        ld c,UNITS / 2          ; (η απογραφή σε δύο καρέ)
        jr z,ai_units.half
        dec a
        jp z,ai_blds
        dec a
        jp z,ai_end
        dec a
        jp z,ai_eco
        dec a
        jp z,ai_build
        dec a
        jp z,ai_army
        ld a,(hl)
        cp AI_PER
        ret c
        ld (hl),0
        ld hl,(ai_cool)         ; ένα δευτερόλεπτο
        ld a,h
        or l
        ret z
        dec hl
        ld (ai_cool),hl
        ret

; Η απογραφή των μονάδων.
ai_units:
        ld hl,an_blk
        ld b,AN_0
.z:     ld (hl),0
        inc hl
        djnz .z
        ld b,AN_LEN - AN_0
.f:     ld (hl),255
        inc hl
        djnz .f
        ld c,0
.half:  ld a,c
        add a,UNITS / 2
        ld (au_end),a
        ld a,c
.u:     push af
        call idx_ix
        ld a,(ix+U_TEAM)
        cp 2
        jr nc,.n
        bit F_WANDER,(ix+U_FL)
        jr nz,.n
        or a
        jr nz,.ai
        ld hl,an_p              ; του παίκτη
        inc (hl)
        ld a,(ix+U_IDX)
        ld (an_pu),a
        jr .n
.ai:    ld hl,an_pop
        inc (hl)
        ld a,(ix+U_SET)
        or a
        jr z,.v
        cp 3
        jr z,.v
        call ai_cls             ; στρατιώτης
        dec a
        jr nz,.w
        ld hl,an_idle
        inc (hl)
        jr .n
.w:     dec a
        jr z,.ws
        dec a
        jr nz,.n
        ld hl,an_lost
        inc (hl)
.ws:    ld hl,an_sol
        inc (hl)
        jr .n
.v:     ld hl,an_vil
        inc (hl)
        call ord_get            ; μάχεται
        inc a
        jr nz,.n
        ld a,(ix+U_JOB)
        cp J_BUILD
        jr z,.n
        ld a,(ix+U_IDX)
        ld hl,an_b1
        ld a,(hl)
        inc a
        jr z,.b
        inc hl
        ld a,(hl)
        inc a
        jr nz,.nb
.b:     ld a,(ix+U_IDX)
        ld (hl),a
.nb:    ld a,(ix+U_JOB)
        or a
        jr nz,.n
        bit F_MOVE,(ix+U_FL)
        jr nz,.n
        ld a,(ix+U_IDX)
        ld (an_iv),a
.n:     pop af
        inc a
        ld hl,au_end
        cp (hl)
        jp nz,.u
        ret

; IX = στρατιώτης του αντιπάλου -> A: 1 αδρανής στο σπίτι, 2 στο κύμα (με
; εντολή, ή μακριά και περπατάει), 3 μακριά χωρίς δουλειά, 4 περπατάει στο
; σπίτι.
ai_cls: call ord_get
        inc a
        ld a,2
        ret nz
        call unit_sp
        ld a,(sp_ui)
        sub HOME_I
        call abs_a
        ld c,a
        ld a,(sp_uj)
        sub HOME_J
        call abs_a
        cp c
        jr nc,.m
        ld a,c
.m:     cp HOME_R + 1
        jr c,.home
        bit F_MOVE,(ix+U_FL)
        ld a,2
        ret nz
        inc a
        ret
.home:  bit F_MOVE,(ix+U_FL)
        ld a,1
        ret z
        ld a,4
        ret

; Η απογραφή των κτιρίων.
ai_blds:
        ld iy,BLD_TAB
        ld a,(bld_top)
        ld b,a
.l:     ld a,(iy+B_TYPE)
        cp 255
        jr z,.n
        ld c,a
        call bidx
        ld e,a
        ld a,(iy+B_OWN)
        or a
        jr nz,.ai
        ld a,e                  ; του παίκτη
        ld (ab_pb),a
        ld a,c
        or a
        jr nz,.n
        ld a,e
        ld (ab_ptc),a
        jr .n
.ai:    ld a,(iy+B_QN)
        ld hl,ab_q
        add a,(hl)
        ld (hl),a
        ld a,c
        or a
        jr nz,.nt
        ld a,e
        ld (ab_tc),a
        jr .n
.nt:    cp BTY_BARRACKS
        jr nz,.nb
        ld a,e
        ld (ab_bar),a
.nb:    ld a,(iy+B_ST)
        or a
        jr nz,.rd
        ld hl,ab_fd
        inc (hl)
        ld a,e
        ld (ab_fs),a
        jr .n
.rd:    ld a,c
        cp BTY_HOUSE
        jr nz,.n
        ld hl,ab_hs
        inc (hl)
.n:     call bnext
        djnz .l
        ret

; Νίκη ή ήττα — όχι στη μέση της επανασχεδίασης ενός κτιρίου που έπεσε (το
; παιχνίδι σταματά: θα έμενε μισό στην οθόνη).
ai_end: ld a,(rq_n)
        inc a
        ret nz
        ld a,(an_p)
        or a
        jr nz,.ai
        ld a,(ab_ptc)
        inc a
        jr nz,.ai
        ld a,2                  ; ήττα
        jr .end
.ai:    ld a,(an_pop)
        or a
        ret nz
        ld a,(ab_tc)
        inc a
        ret nz
        ld a,1                  ; νίκη
.end:   ld (game_end),a
        ld a,1
        ld (paused),a
        ld a,(game_end)
        dec a
        ld a,HW_GREEN
        jr z,.c
        ld a,HW_RED
.c:     ld (bd_busy),a          ; το περιθώριο (ο κύριος βρόχος)
        ld (bd_idle),a
        ret

; -> A = πόσες χωράνε ακόμα (με πρόσημο): POP_BASE + POP_HOUSE x σπίτια -
; (ζωντανές + στις ουρές). Carry αν καμία.
ai_room:
        ld a,(ab_hs)
        ld c,a
        add a,a
        add a,a
        add a,c
        add a,POP_BASE
        ld c,a
        ld a,(an_pop)
        ld hl,ab_q
        add a,(hl)
        ld b,a
        ld a,c
        sub b
        ret c
        cp 1
        ret

; Οικονομία: ένας αδρανής χωρικός στη δουλειά, και χωρικοί από το Κέντρο.
ai_eco: ld a,(an_iv)
        cp 255
        jr z,.tr
        call idx_ix
        ld hl,ai_rr
        ld a,(hl)
        inc a
        and 7
        ld (hl),a
        ld hl,ai_mix
        call tab_a
        ld c,a
        ld hl,ai_gather
        call call0
.tr:    ld a,(ab_tc)
        cp 255
        ret z
        call brec_iy
        ld a,(iy+B_ST)
        or a
        ret z
        ld a,(iy+B_QN)
        or a
        ret nz
        ld a,(an_vil)
        cp AI_VIL
        ret nc
        call ai_room
        ret c

; IY = κτίριο του αντιπάλου: μία μονάδα στην ουρά του, αν πληρώνεται.
ai_queue:
        ld a,(iy+B_TYPE)
        call bt_hl
        ld de,BT_UCOST
        add hl,de
        call ai_pay
        ret c
        inc (iy+B_QN)
        ld hl,bq_tot
        inc (hl)
        ld hl,ab_q
        inc (hl)
        ret

; HL -> 4 x κόστος: NC αν το ai_val φτάνει (ai_chk), και αφαιρείται (ai_pay).
ai_pay: call ai_chk
        ret c
        ld de,ai_val
        ld b,4
.d:     ld a,(de)
        sub (hl)
        ld (de),a
        inc de
        ld a,(de)
        sbc a,0
        ld (de),a
        inc de
        inc hl
        djnz .d
        or a
        ret
ai_chk: push hl
        ld de,ai_val
        ld b,4
.c:     ld a,(de)
        sub (hl)
        inc de
        ld a,(de)
        sbc a,0
        jr c,.no
        inc de
        inc hl
        djnz .c
.no:    pop hl
        ret

; Κτίσιμο: ένα κτίριο τη φορά. Θεμέλιο που δεν προχωράει για AI_STALL s
; (οι χτίστες κόλλησαν, ή σκοτώθηκαν): κι άλλοι δύο χωρικοί.
AI_STALL    equ 12
ai_build:
        ld a,(ab_fd)
        or a
        jr z,.new
        ld a,(ab_fs)
        call brec_iy
        ld a,(iy+B_PROG)
        ld hl,ai_fp
        cp (hl)
        ld (hl),a
        ld hl,ai_fdt
        jr nz,.prog
        inc (hl)
        ld a,(hl)
        cp AI_STALL
        ret c
.prog:  ld (hl),0
        ret nz                  ; (προχώρησε)
        ld a,(ab_fs)
        ld (bp_slot),a
        jp ai_place.bld
.new:   ld a,(an_b1)
        inc a
        ret z
        ld a,(ab_hs)
        cp AI_HOUSES
        jr nc,.bar
        call ai_room
        jr c,.h
        cp 3
        jr nc,.bar
.h:     ld a,BTY_HOUSE
        jr ai_place
.bar:   ld a,(ab_bar)
        inc a
        ret nz
        ld a,(an_vil)
        cp AI_VIL0
        ret c
        ld a,BTY_BARRACKS

; A = τύπος: στην πρώτη ελεύθερη θέση του ai_spots, αν πληρώνεται· θεμέλιο,
; και οι χτίστες εκεί.
ai_place:
        ld (ap_t),a
        call bt_hl
        ld a,(hl)
        ld (ap_n),a
        inc hl
        inc hl
        inc hl
        call ai_chk
        ret c
        push hl
        ld hl,ai_spots
        ld b,AI_NSP
.s:     ld d,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push bc
        push hl
        push de
        call fp_free
        pop de
        pop hl
        pop bc
        jr z,.got
        djnz .s
        pop hl
        ret
.got:   ld a,(ap_t)
        ld c,0
        call bld_new
        pop hl
        ret c
        call ai_pay
        ld (iy+B_OWN),1
        push iy
        ld hl,bld_redraw        ; το θεμέλιο στην οθόνη
        call call0
        pop iy
        call bidx
        ld (bp_slot),a
        ld hl,ab_fd
        inc (hl)
.bld:   ld a,(an_b1)
        call .go
        ld a,(an_b2)
.go:    cp 255
        ret z
        call idx_ix
        ld hl,build_go
        jp call0

; D = i0, E = j0, ap_n = n -> Z αν το (n + 4) x (n + 4) γύρω της είναι μέσα
; στον χάρτη, χωρίς πόρο (εκτός από κούτσουρο) και χωρίς εμπόδιο: 2
; πλακίδια ελεύθερα γύρω από το κτίριο (με 1, ανάμεσα σε δύο κτίρια και στο
; Κέντρο έμεναν περάσματα όπου η ακολούθηση τοίχου κολλούσε).
fp_free:
        dec d
        dec d
        dec e
        dec e
        ld a,(ap_n)
        add a,4
        ld c,a
        ld b,a
.r:     ld a,e
        cp MAPW
        jr nc,.bad
        push bc
        push de
        call map_ptr
        pop de
        pop bc
        push bc
        push de
        ld b,c
.t:     ld a,d
        cp MAPW
        jr nc,.bad2
        ld a,(hl)
        and 15
        jr z,.ok
        cp 4
        jr nz,.bad2
.ok:    push hl
        ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        pop hl
        or a
        jr nz,.bad2
        inc hl
        inc d
        djnz .t
        pop de
        pop bc
        inc e
        djnz .r
        xor a
        ret
.bad2:  pop de
        pop bc
.bad:   or 1
        ret

; Στρατός: σπαθοφόροι από τον στρατώνα, και τα κύματα.
ai_army:
        ld a,(ab_bar)
        cp 255
        jr z,.att
        call brec_iy
        ld a,(iy+B_ST)
        or a
        jr z,.att
        ld a,(iy+B_QN)
        cp 2
        jr nc,.att
        call ai_room
        call nc,ai_queue
.att:   ld a,(an_lost)          ; όσοι του κύματος έμειναν μακριά χωρίς
        or a                    ; στόχο παίρνουν τον επόμενο
        jr z,.w
        call ai_target
        ld c,3
        call nc,ai_order
.w:     ld hl,(ai_cool)         ; νέο κύμα
        ld a,h
        or l
        ret nz
        ld a,(ai_wave)
        ld c,a
        ld a,(an_idle)
        cp c
        ret c
        call ai_target
        ret c
        ld a,1
        ld (ai_att),a
        ld hl,AI_GAP
        ld (ai_cool),hl
        ld a,(ai_wave)
        cp AI_WMAX
        jr nc,.o
        add a,2
        ld (ai_wave),a
.o:     ld c,1                  ; οι αδρανείς στο σπίτι

; C = η κατηγορία (ai_cls): εντολή ai_tgt (1: νέο κύμα, 3: όσοι έμειναν).
ai_order:
        xor a
.u:     push af
        push bc
        call idx_ix
        ld a,(ix+U_TEAM)
        dec a
        jr nz,.n
        bit F_WANDER,(ix+U_FL)
        jr nz,.n
        ld a,(ix+U_SET)
        or a
        jr z,.n
        cp 3
        jr z,.n
        call ai_cls
        pop bc
        push bc
        cp c
        jr nz,.n
        call ord_get
        ld a,(ai_tgt)
        ld (hl),a
        ld a,c                  ; νέο κύμα: από την αρχή της διαδρομής
        dec a
        jr nz,.n
        ld (ix+U_TCELL),a
.n:     pop bc
        pop af
        inc a
        cp UNITS
        jr nz,.u
        ret

; -> ai_tgt: 128 + το Κέντρο Πόλης του παίκτη, ή άλλο κτίριό του, ή μια
; μονάδα του. Carry αν τίποτα.
ai_target:
        ld a,(ab_ptc)
        cp 255
        jr nz,.b
        ld a,(ab_pb)
        cp 255
        jr nz,.b
        ld a,(an_pu)
        cp 255
        scf
        ret z
        jr .t
.b:     or 128
.t:     ld (ai_tgt),a
        or a
        ret


; ============================================================ ΟΜΙΧΛΗ (M11)
;
; Τα νέα πλακίδια του fog_reveal (fog.asm) -> στήλες προς επανασχεδίαση
; (FD_TAB), και η επανασχεδίασή τους σε κάθε καρέ (fog_step, από το
; bld_tick).

; D = i, E = j: ένα πλακίδιο μόλις εξερευνήθηκε. Αν το κουτί του (και ο
; πόρος του, 12 γραμμές από πάνω) πέφτει στο παράθυρο: οι 2 στήλες του στο
; FD_TAB, σε συντεταγμένες κόσμου (ώστε να μένουν σωστές αν κυλήσει η
; κάμερα).
fog_new:
        ld l,d                  ; Y = 4 (i + j)
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        push hl
        ld a,d                  ; X = 2 (i - j) + XOFF
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,XOFF
        add hl,bc
        ex (sp),hl              ; (sp) = X, HL = Y
        ld bc,(cam_y)           ; Y - cam_y + 8 στο 1..VIEW_H + 19
        or a
        sbc hl,bc
        ld bc,8
        add hl,bc
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        cp VIEW_H + 20
        jr nc,.no
        pop hl                  ; X - cam_x + 4 στο 1..83
        push hl
        ld bc,(cam_x)
        or a
        sbc hl,bc
        ld bc,4
        add hl,bc
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        cp 84
        jr nc,.no
        ld l,d                  ; y0 = Y - 12 (ως 0)
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        ld bc,-12
        add hl,bc
        jr c,.y
        ld hl,0
.y:     ex de,hl
        pop hl
        push hl
        push de
        call fd_add
        pop de
        pop hl
        inc hl
        inc hl
        jr fd_add
.no:    pop hl
        ret

; HL = wx, DE = y0 (κόσμος· y1 = y0 + 20): στο FD_TAB — με την ίδια στήλη
; ενώνεται. Γεμάτο: όλο το παράθυρο ξανά (redraw).
fd_add: ld (fd_x),hl
        ld (fd_y0),de
        ld hl,20
        add hl,de
        ld (fd_y1),hl
        ld hl,FD_TAB
        ld de,0                 ; η πρώτη ελεύθερη
        ld b,FD_N
.l:     push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        inc a                   ; #FFFF: ελεύθερη
        jr nz,.u
        ld a,h
        inc a
        jr nz,.u
        ld a,d
        or e
        jr nz,.n
        pop de
        push de
        jr .n
.u:     push de
        ld de,(fd_x)
        or a
        sbc hl,de
        pop de
        jr z,.same
.n:     pop hl
        ld a,6
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .l
        ld a,d                  ; νέα
        or e
        jr z,.full
        ex de,hl
        ld de,fd_x
        ex de,hl
        ld bc,6
        ldir
        ret
.full:  ld a,1
        ld (redraw),a
        ret
.same:  pop hl                  ; ένωση: y0 = min, y1 = max
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld hl,(fd_y0)
        or a
        sbc hl,de
        pop hl
        jr nc,.y1
        ld de,(fd_y0)
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
.y1:    inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld hl,(fd_y1)
        or a
        sbc hl,de
        pop hl
        ret c
        ret z
        ld de,(fd_y1)
        ld (hl),d
        dec hl
        ld (hl),e
        ret

; Σε κάθε καρέ μονάδων (bld_tick): οι στήλες του FD_TAB, σε κομμάτια των
; FD_ROWS γραμμών με το col_redraw, όσο το καρέ είναι κάτω από FOG_T (το
; πρώτο κομμάτι πάντα). Όσες βγήκαν από το παράθυρο ξεχνιούνται: όταν
; ξαναφανούν θα ζωγραφιστούν από την κύλιση.
FD_ROWS     equ 12
fog_step:
        ld hl,FD_TAB
        ld b,FD_N
.l:     ld a,(hl)
        inc hl
        and (hl)
        inc a
        jr nz,.go
        ld de,5
        add hl,de
        djnz .l
        ret
.go:    dec hl
        push hl
        call fd_one
        pop hl
        ld a,(t0)
        ld c,a
        ld a,(int_t)
        sub c
        cp FOG_T
        jr c,fog_step
        ret

; HL = μια εγγραφή του FD_TAB: ένα κομμάτι της στήλης της (ή ελεύθερη).
fd_one: ld e,(hl)               ; στήλη = wx - cam_x στο 0..78
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.free
        ld a,l
        cp 79
        jr nc,.free
        ld (fd_c),a
        pop hl
        push hl
        ld e,(hl)               ; y0, y1 - cam_y, στο 0..VIEW_H
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld c,VIEW_H
        call clamp_c
        and #FC
        ld (col_y0),a
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        call clamp_c
        add a,3
        and #FC
        ld (col_y1),a
        ld hl,col_y0
        sub (hl)
        jr z,.free
        jr c,.free
        cp FD_ROWS + 1          ; ως FD_ROWS: όλο, και ελεύθερη
        jr c,.last
        ld a,(hl)               ; αλλιώς ως y0 + FD_ROWS, και το y0 της
        add a,FD_ROWS           ; εγγραφής προχωράει
        ld (col_y1),a
        ld e,a
        ld d,0
        ld hl,(cam_y)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        jr .draw
.last:  pop hl
        dec hl
        dec hl
        ld (hl),255
        inc hl
        ld (hl),255
.draw:  ld hl,fd_draw          ; (με την C0 και πίσω)
        jp call0
.free:  pop hl
        dec hl
        dec hl
        ld (hl),255
        inc hl
        ld (hl),255
        ret

; ------------------------------------------------------------ μίνι χάρτης

; Το πλαίσιο της κάμερας στη γραμμή mm_my του μίνι χάρτη (minimap.asm): στο
; mm_buf, pen MM_FRAME. Ο κόσμος -> μίνι χάρτης, όπως το mockup.minimap:
;   x0 = MM_X + (5 (cam_x - 192) + 48) / 96, x1 το ίδιο με cam_x + 80
;   y0 = MM_Y + (5 cam_y + 96) / 192,       y1 το ίδιο με cam_y + 144
; (διαίρεση με στρογγύλεμα προς τα κάτω).
mm_rect:
        ld hl,(cam_y)
        ld de,0
        call .ky
        ld (mr_y0),a
        ld hl,(cam_y)
        ld de,VIEW_H
        call .ky
        ld (mr_y1),a
        ld a,(mm_my)            ; η γραμμή: έξω από το πλαίσιο;
        add a,MM_Y
        ld c,a
        ld a,(mr_y0)
        cp c
        jr z,.edge              ; Z: πάνω πλευρά
        ret nc
        ld a,(mr_y1)
        cp c
        ret c
.edge:  push af                 ; Z: πάνω ή κάτω πλευρά
        ld hl,(cam_x)
        ld de,0
        call .kx
        ld (mr_x0),a
        ld hl,(cam_x)
        ld de,80
        call .kx
        ld (mr_x1),a
        pop af
        jr z,.hor
        ld a,(mr_x0)            ; ανάμεσα: οι δύο άκρες
        call .px
        ld a,(mr_x1)
        jr .px
.hor:   ld a,(mr_x0)            ; πάνω ή κάτω: x0..x1
.h:     push af
        call .px
        pop af
        ld hl,mr_x1
        cp (hl)
        inc a
        jr c,.h
        ret
.px:    sub MM_X - MM_N / 2     ; x -> k στο 0..19
        cp MM_N
        ret nc
        ld hl,mm_buf
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),MM_FRAME
        ret
.ky:    add hl,de               ; (5 y + 96) / 192 + MM_Y
        call .x5
        ld de,96
        add hl,de
        ld de,192
        ld a,MM_Y - 1
        jr .div
.kx:    add hl,de               ; (5 (x - 192) + 48 + 20 x 96) / 96 + MM_X - 20
        ld de,-192
        add hl,de
        call .x5
        ld de,48 + 20 * 96
        add hl,de
        ld de,96
        ld a,MM_X - 20 - 1
.div:   inc a                   ; HL ≥ 0 / DE
        or a
        sbc hl,de
        jr nc,.div
        ret
.x5:    ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ret

mr_x0:      db 0
mr_x1:      db 0
mr_y0:      db 0
mr_y1:      db 0
