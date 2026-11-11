; units.asm — ο blitter των μονάδων: 16 sprites κινούνται, στα 25 Hz. M3.
;
; ΟΙ ΔΥΟ ΤΡΑΠΕΖΕΣ
;
;   C4 -> #4000  Ο ΚΑΘΡΕΦΤΗΣ ΤΟΥ ΦΟΝΤΟΥ. Αντίγραφο της οθόνης (#C000-#FFFF)
;                με την ΙΔΙΑ διάταξη: το φόντο κάτω από το byte οθόνης
;                #C000+k είναι στο #4000+k. Η επαναφορά δεν υπολογίζει
;                τίποτα: πηγή = προορισμός με το bit 15 σβηστό (`res 7,h`).
;   C5 -> #4000  ΤΑ SPRITES ΤΩΝ ΜΟΝΑΔΩΝ, αποσυμπιεσμένα εκεί στην εκκίνηση,
;                μαζί με τις όψεις W που φτιάχνονται με καθρέφτισμα.
;
;   Γιατί όχι επαναφορά «από τον χάρτη» (το αρχικό σχέδιο του M3): στην
;   ισομετρική ένα ορθογώνιο της οθόνης είναι κομμάτια από ρόμβους ΚΑΙ
;   δέντρα που το διασχίζουν· θα έπρεπε να ξαναζωγραφιστούν με ψαλίδι στο
;   ορθογώνιο. Ο καθρέφτης κοστίζει μία τράπεζα και κάνει την επαναφορά ένα
;   σκέτο αντίγραφο 64 bytes.
;
; ΤΟ ΚΑΡΕ (κάθε 2ο VSYNC = 25 Hz)
;
;   1. C4: επαναφορά ΟΛΩΝ των παλιών ορθογωνίων από τον καθρέφτη
;   2. κίνηση, καρέ κίνησης, όψη
;   3. ταξινόμηση κατά Y (ο ζωγράφος: όποιος είναι πιο κάτω, μπαίνει μπρος)
;   4. C5: σχεδίαση όλων με μάσκα, πάνω στην οθόνη — όχι πάνω στον καθρέφτη,
;      ώστε μια μονάδα να σκεπάζει σωστά όποια είναι πίσω της
;
;   Πρώτα σβήνονται ΟΛΕΣ και μετά ζωγραφίζονται ΟΛΕΣ: αν μία μονάδα σβηνόταν
;   και ξαναζωγραφιζόταν πριν την επόμενη, το σβήσιμο της επόμενης θα έτρωγε
;   κομμάτι από αυτή που μόλις μπήκε.

RAM_BASE    equ #C0             ; gate array: οι 64 KB της βάσης
RAM_BG      equ #C4             ; extra τράπεζα 0 στο #4000: ο καθρέφτης
RAM_SPR     equ #C5             ; extra τράπεζα 1 στο #4000: τα sprites

UNITS       equ 16
U_SIZE      equ 16              ; 16 x 16 = μία σελίδα, στοιχισμένη (unit_tab)
U_X         equ 0               ; byte οθόνης, 0..76
U_Y         equ 1               ; γραμμή οθόνης, 0..128
U_DX        equ 2               ; ±1
U_DY        equ 3               ; ±1
U_SET       equ 4               ; ποιο σετ sprites
U_ANIM      equ 5               ; καρέ βαδίσματος 0..3
U_STEP      equ 6               ; μετρητής βημάτων
U_OX        equ 7               ; πού ζωγραφίστηκε τελευταία
U_OY        equ 8
U_DRAWN     equ 9
U_FRAME     equ 10              ; dw: το καρέ στην τράπεζα C5
U_BASE      equ 12              ; dw: το σετ της στην τράπεζα C5
U_OADDR     equ 14              ; dw: το byte οθόνης όπου ζωγραφίστηκε

SWAP_TAB    equ #A400           ; 256, στοιχισμένο — αμέσως μετά τον χάρτη
SPR_SETS    equ 3
SPR_BASE    equ #4000
SPR_STRIDE  equ #C80            ; 21 καρέ x 128 + 4 όψεις W x 128
SPR_WEST    equ #A80            ; οι όψεις W μέσα στο σετ

; ------------------------------------------------------------------

setram: ld b,GA                 ; A = RAM_xx
        out (c),a
        ret

; Αντιγράφει το παράθυρο χάρτη στον καθρέφτη. Μετά από κάθε πλήρη σχεδίαση.
; Οι 144 γραμμές είναι οι 18 πρώτες σειρές χαρακτήρων: σε καθεμία από τις
; 8 «οκτάδες» της μνήμης οθόνης, τα πρώτα 18 x 80 = 1.440 bytes. 11.520
; bytes αντί για 16 KB — ~70 ms αντί για ~98.
bg_snapshot:
        ld a,RAM_BG
        call setram
        ld hl,SCREEN
        ld b,8
