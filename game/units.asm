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
; Οι μονάδες του M3 περπατάνε σε μια ΠΕΡΙΟΧΗ του κόσμου 77 x 129, με αρχή
; (ORG_X, ORG_Y) — εκεί που ήταν η κάμερα στο M3. Από το M2 η κάμερα κυλάει:
; η θέση στην οθόνη βγαίνει κάθε καρέ (units_view) και όσες είναι έξω δεν
; ζωγραφίζονται. (Μισές στην άκρη: ακόμα όχι — εμφανίζονται ολόκληρες.)
ORG_X       equ 98
ORG_Y       equ 303

U_X         equ 0               ; byte μέσα στην περιοχή, 0..76
U_Y         equ 1               ; γραμμή μέσα στην περιοχή, 0..128
U_DX        equ 2               ; ±1
U_DY        equ 3               ; ±1
U_SET       equ 4               ; ποιο σετ sprites
U_ANIM      equ 5               ; καρέ βαδίσματος 0..3
U_STEP      equ 6               ; μετρητής βημάτων
U_SX        equ 7               ; πού είναι στην οθόνη αυτό το καρέ
U_SY        equ 8               ; (255 = εκτός· και κλειδί ταξινόμησης)
U_DRAWN     equ 9               ; bit 0: είναι στην οθόνη (το OADDR ισχύει)
                                ; bit 1: σβήνεται αυτό το καρέ
                                ; bit 2: ζωγραφίζεται αυτό το καρέ
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
        jp nz,units_erase
        call read_keys
        call scroll_apply
        ld a,(paused)
        or a
        ret nz
        call units_move
        call units_sort
        call units_mark
        ld c,2
        call units_restore
        jp units_draw

; ΜΟΝΟ Ο,ΤΙ ΑΛΛΑΞΕ — ΚΑΙ ΟΤΑΝ Η ΟΘΟΝΗ ΚΥΛΑΕΙ
;
;   Με την κύλιση του CRTC μια μονάδα που δεν κινήθηκε μένει στην ΙΔΙΑ
;   διεύθυνση μνήμης: δεν χρειάζεται ούτε σβήσιμο ούτε σχεδίαση. Όποια
;   ακουμπάει τη λωρίδα που αποκαλύπτεται βγαίνει εκτός οθόνης (η λωρίδα
;   είναι η μνήμη της αντίθετης άκρης), άρα σβήνεται — ΜΕΤΑ τη λωρίδα, από
;   τον καθρέφτη που την έχει ήδη. Τα παλιά ορθογώνια μετατοπίζονται στις
;   συντεταγμένες της νέας κάμερας (v_shx, v_shy).
;
;   Σε κάθε καρέ κάνουν βήμα οι μισές. Μια μονάδα χωρίς βήμα είναι ήδη
;   σωστή στην οθόνη — εκτός αν την ακουμπάει κάτι που αλλάζει:
;
;     - το σβήσιμο μιας άλλης (το ΠΑΛΙΟ ορθογώνιο μιας που κινήθηκε), ή
;     - η σχεδίαση μιας ΠΙΣΩ της (νωρίτερα στη σειρά), που ζωγραφίζει από
;       πάνω της.
;
;   Τότε ξαναζωγραφίζεται, ΧΩΡΙΣ σβήσιμο: στη θέση της, πάνω από τον εαυτό
;   της, η μάσκα δίνει το ίδιο. Τα ορθογώνια (rects) μαζεύονται: πρώτα τα
;   παλιά όσων κινήθηκαν (units_move), μετά, με τη σειρά του ζωγράφου, τα
;   νέα όσων ζωγραφίζονται (units_mark). Μια μονάδα μπροστά από άλλη που
;   ζωγραφίζεται δεν χρειάζεται τίποτα: μπαίνει μετά.

; Με τη σειρά του ζωγράφου: όποια δεν άλλαξε, αλλά τέμνει κάποιο ορθογώνιο
; που σβήνεται ή ζωγραφίζεται πριν από αυτή, ζωγραφίζεται κι αυτή.
units_mark:
        ld hl,order
        ld b,UNITS
