; ugfx.asm — τα γραφικά των μονάδων στις τράπεζες, ΜΟΝΟ στην εκκίνηση (M12:
; από την κύρια RAM εδώ, για χώρο). Συναρμολογημένο για το UGFX (#B000, οι
; εγγραφές των μονάδων, που το units_init τις γράφει μετά), ταξιδεύει στο
; POLIS.BIN, και το `start` το αντιγράφει εκεί πριν το καλέσει. Όχι στην
; οθόνη (όπως το init.asm): τη χρησιμοποιεί όλη ως ενδιάμεσο χώρο.

; Στην εκκίνηση: τα σετ στην C5 (αποσυμπίεση στην οθόνη, με την C0, και
; αντιγραφή από εκεί: η πηγή μπορεί να είναι στο #4000), οι όψεις W από τις
; E με καθρέφτισμα, και τα sprites του κέρσορα.
units_gfx:
        call make_swap
        ld ix,spr_tab
        ld de,SPR_BASE
        ld b,SPR_SETS - 1
.set:   push bc
        push de
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix
        inc ix
        ld de,SCREEN
        call dzx0
        ld a,RAM_SPR
        call setram
        pop de
        push de
        ld hl,SCREEN
        ld bc,SPR_WEST          ; 21 καρέ x 128
        ldir
        pop de
        push hl
        ; W: τα 4 καρέ βαδίσματος E (4..7) καθρεφτισμένα στο SPR_WEST
        ld hl,4 * 128
        add hl,de
        push de
        ex de,hl                ; DE = E0
        ld hl,SPR_WEST
        pop bc
        push bc
        add hl,bc
        ex de,hl                ; HL = E0, DE = W0
        ld b,4 * 16             ; 4 καρέ x 16 γραμμές
.line:  call mirror_line
        djnz .line
        pop de
        ld hl,SPR_STRIDE
        add hl,de
        ex de,hl
        ld a,RAM_BASE
        call setram
        pop hl
        pop bc
        djnz .set
        ld hl,cursor_gfx        ; ο κέρσορας: μέσω της οθόνης (η πηγή είναι
        ld de,SCREEN            ; πέρα από το #4000, κάτω από την C5) — και
        call dzx0               ; τα περιγράμματα (occlude.asm)
        ld a,RAM_SPR
        call setram
        ld hl,SCREEN
        ld de,SPR_CURSOR
        ld bc,C5_TAIL
        ldir
        ld a,RAM_BASE           ; οι πόροι -> C6
        call setram
        ld hl,res_z
        ld de,SCREEN
        call dzx0
        ld a,RAM_RES
        call setram
        ld hl,SCREEN
        ld de,#4000
        ld bc,#4000
        ldir
        ld a,RAM_BASE           ; τα μεταγλωττισμένα -> C7, μέσω της οθόνης
        call setram
        ld hl,cmp_z
        ld de,SCREEN
        call dzx0
        ld hl,c7_phys           ; και ο κώδικας της C7 (bank7.asm) μετά τα
        ld de,SCREEN + C7_CODE - #4000  ; sprites
        ld bc,C7_LEN
        ldir
        ld a,RAM_CMP
        call setram
        ld hl,SCREEN
        ld de,#4000
        ld bc,#4000
        ldir
        ld a,RAM_BASE
        jp setram

; Μία γραμμή sprite (8 bytes: 4 x μάσκα,δεδομένα) από HL σε DE, ανάποδα:
; τα ζεύγη σε αντίστροφη σειρά και τα δύο pixels κάθε byte ανταλλαγμένα.
; HL, DE προχωράνε 8.
mirror_line:
        push bc
        ld bc,6
        ex de,hl
        add hl,bc               ; DE: το τελευταίο ζεύγος του προορισμού
        ex de,hl
        ld b,4
.p:     ld a,(hl)               ; μάσκα
        call swap_a
        ld (de),a
        inc hl
        inc de
        ld a,(hl)               ; δεδομένα
        call swap_a
        ld (de),a
        inc hl
        dec de
        dec de
        dec de
        djnz .p
        ex de,hl                ; DE από -2 πάει στο +8
        ld bc,10
        add hl,bc
        ex de,hl
        pop bc
        ret

swap_a: push hl
        ld l,a
        ld h,SWAP_TAB >> 8
        ld a,(hl)
        pop hl
        ret
