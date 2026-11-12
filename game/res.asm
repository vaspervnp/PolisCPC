; res.asm — οι πόροι του χάρτη (δέντρα, ορυχεία, ψάρια ...) πάνω στο έδαφος. M1.
;
; Κάθε πόρος είναι sprite 8x16 με μάσκα (data/resources.bin, πλεγμένα
; mask,data ανά byte: AND mask, OR data). Πατάει στο πλακίδιό του: το sprite
; αρχίζει στο X του κουτιού του πλακιδίου και 10 γραμμές πάνω από αυτό — ίδια
; τοποθέτηση με το src/mockup.py.
;
; ΣΕΙΡΑ: ο ζωγράφος. Οι σειρές ρόμβων (r = i+j) από πίσω προς τα μπρος· ένα
; δέντρο της σειράς r+1 σκεπάζει όσα είναι πίσω του. Μέσα στην ίδια σειρά τα
; sprites απέχουν 4 bytes και δεν επικαλύπτονται, άρα η σειρά δεν μετράει.
;
; ΨΑΛΙΔΙ: στα όρια του παραθύρου χάρτη, ανά byte οριζόντια και ανά γραμμή
; κάθετα — ένα δέντρο στην άκρη δεν πηδάει, κόβεται.

RES_W       equ 4               ; bytes δεδομένων ανά γραμμή
RES_H       equ 16
RES_SZ      equ 128             ; μάσκα + δεδομένα

; Οι πόροι που πέφτουν στο ΠΑΡΑΘΥΡΟ ΨΑΛΙΔΙΣΜΑΤΟΣ (clip_x0..clip_x1 bytes,
; clip_y0..clip_y1 γραμμές οθόνης). Όλο το παράθυρο χάρτη στην πλήρη σχεδίαση·
; μια στήλη 2 bytes ή μια σειρά 8 γραμμών στην κύλιση (M2).
draw_resources:
        ; πρώτη σειρά: το sprite της r πιάνει τις γραμμές 4r - cam_y - 10
        ; ... +16, άρα r = ((cam_y + clip_y0 - 6) >> 2) + 1
        ld hl,(cam_y)
        ld a,(clip_y0)
        ld e,a
        ld d,0
        add hl,de
        ld de,-6
        add hl,de
        sra h
        rr l
        sra h
        rr l
        inc hl
        ld (var_r),hl
        ld a,(clip_y0)          ; πόσες σειρές: (ύψος + 16) / 4 + 2
        ld b,a
        ld a,(clip_y1)
        sub b
        add a,16
        srl a
        srl a
        add a,2
        ld (rows_left),a

.row:   ld hl,(var_r)           ; τα κτίρια πίσω από αυτή τη σειρά
        call row_flush
        ; k = r + h + clip_x0/2. Το πρώτο πλακίδιο που ακουμπάει το παράθυρο
        ; είναι το i = k >> 1, στο X οθόνης clip_x0 - 2*(k AND 1).
        ld hl,(var_r)
        ld de,(cam_h)
        add hl,de
        ld a,(clip_x0)
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld a,l
        and 1
        add a,a
        ld b,a
        ld a,(clip_x0)
        sub b
        ld (rx),a
        ld b,a                  ; πόσα πλακίδια: (clip_x1 - x + 3) / 4
        ld a,(clip_x1)
        sub b
        add a,3
        srl a
        srl a
        ld (rn),a
        sra h
        rr l
        ld (var_i),hl
        ; y = 4r - cam_y - 10, με +16 ώστε να χωράει σε byte χωρίς πρόσημο
        ld hl,(var_r)
        add hl,hl
        add hl,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld de,16 - 10
        add hl,de
        ld a,h
        or a
        jp nz,.next             ; έξω από την οθόνη κάθετα
        ld a,l
        cp VIEW_H + 16
        jp nc,.next
        ld (ry),a
        ; J = r - i0, ptr = MAP + J*96 + i0
        ld hl,(var_r)
        ld de,(var_i)
        or a
        sbc hl,de
        ld a,l
        ld (rj),a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(var_i)
        add hl,de
        ld de,MAP
        add hl,de
        ld a,(var_i)
        ld b,a                  ; B = I
        ld a,(rj)
        ld c,a                  ; C = J
        ld a,(rx)
        ld ixl,a                ; IXL = X οθόνης του πλακιδίου
        ld a,(rn)
        ld ixh,a                ; IXH = πόσα πλακίδια
        ld de,1-MAPW            ; DE = βήμα (i+1, j-1)
        ; Όλα μέσα στον χάρτη: (I, J) και (I+n-1, J-n+1).
        dec a
        ld (rn),a
        ld a,MAPW
        ld hl,rn
        sub (hl)
        ld l,a                  ; L = 96 - (n-1)
        ld a,b
        cp l
        jr nc,.tile0
        ld a,c
        cp MAPW
        jr nc,.tile0
        ld hl,rn
        cp (hl)
        jr nc,.ftile0
