; disk.asm — ο οδηγός του FDC (uPD765) για το φόρτωμα αρχείων (M9).
;
; Το firmware είναι κλειστό (main.asm), άρα και η AMSDOS: ο δικός μας
; οδηγός μιλάει κατευθείαν στο FDC. Διαβάζει ΜΟΝΟ: τον κατάλογο (τροχιά 0,
; τομέας #C1: οι 16 πρώτες εγγραφές) και τα blocks ενός αρχείου, σε μορφή
; DATA (40 τροχιές x 9 τομείς #C1-#C9 των 512 bytes· block b = οι λογικοί
; τομείς 2b, 2b + 1· λογικός τομέας L = τροχιά L / 9, τομέας #C1 + L mod 9).
; Ένα extent (ως 16 KB).
;
; Στην ΟΘΟΝΗ (LOAD_AT, M13): τα αρχεία (src/dsk.py) είναι χωρίς κεφαλίδα
; AMSDOS και συμπιεσμένα ZX0· όποιος τα φορτώνει τα αποσυμπιέζει από εκεί
; στη θέση τους (age_load), και η οθόνη ξαναζωγραφίζεται. Κάθε block
; ολόκληρο, ως 16 (ένα extent).

        include "../data/age3.asm"      ; AGE_AT, AGE_TAB_LEN, cult_let
        include "../data/level.asm"     ; η κεφαλίδα της πίστας (M13): H_*
LV_HDR      equ BLD_TAB         ; εκεί την αφήνει το μενού (menu.asm)

FDC_MSR     equ #FB7E           ; κατάσταση (με το B = #FB)
MOTOR       equ #FA7E
LOAD_AT     equ SCREEN          ; (M13: συμπιεσμένα, χωρίς κεφαλίδα — src/dsk.py)


; HL = όνομα (11 χαρακτήρες) -> το αρχείο στη C6 στο LOAD_AT. Carry αν δεν
; βρέθηκε. Επιστρέφει με την C0 και τις διακοπές ανοιχτές.
disk_load:
        push hl
        ld bc,MOTOR
        ld a,1
        out (c),a
        ei                      ; ~0,5 s να γυρίσει ο δίσκος
        ld a,(int_t)
        ld c,a
.sp:    ld a,(int_t)
        sub c
        cp 150
        jr c,.sp
        ld a,3                  ; specify: χωρίς DMA (όπως η AMSDOS)
        call fdc_out
        ld a,#A1
        call fdc_out
        ld a,3
        call fdc_out
        ld a,7                  ; recalibrate: τροχιά 0
        call fdc_out
        xor a
        call fdc_out
        call fdc_sense
        ld de,#00C1             ; ο κατάλογος: 4 τομείς, 64 εγγραφές (M12:
        ld hl,LOAD_AT           ; 16 αρχεία εποχών, το SAVE.BIN)
.dir:   push de
        call fdc_read
        pop de
        inc e
        ld a,e
        cp #C5
        jr c,.dir
        pop de                  ; DE = το όνομα
        ld hl,LOAD_AT
        ld b,64
.e:     push bc
        push de
        push hl
        ld a,(hl)               ; χρήστης 0
        or a
        jr nz,.no
        ld b,11
.c:     inc hl
        ld a,(de)
        xor (hl)
        and #7F
        jr nz,.no
        inc de
        djnz .c
        inc hl                  ; extent 0
        ld a,(hl)
        or a
        jr nz,.no
        pop hl
        pop de
        pop bc
        ld de,16                ; τα blocks του
        add hl,de
        ld de,dk_blk
        ld bc,16
        ldir
        jr .rd
.no:    pop hl
        ld bc,32                ; (όχι DE: είναι το όνομα)
        add hl,bc
        pop de
        pop bc
        djnz .e
        scf
        jr .off
.rd:    push ix
        ld hl,LOAD_AT
        ld ix,dk_blk
        ld b,16
.b:     ld a,(ix+0)
        or a
        jr z,.ok
        ld c,0                  ; L = 2 b, 2 b + 1
        call .sec
        inc c
        call .sec
        inc ix
        djnz .b
.ok:    pop ix
        or a
.off:   push af
        ld bc,MOTOR
        xor a
        out (c),a
        ld a,RAM_BASE
        call setram
        pop af
        ei
        ret
.sec:   push af                 ; ο λογικός τομέας 2 A + C -> HL, HL += 512
        push bc                 ; (16 bits: τα blocks φτάνουν ως το 179, M12)
        push hl
        ld l,a
        ld h,0
        add hl,hl
        ld b,h
        add hl,bc
        call l_ts
        pop hl
        call fdc_read
        pop bc
        pop af
        ret

; HL = λογικός τομέας (< 360) -> D = τροχιά, E = τομέας (#C1-#C9).
l_ts:   ld de,-9
        ld b,-1
.dv:    inc b
        add hl,de
        jr c,.dv
        ld a,l
        add a,#C1 + 9
        ld e,a
        ld d,b
        ret

; A -> το FDC (φάση εντολής). Κρατάει όλα εκτός από τις σημαίες.
fdc_out:
        push bc
        push af
        ld bc,FDC_MSR
.w:     in a,(c)
        add a,a                 ; RQM
        jr nc,.w
        pop af
        inc c
        out (c),a
        pop bc
        ret

; Η φάση αποτελέσματος -> dk_res (ως 7 bytes).
fdc_in: ld hl,dk_res
        ld bc,FDC_MSR
.w:     in a,(c)
        add a,a                 ; RQM
        jr nc,.w
        add a,a                 ; DIO: 0 = τέλος
        ret nc
        inc c
        in a,(c)
        dec c
        ld (hl),a
        inc hl
        jr .w

; Sense interrupt ώσπου να τελειώσει η αναζήτηση (ST0: SE).
fdc_sense:
        ld a,8
        call fdc_out
        call fdc_in
        ld a,(dk_res)
        and #20
        jr z,fdc_sense
        ret

; D = τροχιά, E = τομέας: 512 bytes στο HL (και HL += 512). Ως 3 φορές
; αν το FDC δώσει σφάλμα (ST1: MA ND OR DE, ST2: MD BC WC DD — όχι το EN,
; που το CPC το παίρνει πάντα: δεν έχει γραμμή TC). Και μετά, προχωράει.
fdc_read:
        ld b,3
.tr:    push bc
        push de
        push hl
        call fdc_rd1
        ld a,(dk_res + 1)
        and #37
        ld c,a
        ld a,(dk_res + 2)
        and #33
        or c
        pop bc                  ; (το HL της αρχής)
        pop de
        jr z,.ok
        ld h,b
        ld l,c
        pop bc
        djnz .tr
        inc h                   ; τρεις φορές: το επόμενο, στη θέση του
        inc h
        ret
.ok:    pop bc
        ret

fdc_rd1:
        ld a,#0F                ; seek
        call fdc_out
        xor a
        call fdc_out
        ld a,d
        call fdc_out
        push hl
        call fdc_sense
        pop hl
        di
        ld a,#46                ; read data (MFM)
        call fdc_out
        xor a                   ; δίσκος 0, κεφαλή 0
        call fdc_out
        ld a,d                  ; C
        call fdc_out
        xor a                   ; H
        call fdc_out
        ld a,e                  ; R
        call fdc_out
        ld a,2                  ; N: 512
        call fdc_out
        ld a,e                  ; EOT: μόνο αυτός
        call fdc_out
        ld a,#2A                ; GPL
        call fdc_out
        ld a,#FF                ; DTL
        call fdc_out
        ld bc,FDC_MSR           ; φάση εκτέλεσης: 512 bytes, ένα σε κάθε
        ld de,512               ; RQM (όχι με το EXM: δεν το δίνουν όλα τα
.r:     in a,(c)                ; FDC / οι emulators) — 24 µs, < 32
        jp p,.r
        inc c
        in a,(c)
        ld (hl),a
        dec c
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.r
        push hl
        call fdc_in
        pop hl
        ei
        ret

; Τα ονόματα: το 5ο γράμμα του AGE3/AGE4 είναι ο πολιτισμός (το μενού το
; αλλάζει, M12· και σώζεται με την παρτίδα).
age3_name:  db "AGE3G   BIN"
hopl_name:  db "HOPL    BIN"
age4_name:  db "AGE4G   BIN"
