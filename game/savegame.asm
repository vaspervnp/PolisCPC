; savegame.asm — αποθήκευση και φόρτωμα της παρτίδας στη δισκέτα. M12.
;
; ΤΡΕΧΕΙ ΑΠΟ ΤΗΝ ΟΘΟΝΗ (SVM, #C000): αλλάζει ελεύθερα την τράπεζα στο
; #4000 — η σελίδα του HUD, η C7, η C6 — χωρίς να χάνει τον εαυτό του. Ο
; buffer του τομέα και ο κατάλογος επίσης στην οθόνη (SVM_BUF). Μετά, η
; οθόνη θέλει πλήρη επανασχεδίαση (redraw). Ταξιδεύει μαζί με το INIT
; (main.asm), και το init το φυλάει στις κρυφές σειρές της σελίδας του HUD
; (SVM_STORE): από εκεί το save_go το φέρνει στην οθόνη στη μέση της
; παρτίδας.
;
; ΤΟ ΑΡΧΕΙΟ: το SAVE.BIN, που το build.sh το βάζει άδειο στη δισκέτα
; (src/dsk.py, SAVE_FILE bytes, χωρίς κεφαλίδα). Ο οδηγός του γράφει πάνω
; στα blocks του, με τη σειρά των extents στον κατάλογο. Μέσα, ένα ρεύμα από
; κομμάτια μνήμης (sv_seg), συνεχόμενα, σε τομείς των 512:
;
;   η υπογραφή (sv_sig: χωρίς αυτή το φόρτωμα δεν αγγίζει τίποτα)
;   οι μεταβλητές της κύριας RAM, από τα ονόματα των αρχείων (ο πολιτισμός)
;   η σελίδα του HUD (#4000-#7FFF): οι αριθμοί, οι πίνακες, οι χωρικοί
;   #8000-#BEFF: ο χάρτης, οι μονάδες, τα κτίρια (όχι η στοίβα)
;   η C7 από το C7_CODE: η κατάσταση της μάχης, του αντιπάλου, των ερευνών
;   η ομίχλη (C6)
;
; Ό,τι λείπει ξαναχτίζεται: η οθόνη και ο καθρέφτης (redraw), οι εικόνες
; της εποχής και ο οπλίτης (από τη δισκέτα, load_cont στο init.asm).

; (SVM, SVM_BUF: main.asm, πριν από το org)
SVM_STORE   equ HUD_PAGE + #800 + 7 * 80    ; οι κρυφές σειρές της 2ης οκτάδας
SAVE_M0     equ age3_name       ; οι μεταβλητές της κύριας RAM: ως το #4000
STACK_LOW   equ #BF00           ; ό,τι είναι πάνω είναι η στοίβα
        assert BLD_TAB2 + (BLD_MAX - BLD_N1) * B_SIZE <= STACK_LOW, 'STACK_LOW'
SAVE_FILE   equ 43008           ; το SAVE.BIN στη δισκέτα (build.sh): 42 blocks
SV_EXT      equ 3               ; τα extents του (16 blocks το καθένα)

; Η αποθήκευση: όλο το ρεύμα στη δισκέτα. Carry αν δεν βρέθηκε το αρχείο.
mod_save:
        call sv_open
        ret c
        ld hl,SVM_BUF + 2048    ; ο buffer ως άδειος
        ld (sv_p),hl
        ld ix,sv_seg
.seg:   ld a,(ix+0)
        or a
        jr z,.last
        call sv_bank
        ld l,(ix+1)
        ld h,(ix+2)
        ld c,(ix+3)
        ld b,(ix+4)
.chunk: ld a,b                  ; HL = από, BC = πόσα μένουν
        or c
        jr z,.next
        push bc
        call sv_room            ; DE = ο buffer, BC = min(πόσα, χώρος)
        ex (sp),hl              ; (sp) = από, HL = πόσα μένουν
        or a
        sbc hl,bc
        ex (sp),hl              ; (sp) = πόσα μένουν μετά
        ldir
        ld (sv_p),de
        ld a,d                  ; γέμισε: στη δισκέτα
        cp (SVM_BUF + 2048 + 512) >> 8
        call z,sv_put
        pop bc
        jr .chunk
.next:  ld de,5
        add ix,de
        jr .seg
.last:  ld hl,(sv_p)            ; ό,τι έμεινε στον buffer
        ld de,SVM_BUF + 2048
        or a
        sbc hl,de
        call nz,sv_put
        or a
        jp sv_close

; Το φόρτωμα: ο πρώτος τομέας, και μόνο αν έχει την υπογραφή όλο το ρεύμα
; στη μνήμη. Carry αν δεν βρέθηκε το αρχείο ή δεν έχει παρτίδα.
mod_load:
        call sv_open
        ret c
        call sv_get             ; ο πρώτος τομέας
        ld hl,SVM_BUF + 2048
        ld de,sv_sig
        ld b,SIG_LEN
.sig:   ld a,(de)
        cp (hl)
        jr nz,.none
        inc hl
        inc de
        djnz .sig
        ld hl,SVM_BUF + 2048
        ld (sv_p),hl
        ld ix,sv_seg
.seg:   ld a,(ix+0)
        or a
        jp z,sv_close
        call sv_bank
        ld e,(ix+1)
        ld d,(ix+2)
        ld c,(ix+3)
        ld b,(ix+4)
.chunk: ld a,b                  ; DE = προς, BC = πόσα μένουν
        or c
        jr z,.next
        ld hl,(sv_p)            ; άδειασε ο buffer: ο επόμενος τομέας
        ld a,h
        cp (SVM_BUF + 2048 + 512) >> 8
        jr nz,.have
        push bc
        push de
        call sv_get
        pop de
        pop bc
        ld hl,SVM_BUF + 2048
.have:  push bc                 ; BC = min(πόσα, ό,τι έχει ο buffer)
        push hl
        push de
        ex de,hl
        ld hl,SVM_BUF + 2048 + 512
        or a
        sbc hl,de
        call sv_min
        pop de
        pop hl
        ex (sp),hl              ; (sp) = από, HL = πόσα μένουν
        or a
        sbc hl,bc
        ex (sp),hl
        ldir
        ld (sv_p),hl
        pop bc
        jr .chunk
.next:  ld bc,5
        add ix,bc
        jr .seg
.none:  call sv_close
        scf
        ret

; IX = κομμάτι: η τράπεζα του στο #4000.
sv_bank:
        ld a,(ix+0)
        ld b,GA
        out (c),a
        ret

; BC = πόσα μένουν -> DE = ο buffer (sv_p), BC = min(πόσα, ό,τι χωράει).
sv_room:
        push hl
        ld de,(sv_p)
        ld hl,SVM_BUF + 2048 + 512
        or a
        sbc hl,de
        call sv_min
        pop hl
        ret

; HL = όριο, BC = πόσα -> BC = min. Κρατάει DE.
sv_min: or a
        sbc hl,bc
        ret nc                  ; όριο >= πόσα: όλα
        add hl,bc
        ld b,h
        ld c,l
        ret

; Ο buffer -> ο επόμενος τομέας του αρχείου (sv_k).
sv_put: push bc
        push hl
        push ix
        call sv_where
        call fdc_write
        pop ix
        pop hl
        pop bc
        ld de,SVM_BUF + 2048
        ld (sv_p),de
        ret

; Ο επόμενος τομέας του αρχείου -> ο buffer.
sv_get: push ix
        call sv_where
        call fdc_read
        pop ix
        ret

; Ο τομέας sv_k του αρχείου (και sv_k + 1) -> D = τροχιά, E = τομέας,
; HL = ο buffer.
sv_where:
        ld hl,sv_k
        ld a,(hl)
        inc (hl)
        ld c,a
        srl a                   ; το block: sv_blk[k / 2]
        ld e,a
        ld d,0
        ld hl,sv_blk
        add hl,de
        ld l,(hl)               ; L = 2 b + (k AND 1), 16 bits
        ld h,0
        add hl,hl
        ld a,c
        and 1
        ld c,a
        ld b,0
        add hl,bc
        call l_ts               ; (disk.asm)
        ld hl,SVM_BUF + 2048
        ret

; Ο οδηγός σε λειτουργία, ο κατάλογος, και τα blocks του SAVE.BIN με τη
; σειρά των extents στο sv_blk. Carry αν δεν υπάρχει.
sv_open:
        ld a,BD_DISK            ; το περιθώριο όσο δουλεύει η δισκέτα
        call border
        xor a
        ld (sv_k),a
        ld bc,MOTOR
        inc a
        out (c),a
        ld bc,20000             ; ~0,5 s να γυρίσει ο δίσκος
.sp:    ex (sp),hl
        ex (sp),hl
        ex (sp),hl
        ex (sp),hl
        dec bc
        ld a,b
        or c
        jr nz,.sp
        ld a,3                  ; specify, recalibrate (όπως το disk_load)
        call fdc_out
        ld a,#A1
        call fdc_out
        ld a,3
        call fdc_out
        ld a,7
        call fdc_out
        xor a
        call fdc_out
        call fdc_sense
        ld de,#00C1             ; ο κατάλογος
        ld hl,SVM_BUF
.dir:   push de
        call fdc_read
        pop de
        inc e
        ld a,e
        cp #C5
        jr c,.dir
        ld c,0                  ; τα extents 0, 1, 2 με τη σειρά
.ext:   ld hl,SVM_BUF
        ld b,64
.e:     push bc
        push hl
        ld a,(hl)
        or a
        jr nz,.no
.nm:    ld de,sv_name           ; (το mod_camp: άλλο αρχείο)
        ld b,11
.c:     inc hl
        ld a,(de)
        xor (hl)
        and #7F
        jr nz,.no
        inc de
        djnz .c
        inc hl
        ld a,(hl)               ; αυτό το extent;
        cp c
        jr nz,.no
        ld de,4                 ; τα 16 blocks του
        add hl,de
        ld a,c
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        push hl
        ld hl,sv_blk
        add hl,de
        ex de,hl
        pop hl
        ld bc,16
        ldir
        pop hl
        pop bc
        inc c
        ld a,c
.ne:    cp SV_EXT               ; (το mod_camp: άλλο πλήθος)
        jr c,.ext
        or a
        ret
.no:    pop hl
        ld de,32
        add hl,de
        pop bc
        djnz .e
        ld a,c                  ; όχι το πρώτο extent: όσα έχει, ως το
        or a                    ; ζητούμενο (το mod_camp: το POLIS.BIN 2 ή 3,
        ret nz                  ; το μήκος από την κεφαλίδα AMSDOS)
        call sv_close           ; δεν βρέθηκε
        scf
        ret

; Ο οδηγός σβηστός, η C0, το περιθώριο πίσω, οι διακοπές.
sv_close:
        push af
        ld bc,MOTOR
        xor a
        out (c),a
        ld a,RAM_BASE
        call setram
        ld a,(bd_idle)
        call border
        pop af
        ei
        ret

; D = τροχιά, E = τομέας: ο buffer (512 bytes) στον τομέα. Όπως το
; fdc_rd1 (disk.asm), με το «write data» και τα bytes προς το FDC.
fdc_write:
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
        ld a,#45                ; write data (MFM)
        call fdc_out
        xor a
        call fdc_out
        ld a,d                  ; C
        call fdc_out
        xor a                   ; H
        call fdc_out
        ld a,e                  ; R
        call fdc_out
        ld a,2                  ; N: 512
        call fdc_out
        ld a,e                  ; EOT
        call fdc_out
        ld a,#2A                ; GPL
        call fdc_out
        ld a,#FF                ; DTL
        call fdc_out
        ld bc,FDC_MSR
        ld de,512
.w:     in a,(c)                ; RQM
        jp p,.w
        inc c
        ld a,(hl)
        out (c),a
        dec c
        inc hl
        dec de
        ld a,d
        or e
        jr nz,.w
        call fdc_in
        ei
        ret

; Το τέλος μιας πίστας της εκστρατείας (M13, lv_after στο bank7.asm): η
; πρόοδος στο PROG.BIN, στο LV_FLAG η πίστα που ακολουθεί (menu.asm), και
; το παιχνίδι από την αρχή: το POLIS.BIN ξανά από τη δισκέτα στο #0040 —
; ό,τι κάνει το RUN"POLIS — και jp start. Το διάβασμα περνάει πάνω από τον
; κύριο κώδικα όπου ζουν το fdc_read, το l_ts· τα bytes τους είναι ίδια
; (δεν αλλάζουν ποτέ), και οι διακοπές στο ei/ret ως τότε.
mod_camp:
        ld a,RAM_CMP
        call setram
        ld hl,lv_prog
        ld de,SVM_BUF + 2048    ; ο τομέας: η πρόοδος στην αρχή του
        ld bc,2
        ldir
        ld hl,LV_FLAG
        ld a,(lv_next)
        or a
        jr z,.menu
        ld (hl),#A5
        inc hl
        ld (hl),#5A
        inc hl
        ld a,(lv_camp)
        ld (hl),a
        inc hl
        ld a,(lv_next)
.menu:  ld (hl),a
        ld a,RAM_BASE
        call setram
        ld hl,sv_prog
        ld a,1
        call .open
        jr c,.boot              ; (χωρίς το αρχείο: χωρίς πρόοδο)
        call sv_put
.boot:  ld hl,#FB + #C9 * 256   ; ei / ret στο #0038
        ld (#0038),hl
        ld hl,sv_polis          ; ως 3 extents (16 KB το καθένα, με την
        ld a,SV_EXT             ; κεφαλίδα AMSDOS: ήταν σταθερά 2, και όταν
        call .open              ; πέρασε τα 32 KB το τέλος ήταν σκουπίδια)
        jr c,$                  ; (η δισκέτα χωρίς το παιχνίδι)
        call sv_get             ; ο πρώτος: η κεφαλίδα AMSDOS (128 bytes)
        ld hl,(SVM_BUF + 2048 + 24)     ; το μήκος -> πόσοι τομείς ακόμα
        ld de,128 - 1
        add hl,de
        ld a,h
        srl a
        ld (sv_n),a
        ld hl,SVM_BUF + 2048 + 128
        ld de,#0040
        ld bc,512 - 128
.cp:    ldir
        ld a,(sv_n)
        or a
        jr z,.go
        dec a
        ld (sv_n),a
        push de
        call sv_get
        pop de
        ld hl,SVM_BUF + 2048
        ld bc,512
        jr .cp
.go:    di
        ld bc,MOTOR
        out (c),a               ; (A = 0)
        jp start
.open:  ld (sv_open.nm + 1),hl  ; HL = όνομα, A = extents
        ld (sv_open.ne + 1),a
        jp sv_open

; Τα κομμάτια του ρεύματος: τράπεζα, από, πόσα (0: τέλος).
sv_seg: db RAM_BASE
        dw sv_sig, SIG_LEN
        db RAM_BASE
        dw SAVE_M0, #4000 - SAVE_M0
        db RAM_BASE
        dw HUD_PAGE, #4000
        db RAM_BASE
        dw #8000, STACK_LOW - #8000
        db RAM_CMP
        dw C7_CODE, #8000 - C7_CODE
        db RAM_RES
        dw FOG, FOG_LEN
        db 0
sv_sig:     db "POLIS-M12"      ; η υπογραφή: πρώτη στο αρχείο
SIG_LEN     equ $ - sv_sig
sv_name:    db "SAVE    BIN"
sv_prog:    db "PROG    BIN"
sv_polis:   db "POLIS   BIN"
sv_n:       db 0
sv_p:       dw 0                ; η θέση στον buffer του τομέα
sv_k:       db 0                ; ο επόμενος τομέας του αρχείου
sv_blk:     ds 48               ; τα blocks του αρχείου, 3 extents

SAVE_BYTES  equ SIG_LEN + #4000 - SAVE_M0 + #4000 + STACK_LOW - #8000 + #8000 - C7_CODE + FOG_LEN
        assert SAVE_BYTES <= SAVE_FILE, 'SAVE.BIN too small'
        assert SAVE_FILE <= SV_EXT * 16384 && SAVE_FILE > (SV_EXT - 1) * 16384, 'SV_EXT'