.tile0: call .ptr
.tile:  ld a,b                  ; με ελέγχους ορίων
        cp MAPW
        jr nc,.skip
        ld a,c
        cp MAPW
        jr nc,.skip
        ld a,(hl)
        and #0F
        call nz,res_here
.skip:  inc b
        dec c
        add hl,de
        ld a,ixl
        add a,4
        ld ixl,a
        dec ixh
        jr nz,.tile
        jr .next

.ftile0:
        call .ptr
.ftile: ld a,(hl)               ; χωρίς: όλη η σειρά είναι μέσα
        and #0F
        call nz,res_here
        add hl,de
        ld a,ixl
        add a,4
        ld ixl,a
        dec ixh
        jr nz,.ftile

.next:  ld hl,(var_r)
        inc hl
        ld (var_r),hl
        ld a,(rows_left)
        dec a
        ld (rows_left),a
        jp nz,.row
        ret

; HL = ο δείκτης του χάρτη για το (var_i, rj) — ξαναϋπολογίζεται γιατί ο
; έλεγχος από πάνω χάλασε το HL.
.ptr:   push de
        ld a,(rj)
        ld l,a
        ld a,(rj)
        rlca
        sbc a,a
        ld h,a                  ; J με πρόσημο
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(var_i)
        add hl,de
        ld de,MAP
        add hl,de
        pop de
        ret

; Πόρος A στο πλακίδιο του σαρωτή: X από το IXL. Κρατάει BC, DE, HL, IX.
res_here:
        cp BLD_RES              ; πλακίδιο κτιρίου (M7): κανένα sprite
        ret z
        push bc
        push de
        push hl
        ld b,a
        call fog_hl             ; ανεξερεύνητο (M11): κανένα (HL = ο χάρτης)
        jr z,.out
        ld a,ixl
        ld (rx),a
        ld a,b
        call blit_res
.out:   pop hl
        pop de
        pop bc
        ret

; A = γραμμή οθόνης 0..143, B = byte 0..79 -> DE = η διεύθυνσή τους, με
; τύλιγμα στα 2 KB (με την κύλιση η γραμμή μπορεί να σπάει).
line_x: ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,b
        add a,e
        ld e,a
        ret nc
        jp de_carry

; A = πόρος (1-15), (rx) = X οθόνης σε bytes (προσημασμένο), (ry) = Y + 16.
; Ψαλίδι στο παράθυρο clip_*.
blit_res:
        ; sprite = res_gfx + (A-1)*128
        dec a
        rrca                    ; *128 = >> 1 με το bit 0 στο 7
        ld e,a
        and #7F
        ld d,a
        ld a,e
        and #80
        ld e,a
        ld hl,res_gfx
        add hl,de
        ld (b_src),hl

        ; Με +8 στο X και +16 στο Y όλα χωράνε σε bytes χωρίς πρόσημο.
        ; c0 = max(0, clip_x0 - x), c1 = min(4, clip_x1 - x)
        ld a,(rx)
        add a,8
        ld d,a                  ; D = x + 8
        ld a,(clip_x0)
        add a,8
        sub d
        jr nc,.c0
        xor a