.u:     push bc
        push hl
        ld a,(hl)
        ld ixl,a
        ld ixh,unit_tab >> 8
        ld a,(ix+U_SY)
        cp 255
        jr z,.done              ; οι υπόλοιπες είναι εκτός (στο τέλος)
        ld b,a
        ld c,(ix+U_SX)
        bit 2,(ix+U_DRAWN)
        jr nz,.add
        call hits
        jr nc,.next
        set 2,(ix+U_DRAWN)
.add:   call add_rect
.next:  pop hl
        inc hl
        pop bc
        djnz .u
        ret
.done:  pop hl
        pop bc
        ret

; C = x, B = y (θέση στην οθόνη) -> carry αν το 4 x 16 εκεί τέμνει κάποιο
; από τα rects: |dx| < 4 και |dy| < 16.
hits:   ld a,(rect_n)
        or a
        ret z
        ld e,a
        ld hl,rects
.l:     ld a,(hl)
        inc hl
        sub c
        add a,3
        cp 7
        jr nc,.no
        ld a,(hl)
        sub b
        add a,15
        cp 31
        ret c
.no:    inc hl
        dec e
        jr nz,.l
        ret                     ; carry 0 από το τελευταίο cp

; C = x, B = y -> ένα ορθογώνιο ακόμα.
add_rect:
        ld hl,rect_n
        ld a,(hl)
        inc (hl)
        add a,a
        ld e,a
        ld d,0
        ld hl,rects
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        ret

; Σβήνει όλες και σταματάει: η οθόνη πρέπει να ξαναγίνει ΑΚΡΙΒΩΣ το φόντο.
; Ο έλεγχος του M3 το χρησιμοποιεί για να αποδείξει ότι δεν μένουν σκουπίδια.
units_erase:
        ld c,1
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

; C = μάσκα του U_DRAWN: 1 = όσες είναι στην οθόνη, 2 = όσες σβήνονται
; αυτό το καρέ. Όποια σβήνεται δεν είναι πια στην οθόνη (bit 0).
units_restore:
        ld a,RAM_BG
        call setram
        ld ix,unit_tab
        ld b,UNITS
.u:     push bc
        ld a,(ix+U_DRAWN)
        and c
        jr z,.next
        res 0,(ix+U_DRAWN)
        ld e,(ix+U_OADDR)       ; όπου ζωγραφίστηκε — το κράτησε η σχεδίαση
        ld d,(ix+U_OADDR+1)
        call restore16
.next:  ld de,U_SIZE
        add ix,de
        pop bc
        djnz .u
        ld a,RAM_BASE
        jp setram

; Κίνηση, και η θέση στην οθόνη από την κάμερα (255 αν δεν χωράει
; ολόκληρη). Η μετατόπιση της περιοχής στην οθόνη (ORG - cam) γίνεται ΜΙΑ
; φορά εύρος για το U_X / U_Y μέσα στο οποίο η μονάδα φαίνεται· ανά μονάδα
; μένουν δύο συγκρίσεις 8-bit.
units_move:
        ld hl,ORG_X             ; dx = ORG_X - cam_x: φαίνεται αν
        ld de,(cam_x)           ; 0 ≤ U_X + dx ≤ 76
        or a
        sbc hl,de
        ld a,(v_dx)             ; η μετατόπιση από το προηγούμενο καρέ
        cpl
        inc a
        add a,l
        ld (v_shx),a
        ld a,l
        ld (v_dx),a
        ld c,76
        call vis_range
        ld (v_xlo),de
        ld hl,ORG_Y
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,(v_dy)
        cpl
        inc a
        add a,l
        ld (v_shy),a
        ld a,l
        ld (v_dy),a
        ld c,VIEW_H - 16
        call vis_range
        ld (v_ylo),de
        xor a
        ld (rect_n),a
        ld ix,unit_tab
        ld b,UNITS
