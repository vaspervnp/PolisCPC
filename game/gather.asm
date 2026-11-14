; gather.asm — πόροι και χωρικοί. M6.
;
; ΧΩΡΙΚΟΣ: ΠΗΓΑΙΝΕ -> ΜΑΖΕΨΕ -> ΓΥΡΝΑ -> ΑΔΕΙΑΣΕ
;
;   Η εντολή (RETURN) πάνω σε πλακίδιο με πόρο που μαζεύεται: οι επιλεγμένοι
;   χωρικοί (σετ 0, ομάδα του παίκτη) παίρνουν δουλειά· οι υπόλοιπες μονάδες
;   πάνε απλώς εκεί. Η κατάσταση είναι στο U_JOB, και αλλάζει ΜΟΝΟ στην
;   απόφαση (units_think, μία φορά στα ~22 καρέ):
;
;     J_GO    περπατάει στο ελεύθερο πλακίδιο δίπλα στην πηγή που είναι πιο
;             κοντά της· όταν σταματήσει (και είναι δίπλα): J_WORK
;     J_WORK  σε κάθε απόφαση +GATHER_N, ως carry_max[είδος], από την πηγή·
;             γεμάτος, ή άδειασε η πηγή: J_BACK
;     J_BACK  περπατάει στο κοντινότερο κτίριο που δέχεται το είδος (M7:
;             Κέντρο Πόλης, σιταποθήκη, αποθήκη)· εκεί ο φόρτος πάει στη μπάρα του
;             HUD, και ξανά J_GO στην ίδια πηγή. Αν η πηγή άδειασε: στην
;             κοντινότερη του ίδιου είδους (src_next)· αν δεν έχει: αδρανής.
;
;   Το πρώτο ταξίδι ακολουθεί το flow field της εντολής· τα επόμενα πάνε
;   ίσια, με ακολούθηση τοίχου (U_FIELD = FIELD_WALK, pathing.asm).
;
; ΠΗΓΕΣ: τι έχει μείνει
;
;   Ένα byte ανά πλακίδιο για το ποσό θα ήταν 9 KB. Εδώ μόνο οι πηγές που
;   ΑΝΟΙΞΑΝ: πίνακας SRC_N εγγραφών (θέση στον χάρτη, ποσό), που γεμίζει
;   όταν κάποιος αρχίζει να μαζεύει. Όταν το ποσό τελειώσει, το πλακίδιο
;   αλλάζει πόρο (δέντρο -> κούτσουρο, θάμνος -> άδειος, βράχος -> πετρούλες,
;   res_spent) και, αν φαίνεται, ξαναζωγραφίζονται οι δύο στήλες του.
;
; Οι πίνακες ανά μονάδα (L = ο δείκτης της, όπως PX/PY) και οι πηγές είναι
; στις σειρές της σελίδας του HUD που δεν φαίνονται ποτέ (screen.asm).

U_JOB       equ 27              ; η δουλειά: 0 καμία, J_*
J_GO        equ 1
J_WORK      equ 2
J_BACK      equ 3

J_CARRY     equ #7700           ; 128: πόσο κουβαλάει
J_KIND      equ #7780           ; 128: τι (0 τροφή, 1 ξύλο, 2 χρυσό, 3 πέτρα)
J_SI        equ #7F00           ; 128: η πηγή, i
J_SJ        equ #7F80           ; 128: η πηγή, j
SRC_TAB     equ #6F00           ; SRC_N x (θέση στον χάρτη dw, ποσό dw)
SRC_N       equ 32              ; ελεύθερη: high byte της θέσης = #FF

SET_CARRY   equ 3               ; το σετ του χωρικού με φορτίο (make_carry.py)
GATHER_N    equ 2
FIELD_WALK  equ FIELDS + 1      ; ίσια, με ακολούθηση τοίχου


; ------------------------------------------------------------ εκκίνηση

; HL = αρχή σελίδας -> 256 μηδενικά.
zero_page:
        ld d,h
        ld e,1
        ld (hl),0
        ld bc,255
        ldir
        ret

; ------------------------------------------------------------ εντολή

; (n_i, n_j) με πρόσημο -> A = το είδος του πόρου εκεί (255 κανένα), και
; cmd_si, cmd_sj = το πλακίδιο.
res_at: ld hl,(n_i)
        ld a,h
        or a
        jr nz,.none
        ld a,l
        cp MAPW
        jr nc,.none
        ld d,a
        ld hl,(n_j)
        ld a,h
        or a
        jr nz,.none
        ld a,l
        cp MAPW
        jr nc,.none
        ld e,a
        ld (cmd_sj),de          ; cmd_sj = j, cmd_si = i
        call map_ptr
        ld a,(hl)
        and 15
        ld e,a
        ld d,0
        ld hl,res_kind
        add hl,de
        ld a,(hl)
        ret
.none:  ld a,255
        ret

; A = ζυγό byte οθόνης: το κομμάτι col_y0..col_y1 της στήλης από την αρχή,
; ΤΟ ΙΔΙΟ κομμάτι στον καθρέφτη (όχι όλη η στήλη: πιο κάτω μπορεί να είναι
; ζωγραφισμένη μια μονάδα, που δεν είναι φόντο), και ορθογώνια 4 x 16 που
; καλύπτουν το κομμάτι.
col_redraw:
        push af
        xor a                   ; μια κάθετη κύλιση στη μέση έχει ίσως
        ld (v_pend),a           ; ζωγραφίσει το παλιό: ξαναρχίζει
        ld a,#FE                ; οι έλεγχοι του παραθύρου στο draw_column
        ld (cw_j1),a
        ld (cw_j2),a
        ld a,RAM_RES            ; οι πόροι είναι στην C6
        call setram
        pop af
        push af
        call draw_column
        ld a,RAM_BASE
        call setram
        ld a,#18                ; πίσω σε «jr»: όλο το ύψος
        ld (cw_j1),a
        ld (cw_j2),a
        pop af
        push af
        call mirror_part
        pop af
        ld c,a
        ld a,(col_y0)
        ld b,a
