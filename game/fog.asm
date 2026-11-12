; fog.asm — ο εξερευνημένος χάρτης. M11.
;
; ΕΝΑ BIT ΑΝΑ ΠΛΑΚΙΔΙΟ, στην τράπεζα C6 (FOG, 96 x 12 bytes): εκεί που
; είναι και τα πλακίδια του εδάφους, άρα το βλέπει όποιος ζωγραφίζει. Το
; πλακίδιο (i, j) είναι το bit (i AND 7) του byte FOG + 12 j + i / 8 — δηλαδή
; το bit (δείκτης χάρτη - MAP): το 96 διαιρείται με το 8.
;
; ΑΝΕΞΕΡΕΥΝΗΤΟ = ΜΑΥΡΟ, όπως το έξω από τον χάρτη: χωρίς έδαφος, πόρο ή
; κτίριο. Στους βρόχους του εδάφους (ground.asm) ο έλεγχος είναι ένας
; δείκτης που προχωράει μαζί με το πλακίδιο (IY = το byte, IXH = το bit)·
; στα υπόλοιπα (μισά στοιχεία, στήλες, πόροι, κτίρια) το fog_hl.
;
; ΑΠΟΚΑΛΥΨΗ: όταν μια μονάδα του παίκτη αλλάζει πλακίδιο (bucket_update), το
; τετράγωνο FOG_R γύρω της (fog_reveal). Δεν ξεχνιέται ποτέ. Όσα νέα
; πλακίδια φαίνονται ξαναζωγραφίζονται στήλη-στήλη (fog_dirty, fog_step).