.c0:    ld (b_c0),a
        cp RES_W
        ret nc
        ld a,(clip_x1)
        add a,8
        sub d                   ; clip_x1 - x
        ret c
        ret z
        cp RES_W
        jr c,.c1
        ld a,RES_W
.c1:    ld hl,b_c0
        sub (hl)
        ret z
        ret c
        ld (b_n),a
        ; l0 = max(0, clip_y0 - y), l1 = min(16, clip_y1 - y)
        ld a,(ry)
        ld d,a                  ; D = y + 16
        ld a,(clip_y0)
        add a,16
        sub d
        jr nc,.l0
        xor a
.l0:    ld (b_l0),a
        cp RES_H
        ret nc
        ld a,(clip_y1)
        add a,16
        sub d
        ret c
        ret z
        cp RES_H
        jr c,.l1
        ld a,RES_H
.l1:    ld hl,b_l0
        sub (hl)
        ret z
        ret c
        ld (b_lines),a

        ; Ολόκληρο μέσα; Τότε χωρίς ψαλίδι, ξετυλιγμένο — η συνηθισμένη
        ; περίπτωση στην πλήρη σχεδίαση.
        cp RES_H
        jr nz,.clip
        ld a,(b_n)
        cp RES_W
        jr nz,.clip
        ld a,(ry)
        sub 16
        ld hl,rx
        ld b,(hl)
        call line_x
        ld hl,(b_src)
        jp blit16

.clip:  ; πρώτη γραμμή οθόνης: y + l0· πηγή: + l0*8 + c0*2
        ld a,(ry)
        sub 16
        ld hl,b_l0
        add a,(hl)
        ld (b_y),a
        ld a,(b_l0)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(b_c0)
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,(b_src)
        add hl,de
        ld (b_src),hl
        ; ΚΟΜΜΕΝΟ ΜΟΝΟ ΚΑΘΕΤΑ, ΜΕΣΑ ΣΕ ΜΙΑ ΣΕΙΡΑ ΧΑΡΑΚΤΗΡΩΝ (η σειρά 8 γραμμών
        ; της κάθετης κύλισης): όλα τα 4 bytes, και η επόμενη γραμμή είναι
        ; D + 8 — χωρίς line_x ανά γραμμή.
        ld a,(b_n)
        cp RES_W
        jr nz,.line
        ld a,(b_y)
        and 7
        ld c,a
        ld a,(b_lines)
        add a,c
        cp 9
        jr nc,.line
        ld a,(rx)
        ld b,a
        ld a,(b_y)
        call line_x
        ld a,e
        cp #FD                  ; τα 4 bytes περνάνε όριο σελίδας: αργά
        jr nc,.line
        ld c,e
        ld hl,(b_src)
        ld a,(b_lines)
        ld b,a
.row:   ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        ld e,c
        ld a,d
        add a,8
        ld d,a
        djnz .row
        ret

.line:  ld a,(rx)               ; DE = line_addr[y] + x + c0
        ld hl,b_c0
        add a,(hl)
        ld b,a
        ld a,(b_y)
        call line_x
        ld hl,(b_src)
        ld a,(b_n)
        ld b,a
.byte:  ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc e
        call z,de_carry
        djnz .byte
        ld hl,(b_src)
        ld de,RES_W * 2
        add hl,de
        ld (b_src),hl
        ld hl,b_y
        inc (hl)
        ld hl,b_lines
        dec (hl)
        jr nz,.line
        ret