.blk:   push bc
        push hl
        ld d,h
        res 7,d
        ld e,l
        ld bc,(VIEW_H / 8) * 80
        ldir
        pop hl
        ld bc,#800
        add hl,bc
        pop bc
        djnz .blk
        ld a,RAM_BASE
        jr setram

; Στην εκκίνηση: τα σετ στην C5, και οι όψεις W από τις E με καθρέφτισμα.
units_init:
        call make_swap
        ld a,RAM_SPR
        call setram
        ld ix,spr_tab
        ld de,SPR_BASE
        ld b,SPR_SETS
.set:   push bc
        push de
        ld l,(ix+0)
        ld h,(ix+1)
        inc ix
        inc ix
        call dzx0
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
        pop hl
        pop bc
        djnz .set
        ld a,RAM_BASE
        call setram
        ; οι μονάδες από τον πίνακα εκκίνησης
        ld hl,unit_init
        ld de,unit_tab
        ld b,UNITS
.u:     push bc
        ld bc,4
        ldir                    ; x, y, dx, dy
        ld a,(hl)
        inc hl
        ld (de),a               ; σετ
        inc de
        ex de,hl
        ld b,U_SIZE - 5
.z:     ld (hl),0
        inc hl
        djnz .z
        ex de,hl
        pop bc
        djnz .u
        ; ανά μονάδα: η βάση του σετ της, το πρώτο καρέ, και βήματα
        ; ΜΟΙΡΑΣΜΕΝΑ — οι μισές κάνουν βήμα στα μονά καρέ, οι μισές στα ζυγά
        ld ix,unit_tab
        ld b,UNITS
.f:     push bc
        ld a,b
        and 1
        ld (ix+U_STEP),a
        ld l,(ix+U_SET)
        ld h,0
        add hl,hl
        ld de,set_base
        add hl,de
        ld a,(hl)
        ld (ix+U_BASE),a
        inc hl
        ld a,(hl)
        ld (ix+U_BASE+1),a
        call unit_face
        ld de,U_SIZE
        add ix,de
        pop bc
        djnz .f
        ret

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

; Πίνακας 256: τα δύο pixels του byte Mode 0 ανταλλαγμένα. Pixel 0 στα bits
; 7,5,3,1, pixel 1 στα 6,4,2,0 — άρα ανταλλαγή ζυγών/μονών bits.
make_swap:
        ld hl,SWAP_TAB
.s:     ld a,l
        add a,a
        and #AA
        ld c,a
        ld a,l
        rrca
        and #55
        or c
        ld (hl),a
        inc l
        jr nz,.s
        ret

; ---------------------------------------------------------- το καρέ

units_tick:
        ld a,(erase_req)
        or a
        jr nz,units_erase
        ld a,(paused)
        or a
        ret nz
        call units_restore
        call units_move
        call units_sort
        jp units_draw

; Σβήνει όλες και σταματάει: η οθόνη πρέπει να ξαναγίνει ΑΚΡΙΒΩΣ το φόντο.
; Ο έλεγχος του M3 το χρησιμοποιεί για να αποδείξει ότι δεν μένουν σκουπίδια.
units_erase:
        call units_restore
        xor a
        ld (erase_req),a
        ld ix,unit_tab
        ld b,UNITS
        ld de,U_SIZE
.u:     ld (ix+U_DRAWN),0
        add ix,de
        djnz .u
        ld a,1
        ld (paused),a
        ret

units_restore:
        ld a,RAM_BG
        call setram
        ld ix,unit_tab
        ld b,UNITS
.u:     push bc
        ld a,(ix+U_DRAWN)
        or a
        jr z,.next
        ld e,(ix+U_OADDR)       ; όπου ζωγραφίστηκε — το κράτησε η σχεδίαση
        ld d,(ix+U_OADDR+1)
        call restore16
.next:  ld de,U_SIZE
        add ix,de
        pop bc
        djnz .u
        ld a,RAM_BASE
        jp setram

units_move:
        ld ix,unit_tab
        ld b,UNITS
.u:     push bc
        inc (ix+U_STEP)
        bit 0,(ix+U_STEP)       ; βήμα κάθε 2ο καρέ: 12,5 βήματα/s
        jr z,.next              ; χωρίς βήμα δεν αλλάζει ούτε το καρέ
        ld a,(ix+U_X)           ; x += dx, αναπήδηση στα 0..76
        add a,(ix+U_DX)
        cp 77
        jr c,.xok
        ld a,(ix+U_DX)
        neg
        ld (ix+U_DX),a
        ld a,(ix+U_X)
        add a,(ix+U_DX)
