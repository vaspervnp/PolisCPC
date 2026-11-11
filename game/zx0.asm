; zx0.asm — αποσυμπιεστής ZX0 (Einar Saukas), η «standard» εκδοχή, 68 bytes.
;
; Τα δεδομένα τα συμπιέζει ο ίδιος ο rasm με το μπλοκ LZX0 ... LZCLOSE,
; οπότε δεν υπάρχει εξωτερικό εργαλείο στο build.
;
;   HL = πηγή (συμπιεσμένα), DE = προορισμός
;
; Χρόνος: ~8 µs ανά byte εξόδου για δεδομένα σαν τον χάρτη.

dzx0:
        ld bc,#FFFF             ; η προηγούμενη μετατόπιση: 1
        push bc
        inc bc
        ld a,#80
.lit:   call .elias             ; μήκος literals
        ldir
        add a,a                 ; από την προηγούμενη μετατόπιση ή νέα;
        jr c,.newoff
        call .elias
.copy:  ex (sp),hl              ; κράτα την πηγή, φέρε τη μετατόπιση
        push hl
        add hl,de
        ldir
        pop hl
        ex (sp),hl
        add a,a
        jr nc,.lit
.newoff:
        pop bc
        ld c,#FE
        call .eloop             ; MSB της μετατόπισης
        inc c
        ret z                   ; τέλος
        ld b,c
        ld c,(hl)
        inc hl
        rr b
        rr c
        push bc
        ld bc,1
        call nc,.back
        inc bc
        jr .copy
.elias: inc c
.eloop: add a,a
        jr nz,.skip
        ld a,(hl)
        inc hl
        rla
.skip:  ret c
.back:  add a,a
        rl c
        rl b
        jr .eloop