; ----------------------------------------------------------------
; Η ΕΠΟΜΕΝΗ ΣΕΙΡΑ ΧΑΡΑΚΤΗΡΩΝ, με την κύλιση
;
; Μέσα στη σειρά η επόμενη γραμμή είναι +#800 και το low byte δεν αλλάζει.
; Στο τέλος της σειράς (μετά τη γραμμή 7, το D «ξεχείλισε» στο +8): +80 στη
; μετατόπιση, ΤΥΛΙΓΜΕΝΗ στα 2 KB (με την κύλιση η σειρά μπορεί να συνεχίζει
; από την αρχή της οκτάδας), στη γραμμή 0 της σελίδας #C000.

; ----------------------------------------------------------------
; Sprite 8x16 με μάσκα, ολόκληρο μέσα στην οθόνη, χωρίς ψαλίδι.
; HL = πηγή, ΣΤΟΙΧΙΣΜΕΝΗ στα 128 (`inc l` σε όλο το sprite), DE = byte
; οθόνης. Το μοιράζονται πόροι και μονάδες. ~0,75 ms.
;
; ΣΕ ΖΕΥΓΑΡΙΑ ΓΡΑΜΜΩΝ: 8 φορές 2 γραμμές (ήταν ξετυλιγμένο σε 16· τα ~470
; bytes πήγαν στις μονάδες πίσω από κτίρια, M7). Ανάμεσα στις γραμμές μόνο
; `call z` για την αλλαγή σειράς χαρακτήρων — 3 NOPs όταν δεν γίνεται. Αν τα
; 4 bytes μιας γραμμής περνάνε όριο σελίδας (E ≥ #FD), το `inc e` δεν
; φτάνει: ελέγχεται στην αρχή και σε κάθε αλλαγή σειράς, και ΜΟΝΟ οι γραμμές
; που μένουν πάνε από την αργή διαδρομή (το bwrap πετάει τον βρόχο).
;
; (Δοκιμάστηκε και ξετύλιγμα με είσοδο ανά σειρά: οι γραμμές κέρδισαν 3 ms
; στα 16 sprites, η επιλογή εισόδου έφαγε 7. Πετάχτηκε.)
blit16:
        ld a,e
        cp #FD
        ld b,16
        jp nc,blit_slow
        ld c,e
        ld b,8
.l:
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        ld e,c
        ld a,d
        add a,#08
        ld d,a
        and #38
        call z,bwrap
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        ld e,c
        dec b
        ret z
        ld a,d
        add a,#08
        ld d,a
        and #38
        call z,bwrap
        jr .l

; Το blit16 για την ομάδα 1 (units_draw): το byte δεδομένων περνάει από τον
; πίνακα TR1 της C5 (τα pens της ομάδας -> τα δικά της, src/make_edges.py).
; HL = καρέ (στοιχισμένο), DE = οθόνη, όποια θέση: κάθε byte με de_carry.
; ~1,3 ms (το blit16 0,8).
        macro BT1
        inc l
        ld c,(hl)
        ld a,(bc)
        ld c,a
        dec l
        ld a,(de)
        and (hl)
        or c
        ld (de),a
        inc l
        inc l
        inc e
        call z,de_carry
        mend
blit16t:
        ld b,TR1 >> 8
        ld a,16
.r:     push af
        push de
        BT1
        BT1
        BT1
        BT1
        pop de
        ld a,d
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        pop af
        dec a
        jr nz,.r
        ret

; Αλλαγή σειράς στο blit16: +80 τυλιγμένο στα 2 KB. Αν η νέα σειρά περνάει
; όριο σελίδας, οι γραμμές που μένουν (από το L: 8 bytes ανά γραμμή) πάνε
; στην αργή διαδρομή, και ο βρόχος εγκαταλείπεται.
bwrap:  ld a,c
        add a,80
        ld c,a
        ld e,a
        ld a,d
        adc a,0
        and 7
        or #C0
        ld d,a
        ld a,e
        cp #FD
        ret c
        pop af                  ; όχι πίσω στον βρόχο
        ld a,l
        and #7F
        rrca
        rrca
        rrca
        neg
        add a,16
        ld b,a

; Η αργή διαδρομή, B γραμμές. Μια γραμμή που περνάει όριο σελίδας θέλει απλώς
; 16-bit `inc de` — εκτός αν το όριο είναι και όριο 2 KB (D AND 7 = 7), όπου
; η γραμμή συνεχίζει από την αρχή της οκτάδας. Αυτό το δεύτερο γίνεται σε
; ΜΙΑ σειρά χαρακτήρων μόνο, όταν η κύλιση την έχει σπάσει.
blit_slow:
.l:     push de
        ld a,d
        and 7
        cp 7
        jr z,.k2
        repeat 3
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc de
        rend
        jr .last
.k2:    repeat 3
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        call z,de_carry
        rend
.last:  ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        pop de
        ld a,d
        add a,#08
        ld d,a
        and #38
        call z,next_row_de
        djnz .l
        ret

; DE = byte οθόνης. 4 bytes x 16 γραμμές από τον καθρέφτη (C4 στο #4000),
; που έχει την ΙΔΙΑ διάταξη: η πηγή είναι το DE με το bit 15 σβηστό.
; Ξετυλιγμένο όπως το blit16. ~0,55 ms.
;
; Το B μετράει γραμμές· το C είναι μεγάλο ώστε τα 64 LDI να μη δανειστούν
; ποτέ από το B.
restore16:
        ld bc,#10FF
        ld a,e
        cp #FC                  ; τα 4 LDI πάνε το DE ως +4: ≤ #FF
        jp nc,restore_slow
        repeat 15
        ld h,d
        ld l,e
        res 7,h
        ldi
        ldi
        ldi
        ldi
        dec b
        ld a,e
        sub 4
        ld e,a
        ld a,d
        add a,#08
        ld d,a
        and #38
        call z,rwrap
        rend
        ld h,d
        ld l,e
        res 7,h
        ldi
        ldi
        ldi
        ldi
        ret

rwrap:  ld a,e
        add a,80
        ld e,a
        ld a,d
        adc a,0
        and 7
        or #C0
        ld d,a
        ld a,e
        cp #FC
        ret c
        pop af                  ; οι B γραμμές που μένουν: αργά

restore_slow:
.l:     push de
        ld a,d
        and 7
        cp 7
        jr z,.k2
        ld h,d
        ld l,e
        res 7,h
        ldi                     ; απλό όριο σελίδας: τα LDI το περνάνε σωστά
        ldi                     ; (το C είναι ≥ 4: τα LDI δεν αγγίζουν το B)
        ldi
        ldi
        jr .next
.k2:    repeat 4
        ld h,d
        ld l,e
        res 7,h
        ld a,(hl)
        ld (de),a
        inc e
        call z,de_carry
        rend
.next:  pop de
        ld a,d
        add a,#08
        ld d,a
        and #38
        call z,next_row_de
        djnz .l
        ret

; Το E μόλις έγινε 0: D+1, τυλιγμένο στα 2 KB της οκτάδας.
de_carry:
        inc d
        ld a,d
        and 7
        ret nz
        ld a,d
        sub 8
        ld d,a
        ret

; DE + 1 μέσα στη μνήμη οθόνης: στο όριο των 2 KB τυλίγεται στην αρχή της
; ίδιας οκτάδας (η κύλιση μπορεί να σπάει μια γραμμή εκεί).
inc_de_scr:
        inc de
        ld a,e
        or a
        ret nz
        ld a,d
        and 7
        ret nz
        ld a,d
        sub 8
        ld d,a
        ret

; DE = η γραμμή από κάτω, με τύλιγμα στα 2 KB.
next_line_de:
        ld a,d
        add a,#08
        ld d,a
        and #38
        ret nz
; Το D μόλις ξεχείλισε (τέλος σειράς): +80, τυλιγμένο στα 2 KB.
next_row_de:
        ld a,e
        add a,80
        ld e,a
        ld a,d
        adc a,0
        and 7
        or #C0
        ld d,a
        ret