.u:     push bc
        ld a,(ix+U_DRAWN)       ; μένει μόνο το «είναι στην οθόνη»
        and 1
        ld (ix+U_DRAWN),a
        inc (ix+U_STEP)
        bit 0,(ix+U_STEP)       ; βήμα κάθε 2ο καρέ: 12,5 βήματα/s
        jr nz,.step             ; χωρίς βήμα δεν αλλάζει ούτε το καρέ:
        or a                    ; αν είναι ήδη στην οθόνη, το αποφασίζει
        jr nz,.next             ; το units_mark
        jr .new
.step:  or a
        jr z,.new
        set 1,(ix+U_DRAWN)      ; σβήνεται: το παλιό ορθογώνιο, στη νέα
        ld a,(v_shx)            ; κάμερα
        add a,(ix+U_SX)
        ld c,a
        ld a,(v_shy)
        add a,(ix+U_SY)
        ld b,a
        call add_rect
.new:   set 2,(ix+U_DRAWN)      ; ζωγραφίζεται (αν φαίνεται)
        bit 0,(ix+U_STEP)
        jr z,.next
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
.next:  ld (ix+U_SY),255        ; η θέση στην οθόνη
        ld a,(ix+U_X)
        ld hl,v_xlo
        cp (hl)
        jr c,.out
        inc hl
        cp (hl)
        jr z,.xin
        jr nc,.out
.xin:   ld hl,v_dx
        add a,(hl)
        ld (ix+U_SX),a
        ld a,(ix+U_Y)
        ld hl,v_ylo
        cp (hl)
        jr c,.out
        inc hl
        cp (hl)
        jr z,.yin
        jr nc,.out
.yin:   ld hl,v_dy
        add a,(hl)
        ld (ix+U_SY),a
        jr .vis
.out:   res 2,(ix+U_DRAWN)      ; εκτός οθόνης: αν ήταν μέσα και δεν
        ld a,(ix+U_DRAWN)       ; σβήνεται ήδη (βγήκε με την κύλιση),
        cp 1                    ; σβήνεται. Χωρίς βήμα, το παλιό
        jr nz,.vis              ; ορθογώνιο στη νέα κάμερα είναι
        set 1,(ix+U_DRAWN)      ; ακριβώς U + v_d
        ld a,(v_dx)
        add a,(ix+U_X)
        ld c,a
        ld a,(v_dy)
        add a,(ix+U_Y)
        ld b,a
        call add_rect
.vis:   ld de,U_SIZE
        add ix,de
        pop bc
        dec b
        jp nz,.u
        ret

; HL = μετατόπιση d (με πρόσημο), C = μέγιστο m -> E = lo, D = hi: το εύρος
; του u (0..m) με 0 ≤ u + d ≤ m. Κενό (lo > hi) αν δεν φαίνεται τίποτα.
vis_range:
        bit 7,h
        jr nz,.neg
        ld a,h                  ; d ≥ 0: u ≤ m - d
        or a
        jr nz,.none
        ld a,c
        sub l
        jr c,.none
        ld d,a
        ld e,0
        ret
.neg:   ld a,h                  ; d < 0: u ≥ -d
        inc a
        jr nz,.none
        xor a
        sub l
        cp c
        jr z,.lo
        jr nc,.none
.lo:    ld e,a
        ld d,c
        ret
.none:  ld de,#00FF             ; lo = 255, hi = 0
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
        add a,U_SY
        ld e,a
        ld d,unit_tab >> 8
        ld a,(de)
        ld (s_y),a
        ld d,c                  ; D = j
.in:    ld a,d
        or a
        jr z,.place
        dec hl                  ; HL = &order[j-1]
        ld a,(hl)
        add a,U_SY              ; το Y της, κατευθείαν (σελίδα στοιχισμένη)
        ld e,a
        push de
        ld d,unit_tab >> 8
        ld a,(de)
        pop de
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
        bit 2,(ix+U_DRAWN)
        jr z,.skip              ; δεν άλλαξε, ή εκτός οθόνης
        ld a,(ix+U_SY)
        ld b,(ix+U_SX)
        call line_x
        ld (ix+U_OADDR),e
        ld (ix+U_OADDR+1),d
        ld l,(ix+U_FRAME)
        ld h,(ix+U_FRAME+1)
        call blit16
        set 0,(ix+U_DRAWN)
.skip:  pop hl
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
