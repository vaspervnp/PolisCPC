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
        jr z,.set
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