.xok:   ld (ix+U_X),a
        ld a,(ix+U_Y)           ; y += dy, αναπήδηση στα 0..128
        add a,(ix+U_DY)
        cp 129
        jr c,.yok
        ld a,(ix+U_DY)
        neg
        ld (ix+U_DY),a
        ld a,(ix+U_Y)
        add a,(ix+U_DY)
.yok:   ld (ix+U_Y),a
        ld a,(ix+U_STEP)        ; καρέ βαδίσματος: ένα ανά 2 βήματα
        rrca
        rrca
        and 3
        ld (ix+U_ANIM),a
        call unit_face
.next:  ld de,U_SIZE
        add ix,de
        pop bc
        djnz .u
        ret

; Το καρέ από την κατεύθυνση και το βήμα. Οι ισομετρικές διαγώνιοι πάνε
; στις 4 όψεις:
;   ΝΑ (dx+, dy+) -> E    ΝΔ (dx-, dy+) -> S
;   ΒΔ (dx-, dy-) -> W    ΒΑ (dx+, dy-) -> N
unit_face:
        ld e,(ix+U_BASE)
        ld d,(ix+U_BASE+1)
        bit 7,(ix+U_DY)
        jr nz,.up
        bit 7,(ix+U_DX)
        ld hl,4 * 128           ; E
        jr z,.got
        ld hl,0                 ; S
        jr .got
.up:    bit 7,(ix+U_DX)
        ld hl,8 * 128           ; N
        jr z,.got
        ld hl,SPR_WEST          ; W
.got:   add hl,de
        ld a,(ix+U_ANIM)        ; + anim * 128
        rrca
        ld d,a
        and #80
        ld e,a
        ld a,d
        and #7F
        ld d,a
        add hl,de
        ld (ix+U_FRAME),l
        ld (ix+U_FRAME+1),h
        ret

; Ταξινόμηση με εισαγωγή του πίνακα σειράς (16 δείκτες) κατά Y. Οι μονάδες
; κινούνται λίγο ανά καρέ, οπότε ο πίνακας είναι σχεδόν ταξινομημένος και η
; εισαγωγή κάνει σχεδόν μόνο συγκρίσεις.
units_sort:
        ld c,1                  ; C = θέση προς εισαγωγή
.outer: ld hl,order
        ld b,0
        add hl,bc               ; HL = &order[c]
        ld a,(hl)
        ld (s_key),a
        call y_of
        ld (s_y),a
        ld d,c                  ; D = j
.in:    ld a,d
        or a
        jr z,.place
        dec hl                  ; HL = &order[j-1]
        ld a,(hl)
        call y_of
        ld e,a
        ld a,(s_y)
        cp e
        jr nc,.stop             ; y ≥ y[j-1]: σταθερή, μένει εδώ
        ld a,(hl)               ; order[j] = order[j-1]
        inc hl
        ld (hl),a
        dec hl
        dec d
        jr .in
.stop:  inc hl
.place: ld a,(s_key)
        ld (hl),a
        inc c
        ld a,c
        cp UNITS
        jr nz,.outer
        ret

; A = καταχώριση του order (το low byte της εγγραφής) -> A = Y της.
; Ο πίνακας μονάδων είναι μία στοιχισμένη σελίδα, άρα χωρίς πολλαπλασιασμό.
y_of:   push de
        add a,U_Y
        ld e,a
        ld d,unit_tab >> 8
        ld a,(de)
        pop de
        ret

units_draw:
        ld a,RAM_SPR
        call setram
        ld b,UNITS
        ld hl,order
.u:     push bc
        push hl
        ld a,(hl)               ; IX = η εγγραφή, κατευθείαν από το order
        ld ixl,a
        ld ixh,unit_tab >> 8
        ld a,(ix+U_Y)
        ld (ix+U_OY),a
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(ix+U_X)
        ld (ix+U_OX),a
        add a,e
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld (ix+U_OADDR),e
        ld (ix+U_OADDR+1),d
        ld l,(ix+U_FRAME)
        ld h,(ix+U_FRAME+1)
        call blit16
        ld (ix+U_DRAWN),1
        pop hl
        inc hl
        pop bc
        djnz .u
        ld a,RAM_BASE
        jp setram

; Μετά από πλήρη σχεδίαση: καμία μονάδα δεν έχει ίχνος να σβήσει.
units_forget:
        ld hl,unit_tab + U_DRAWN
        ld de,U_SIZE
        ld b,UNITS
.u:     ld (hl),0
        add hl,de
        djnz .u
        ret