FOG         equ #5F80           ; C6: μετά τις εικόνες της εποχής
FOG_LEN     equ MAPW * MAPW / 8
FOG_R       equ 4               ; πλακίδια γύρω από τη μονάδα
FD_TAB      equ #AD60           ; FD_N x (wx, y0, y1: dw): στήλες προς
FD_N        equ 26              ; επανασχεδίαση (μετά το buffer γραμμής
        assert FD_TAB >= BUF_A + #800 + 80 && FD_TAB + FD_N * 6 <= UNIT_TAB, 'FD_TAB'
FOG_T       equ 5               ; 1/300 s από την αρχή του καρέ: ως εκεί
        assert FOG + FOG_LEN <= CMP_RED, 'FOG over CMP_RED'

; HL = δείκτης χάρτη -> NZ αν το πλακίδιο είναι εξερευνημένο (με την C6
; μέσα). Κρατάει BC, DE, HL.
fog_hl: push hl
        push bc
        ld a,l
        and 7
        ld c,a
        ld a,h
        and #7F                 ; - MAP
        srl a
        rr l
        srl a
        rr l
        srl a
        rr l
        ld h,a
        ld a,l
        add a,FOG & 255
        ld l,a
        ld a,h
        adc a,FOG >> 8
        ld h,a
        ld a,c
        add a,fog_bit & 255
        ld c,a
        ld b,fog_bit >> 8
        ld a,(bc)
        and (hl)
        pop bc
        pop hl
        ret

fog_bit:    db 1, 2, 4, 8, 16, 32, 64, 128
        assert (fog_bit & 255) <= 248, 'fog_bit: one page'

; B = i, C = j (με πρόσημο: στο παράθυρο |i|, |j| < 128) -> IY = το byte του
; στο FOG, IXH = το bit του (και έξω από τον χάρτη: συνεπές βήμα). Κρατάει
; BC, DE, HL.
fog_iy: push hl
        push de
        ld a,c
        ld l,a
        rla
        sbc a,a
        ld h,a                  ; HL = j
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; 12 j
        ld a,b
        sra a
        sra a
        sra a
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de               ; + i / 8
        ld de,FOG
        add hl,de
        push hl
        pop iy
        ld a,b
        and 7
        add a,fog_bit & 255
        ld l,a
        ld h,fog_bit >> 8
        ld a,(hl)
        ld ixh,a
        pop de
        pop hl
        ret

; IY = κτίριο -> NZ αν το μπροστινό του πλακίδιο είναι εξερευνημένο (με την
; C6 μέσα). Κρατάει BC, IY.
bld_fog:
        ld a,(iy+B_TYPE)
        call bt_hl
        ld a,(hl)
        dec a
        ld e,a
        add a,(iy+B_I)
        ld d,a
        ld a,e
        add a,(iy+B_J)
        ld e,a
        push bc
        call map_ptr
        pop bc
        jp fog_hl

; ------------------------------------------------------------ αποκάλυψη

; D = i, E = j (0..95) -> HL = το byte του στο FOG, A = το bit του.
fog_at: ld l,e
        ld h,0
        add hl,hl
        add hl,hl
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc               ; 12 j
        ld a,d
        rrca
        rrca
        rrca
        and 31
        ld c,a
        ld b,0
        add hl,bc
        ld bc,FOG
        add hl,bc
        ld a,d
        and 7
        add a,fog_bit & 255
        ld c,a
        ld b,fog_bit >> 8
        ld a,(bc)
        ret

; D = i, E = j (0..95): το τετράγωνο ±FOG_R γύρω του εξερευνημένο. Όσα
; πλακίδια ήταν ανεξερεύνητα: fog_new (bank7.asm). Από κώδικα με την C0
; (βάζει την C6 και γυρίζει στην C0). Κρατάει IX, IY.
fog_reveal:
        ld a,RAM_RES
        call setram
        ld a,e                  ; οι γραμμές j0..j1, οι στήλες i0..i1
        sub FOG_R
        jr nc,.j0
        xor a
.j0:    ld (fr_j),a
        ld a,e
        add a,FOG_R
        cp MAPW
        jr c,.j1
        ld a,MAPW - 1
.j1:    ld (fr_j1),a
        ld a,d
        sub FOG_R
        jr nc,.i0
        xor a
.i0:    ld (fr_i0),a
        ld a,d
        add a,FOG_R
        cp MAPW
        jr c,.i1
        ld a,MAPW - 1
.i1:    ld (fr_i1),a
.row:   ld a,(fr_i0)
        ld d,a
        ld a,(fr_j)
        ld e,a
        call fog_at
        ld c,a
        ld a,(fr_i1)
        sub d
        inc a
        ld b,a
.t:     ld a,(hl)
        and c
        jr nz,.old
        ld a,(hl)
        or c
        ld (hl),a
        push bc                 ; νέο: στο FD_TAB (bank7.asm), και πίσω
        push de                 ; στην C6
        push hl
        ld hl,fog_new
        call far7
        ld a,RAM_RES
        call setram
        pop hl
        pop de
        pop bc
.old:   inc d
        rlc c
        jr nc,.n
        inc hl
.n:     djnz .t
        ld a,(fr_j)
        ld hl,fr_j1
        cp (hl)
        inc a
        ld (fr_j),a
        jr c,.row
        ld a,RAM_BASE
        jp setram

; Το col_redraw της στήλης fd_c (από την C7, με το call0: χαλάει το A).
fd_draw:
        ld a,(fd_c)
        jp col_redraw

; IX = μονάδα, (n_i, n_j) = το πλακίδιό της: fog_reveal γύρω της.
unit_reveal:
        ld a,(fog_on)           ; χωρίς ομίχλη: όλα ήδη εξερευνημένα
        or a
        ret z
        ld hl,(n_i)
        call clamp95
        ld d,a
        ld hl,(n_j)
        call clamp95
        ld e,a
        jp fog_reveal

; IX -> NZ αν φαίνεται: του παίκτη, ή τα πόδια της σε εξερευνημένο
; πλακίδιο. Από κώδικα με την C0. Κρατάει IX, IY (και τα n_i, n_j).
unit_fog:
        ld a,(fog_on)
        or a
        jr z,.yes
        ld a,(ix+U_TEAM)
        or a
        jr z,.yes
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        inc hl
        inc hl
        ld e,(ix+U_WY)
        ld d,(ix+U_WY+1)
        push hl
        ld hl,14
        add hl,de
        ex de,hl
        pop hl
        call feet_tile          ; HL = i, DE = j
        ld a,h                  ; έξω από τον χάρτη: όχι
        or d
        jr nz,.no
        ld a,l
        cp MAPW
        jr nc,.no
        ld a,e
        cp MAPW
        jr nc,.no
        ld d,l
        call fog_at
        ld c,a
        ld a,RAM_RES
        call setram
        ld a,(hl)
        and c
        push af
        ld a,RAM_BASE
        call setram
        pop af
        ret
.no:    xor a
        ret
.yes:   or 1
        ret
