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
;     J_WORK  σε κάθε απόφαση +GATHER_N, ως CARRY_MAX, από το ποσό της πηγής·
;             γεμάτος, ή άδειασε η πηγή: J_BACK
;     J_BACK  περπατάει στο σημείο απόθεσης (δίπλα στο Κέντρο Πόλης, που
;             ακόμα δεν ζωγραφίζεται — M7)· εκεί ο φόρτος πάει στη μπάρα του
;             HUD, και ξανά J_GO στην ίδια πηγή. Αν η πηγή άδειασε: αδρανής.
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

CARRY_MAX   equ 10
GATHER_N    equ 2
FIELD_WALK  equ FIELDS + 1      ; ίσια, με ακολούθηση τοίχου

DROP_I      equ 33              ; ανατολικά του Κέντρου Πόλης (30..32, 58..60)
DROP_J      equ 59
DROP_X      equ 2 * (DROP_I - DROP_J) + 190
DROP_Y      equ 4 * (DROP_I + DROP_J) - 10

; ------------------------------------------------------------ εκκίνηση

gather_init:
        ld hl,SRC_TAB + 1       ; όλες οι πηγές ελεύθερες
        ld b,SRC_N
.s:     ld (hl),#FF
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .s
        ld hl,J_CARRY           ; καμία δεν κουβαλάει τίποτα
        call zero_page
        ld hl,J_SI
        call zero_page
        jp hud_update

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

; IX = χωρικός της εντολής: η πηγή cmd_si, cmd_sj, του είδους cmd_kind.
job_start:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(cmd_si)
        ld (hl),a
        set 7,l
        ld a,(cmd_sj)
        ld (hl),a
        ld h,J_KIND >> 8        ; άλλο είδος: ό,τι κουβαλούσε χάνεται
        ld a,(cmd_kind)
        cp (hl)
        jr z,.same
        ld (hl),a
        res 7,l
        ld (hl),0
.same:  call stand_point
        jr c,job_idle           ; τίποτα ελεύθερο γύρω της: απλώς πάει εκεί
        call tile_target
        ld (ix+U_JOB),J_GO
        ret

job_idle:
        ld (ix+U_JOB),0
        ret

; ------------------------------------------------------------ απόφαση