.r:     push bc
        call add_rect
        pop bc
        ld a,b
        add a,16
        ld b,a
        ld hl,col_y1
        cp (hl)
        jr c,.r
        xor a                   ; πίσω σε όλο το ύψος: αλλιώς η επόμενη
        ld (col_y0),a           ; κύλιση (draw_column) ψαλιδίζει τους
        ld a,VIEW_H             ; πόρους και τα κτίρια της στο κομμάτι
        ld (col_y1),a
        ret

; A = ζυγό byte οθόνης: οι γραμμές col_y0..col_y1 της στήλης (2 bytes) στον
; καθρέφτη (τράπεζα C4, ίδια διάταξη, bit 15 σβηστό).
mirror_part:
        ld c,a
        ld a,RAM_BG
        call setram
        ld a,(col_y0)
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld a,(col_y0)
        neg
        ld b,a
        ld a,(col_y1)
        add a,b
        ld b,a                  ; B = πόσες γραμμές
.l:     ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ld a,c
        add a,e
        ld e,a
        call c,de_carry
        ld h,d
        ld l,e
        res 7,h
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        pop hl
        djnz .l
        ld a,RAM_BASE
        jp setram

; ------------------------------------------------------------ θέσεις

; D = i, E = j (0..95) -> HL = MAP + 96 j + i. Κρατάει DE.
map_ptr:
        ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc
        ld c,d
        ld b,0
        add hl,bc
        ld bc,MAP
        add hl,bc
        ret

; IX -> sp_ui, sp_uj: το πλακίδιο της, στον χάρτη.
unit_sp:
        call unit_tile
        ld hl,(n_i)
        call clamp95
        ld (sp_ui),a
        ld hl,(n_j)
        call clamp95
        ld (sp_uj),a
        ret

; IX -> D = i, E = j: το ελεύθερο πλακίδιο γύρω από την πηγή του που είναι
; πιο κοντά στο δικό της. Carry αν δεν υπάρχει κανένα.
stand_point:
        call unit_sp
        call job_src
        dec d
        dec e
        ld c,3

; D, E = γωνία, C = πλευρά: το ελεύθερο πλακίδιο του τετραγώνου C x C που
; είναι πιο κοντά στο (sp_ui, sp_uj) -> D, E. Carry αν κανένα.
near_free:
        ld a,c
        ld (nf_n),a
        ld a,255
        ld (sp_best),a
        ld b,c
.r:     push bc
        push de
        ld a,e                  ; έξω από τον χάρτη (και το -1 = 255)
        cp MAPW
        jr nc,.nr
        push de
        ld d,0
        call map_ptr            ; HL = MAP + 96 j, + i με πρόσημο
        pop de
        ld a,d
        ld c,a
        rla
        sbc a,a
        ld b,a
        add hl,bc
        ld a,(nf_n)
        ld b,a
.c:     ld a,d
        cp MAPW
        jr nc,.n
        push hl
        ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        or a
        jr nz,.nn
        ld a,(sp_ui)            ; |i - ui| + |j - uj|
        sub d
        call abs_a
        ld c,a
        ld a,(sp_uj)
        sub e
        call abs_a
        add a,c
        ld hl,sp_best
        cp (hl)
        jr nc,.nn
        ld (hl),a
        ld (sp_bj),de
.nn:    pop hl
.n:     inc hl
        inc d
        djnz .c
.nr:    pop de
        inc e
        pop bc
        djnz .r
        ld a,(sp_best)
        inc a
        scf
        ret z
        ld de,(sp_bj)
        or a
        ret

; HL = |HL|.
abs_hl: bit 7,h
        ret z
        xor a
        sub l
        ld l,a
        sbc a,a
        sub h
        ld h,a
        ret

; HL, DE -> HL = min, DE = max (χωρίς πρόσημο).
order_hl_de:
        call cmp_hl_de
        ret c
        ex de,hl
        ret

; Carry αν HL < DE (χωρίς πρόσημο). Κρατάει HL, DE.
cmp_hl_de:
        or a
        sbc hl,de
        add hl,de
        ret

abs_a:  bit 7,a
        ret z
        neg
        ret

; D = i, E = j -> HL = 2 (i - j) + 190, DE = 4 (i + j) - 10: η πάνω-αριστερή
; γωνία της μονάδας που πατάει στο κέντρο του πλακιδίου.
tile_xy:
        ld a,d
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,190
        add hl,bc
        push hl
        ld l,d
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        ld bc,-10
        add hl,bc
        ex de,hl
        pop hl
        ret

; IX, D = i, E = j -> ο στόχος της εκεί, και το U_OCELL του.
tile_target:
        push de
        call tile_xy
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld (ix+U_TY),e
        ld (ix+U_TY+1),d
        pop de
        ld l,d
        ld h,0
        ld (n_i),hl
        ld l,e
        ld (n_j),hl
        call tile_cell
        ld (ix+U_OCELL),a
        ret