; IX, U_JOB != 0. Από το unit_think. Τίποτα όσο περπατάει.
job_tick:
        bit F_MOVE,(ix+U_FL)
        ret nz
        ld a,(ix+U_JOB)
        cp J_WORK
        jp z,job_work
        cp J_GO
        jr z,job_at_src
        ; J_BACK, στο σημείο απόθεσης: ο φόρτος στη μπάρα
        ld l,(ix+U_IDX)
        ld h,J_CARRY >> 8
        ld c,(hl)
        ld (hl),0
        set 7,l                 ; J_KIND
        ld a,(hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,hud_val
        add hl,de
        ld a,(hl)
        add a,c
        ld (hl),a
        inc hl
        ld a,(hl)
        adc a,0
        ld (hl),a
        ld a,1
        ld (hud_dirty),a
        ; και πίσω στην πηγή, αν έχει ακόμα
job_go_src:
        call src_check
        jr nz,job_idle
        call stand_point
        jr c,job_idle
        call tile_target
        ld (ix+U_JOB),J_GO
job_walk:
        ld (ix+U_FIELD),FIELD_WALK
        ld (ix+U_WF),0
        ld (ix+U_STUCK),0
        set F_MOVE,(ix+U_FL)
        ret
job_at_src:                     ; σταμάτησε: είναι δίπλα στην πηγή;
        call unit_tile
        ld hl,(n_i)
        call clamp95
        ld c,a
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld a,(hl)
        sub c
        inc a
        cp 3
        jr nc,job_idle
        ld hl,(n_j)
        call clamp95
        ld c,a
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_SJ >> 8
        ld a,(hl)
        sub c
        inc a
        cp 3
        jp nc,job_idle
        ld (ix+U_JOB),J_WORK
        ret

job_go_drop:
        ld hl,DROP_X
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld hl,DROP_Y
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        ld (ix+U_JOB),J_BACK
        jr job_walk

; Μαζεύει: min(GATHER_N, ό,τι χωράει, ό,τι έχει η πηγή).
job_work:
        call src_check
        jr nz,.gone
        call src_entry          ; HL -> το ποσό της πηγής
        push hl
        ld e,(hl)
        inc hl
        ld d,(hl)               ; DE = ποσό
        ld l,(ix+U_IDX)
        ld h,J_CARRY >> 8
        ld a,CARRY_MAX
        sub (hl)
        ld c,a                  ; C = ό,τι χωράει
        ld a,GATHER_N
        cp c
        jr c,.r
        ld a,c
.r:     ld b,a                  ; B = min(GATHER_N, χωράει)
        ld a,d
        or a
        jr nz,.t
        ld a,e
        cp b
        jr nc,.t
        ld b,a                  ; ... και ως το ποσό
.t:     ld a,(hl)
        add a,b
        ld (hl),a
        ld c,a                  ; C = φόρτος
        pop hl
        ld a,e
        sub b
        ld (hl),a
        inc hl
        ld a,d
        sbc a,0
        ld (hl),a
        or (hl)
        dec hl
        or (hl)
        jr z,.empty
        ld a,c
        cp CARRY_MAX
        ret c
        jr job_go_drop
.empty: dec hl                  ; η εγγραφή ελεύθερη, το πλακίδιο αλλάζει
        ld (hl),#FF
        call src_deplete
        jr job_go_drop
.gone:  ld l,(ix+U_IDX)         ; την άδειασε άλλος: ό,τι κουβαλάει στο σπίτι
        ld h,J_CARRY >> 8
        ld a,(hl)
        or a
        jr nz,job_go_drop
        jp job_idle

; ------------------------------------------------------------ πηγές

; IX -> D = i, E = j της πηγής του.
job_src:
        ld l,(ix+U_IDX)
        ld h,J_SI >> 8
        ld d,(hl)
        set 7,l
        ld e,(hl)
        ret

; IX -> Z αν η πηγή έχει ακόμα πόρο του είδους του.
src_check:
        call job_src
        call map_ptr
        ld a,(hl)
        and 15
        ld e,a
        ld d,0
        ld hl,res_kind
        add hl,de
        ld c,(hl)
        ld l,(ix+U_IDX)
        set 7,l
        ld h,J_KIND >> 8
        ld a,(hl)
        cp c
        ret

; IX -> HL = το ποσό (dw) της πηγής του: η εγγραφή της, ή νέα με το ποσό
; του πόρου (res_amount). Αν ο πίνακας γέμισε, ένα ποσό που δεν τελειώνει.
src_entry:
        call job_src
        call map_ptr
        push hl                 ; (sp) = το byte του χάρτη
        ld bc,-MAP
        add hl,bc
        ex de,hl                ; DE = η θέση στον χάρτη
        ld hl,SRC_TAB
        ld b,SRC_N
.f:     ld a,(hl)
        inc hl
        cp e
        jr nz,.n1
        ld a,(hl)
        cp d
        jr z,.hit
.n1:    inc hl
        inc hl
        inc hl
        djnz .f
        ld hl,SRC_TAB + 1       ; καμία: η πρώτη ελεύθερη
        ld b,SRC_N
.g:     ld a,(hl)
        inc a
        jr z,.new
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .g
        pop hl                  ; γεμάτος
        ld hl,1000
        ld (src_spare),hl
        ld hl,src_spare
        ret
.new:   ld (hl),d
        dec hl
        ld (hl),e
        inc hl
        inc hl                  ; HL -> ποσό
        ex (sp),hl              ; HL = το byte του χάρτη
        ld a,(hl)
        and 15
        add a,a
        ld e,a
        ld d,0
        ld hl,res_amount
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        dec hl
        ret
.hit:   inc hl
        pop de
        ret

; IX: η πηγή του άδειασε. Ο πόρος γίνεται res_spent, και αν το πλακίδιο
; φαίνεται, ξαναζωγραφίζεται ΜΟΝΟ το κομμάτι του: οι 2 στήλες (4 bytes) του
; sprite, στις γραμμές του (σε ομάδες των 4) — έδαφος και πόροι με τη σειρά
; του ζωγράφου, ψαλιδισμένα εκεί (draw_column της κύλισης, με col_y0..y1),
; και ο καθρέφτης. Οι μονάδες και ο κέρσορας που το ακουμπάνε ξαναζωγρα-
; φίζονται από πάνω (ορθογώνια στο RECTS, units_mark). Από την απόφαση:
; μετά το units_prep, πριν το units_move.
src_deplete:
        call job_src
        push de
        call map_ptr
        ld a,(hl)
        and 15
        ld c,a
        ld b,0
        push hl
        ld hl,res_spent
        add hl,bc
        ld c,(hl)
        pop hl
        ld a,(hl)
        and #F0
        or c
        ld (hl),a
        pop de
        call tile_xy            ; HL = x, DE = y (= το sprite του πόρου)
        push hl
        ex de,hl                ; y - cam_y: -16 < y < VIEW_H
        ld bc,(cam_y)
        or a
        sbc hl,bc
        ld bc,16
        add hl,bc
        pop de
        ld a,h
        or a
        ret nz
        ld a,l
        or a
        ret z
        cp VIEW_H + 16
        ret nc
        sub 16                  ; col_y0 = max(0, y) AND #FC
        jr nc,.y0
        xor a
.y0:    and #FC
        ld (col_y0),a
        ld a,l                  ; col_y1 = min(VIEW_H, y + 16 + 3) AND #FC
        add a,3
        cp VIEW_H + 1
        jr c,.y1
        ld a,VIEW_H
.y1:    and #FC
        ld (col_y1),a
        ex de,hl                ; οι δύο στήλες: x - cam_x και + 2
        ld bc,(cam_x)
        or a
        sbc hl,bc
        ld b,2
.c:     push bc
        push hl
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp 80 - 1
        call c,col_redraw
.skip:  pop hl
        inc hl
        inc hl
        pop bc
        djnz .c
        xor a                   ; η κύλιση: όλο το ύψος
        ld (col_y0),a
        ld a,VIEW_H
        ld (col_y1),a
        ret

; A = ζυγό byte οθόνης: το κομμάτι col_y0..col_y1 της στήλης από την αρχή,
; ΤΟ ΙΔΙΟ κομμάτι στον καθρέφτη (όχι όλη η στήλη: πιο κάτω μπορεί να είναι
; ζωγραφισμένη μια μονάδα, που δεν είναι φόντο), και ορθογώνια 4 x 16 που
; καλύπτουν το κομμάτι.
col_redraw:
        push af
        call draw_column
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

; IX -> D = i, E = j: το ελεύθερο πλακίδιο γύρω από την πηγή του που είναι
; πιο κοντά στο δικό της. Carry αν δεν υπάρχει κανένα.
stand_point:
        call unit_tile
        ld hl,(n_i)
        call clamp95
        ld (sp_ui),a
        ld hl,(n_j)
        call clamp95
        ld (sp_uj),a
        call job_src
        ld (sp_sj),de           ; sp_sj = j, sp_si = i
        ld a,255
        ld (sp_best),a
        ld hl,nbr_tab
        ld b,8
.n:     push bc
        push hl
        ld a,(sp_si)
        add a,(hl)
        ld d,a
        inc hl
        ld a,(sp_sj)
        add a,(hl)
        ld e,a
        ld a,d                  ; έξω από τον χάρτη (και το -1 = 255)
        cp MAPW
        jr nc,.next
        ld a,e
        cp MAPW
        jr nc,.next
        call map_ptr
        ld l,(hl)
        ld h,BLOCK_TAB >> 8
        ld a,(hl)
        or a
        jr nz,.next
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
        jr nc,.next
        ld (hl),a
        ld (sp_bj),de           ; sp_bj = j, sp_bi = i
.next:  pop hl
        inc hl
        inc hl
        pop bc
        djnz .n
        ld a,(sp_best)
        inc a
        scf
        ret z
        ld de,(sp_bj)
        or a
        ret

nbr_tab:    db -1,-1, 0,-1, 1,-1, 1,0, 1,1, 0,1, -1,1, -1,0

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

; ------------------------------------------------------------ HUD

; Οι 6 αριθμοί της μπάρας (hud_val) στη σελίδα του HUD, 4 ψηφία ο καθένας,
; στοιχισμένα δεξιά. Η σελίδα είναι κύρια RAM: η C0 πρέπει να είναι μέσα.
hud_update:
        xor a
        ld (hud_dirty),a
        ld hl,hud_val
        ld de,bar_x
        ld b,6
.n:     push bc
        push de
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld a,(de)
        call hud_num
        pop hl
        pop de
        inc de
        pop bc
        djnz .n
        ret

; BC = τιμή, A = byte της πρώτης στήλης.
hud_num:
        ld (hn_x),a
        ld h,b
        ld l,c
        ld de,10000             ; ως 9999
        call cmp_hl_de
        jr c,.ok
        ld hl,9999
.ok:    ld de,hn_d
        ld bc,-1000
        call .dig
        ld bc,-100
        call .dig
        ld bc,-10
        call .dig
        ld a,l
        ld (de),a
        ld hl,hn_d              ; τα μηδενικά μπροστά: κενά
        ld b,3
.z:     ld a,(hl)
        or a
        jr nz,.draw
        ld (hl),10
        inc hl
        djnz .z
.draw:  ld hl,hn_d
        ld c,0                  ; C = στήλη μέσα στον αριθμό
        ld b,4
.g:     push bc
        ld a,(hl)
        push hl
        ld l,a                  ; DE = digits + 10 d
        add a,a
        add a,a
        add a,l
        add a,a
        ld e,a
        ld d,0
        ld hl,digits
        add hl,de
        ex de,hl
        ld a,(hn_x)
        add a,c
        ld (hn_c),a
        ld hl,bar_rows
        ld b,5
.l:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        ld a,(hn_c)
        add a,c
        ld l,a
        ld a,b
        adc a,0
        ld h,a
        ld a,(de)
        ld (hl),a
        inc de
        inc hl
        ld a,(de)
        ld (hl),a
        inc de
        pop hl
        pop bc
        djnz .l
        pop hl
        inc hl
        pop bc
        inc c
        inc c
        djnz .g
        ret
.dig:   ld a,-1                 ; πόσες φορές χωράει το -BC
.d1:    inc a
        add hl,bc
        jr c,.d1
        sbc hl,bc               ; carry 0: πίσω το τελευταίο
        ld (de),a
        inc de
        ret

; Οι 5 γραμμές των ψηφίων στη σελίδα του HUD (διάταξη CRTC με αρχή 0).
bar_rows:
hl_ = BAR_Y
        repeat 5
        dw HUD_PAGE + (hl_ & 7) * #800 + (hl_ >> 3) * 80
hl_ = hl_ + 1
        rend
