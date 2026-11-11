; units.asm — οι μονάδες: 128 στον κόσμο, όσες φαίνονται στην οθόνη. M3 + M4.
;
; ΟΙ ΔΥΟ ΤΡΑΠΕΖΕΣ
;
;   C4 -> #4000  Ο ΚΑΘΡΕΦΤΗΣ ΤΟΥ ΦΟΝΤΟΥ. Αντίγραφο της οθόνης (#C000-#FFFF)
;                με την ΙΔΙΑ διάταξη: το φόντο κάτω από το byte οθόνης
;                #C000+k είναι στο #4000+k. Η επαναφορά δεν υπολογίζει
;                τίποτα: πηγή = προορισμός με το bit 15 σβηστό (`res 7,h`).
;   C5 -> #4000  ΤΑ SPRITES: τα σετ των μονάδων, αποσυμπιεσμένα εκεί στην
;                εκκίνηση, με τις όψεις W από καθρέφτισμα, και μετά τους ο
;                κέρσορας, το σημάδι επιλογής και η γωνία του κουτιού.
;
; ΤΡΙΑ ΡΟΛΟΓΙΑ (milestones.md, Μέρος Β)
;
;   ΑΠΟΦΑΣΗ, τεμαχισμένη: 16 μονάδες ανά καρέ με κυκλικό δείκτη, άρα κάθε
;   μονάδα μία φορά στα 8 καρέ (units_think). Μια ελεύθερη μονάδα διαλέγει
;   νέο στόχο· μια μακρινή που περπατάει κάνει μονομιάς τα 4 βήματα που της
;   αναλογούν· και κρίνεται αν είναι ΕΝΕΡΓΗ: κοντά στην κάμερα.
;
;   ΚΙΝΗΣΗ, σε κάθε καρέ, ΜΟΝΟ οι ενεργές (units_move): βήμα κάθε 2ο καρέ
;   (οι μισές στα μονά, οι μισές στα ζυγά), καρέ βαδίσματος, όψη, θέση στην
;   οθόνη. Το περιθώριο της «ενεργής» ζώνης είναι όσο μπορούν να κινηθούν
;   κάμερα + μονάδα σε 8 καρέ: καμία ανενεργή δεν προλαβαίνει να φανεί.
;
;   ΣΧΕΔΙΑΣΗ: μόνο ό,τι άλλαξε (units_mark), με τη σειρά του ζωγράφου.
;
; Η ΘΕΣΗ είναι σε συντεταγμένες ΚΟΣΜΟΥ, ίδιες με την κάμερα: WX σε bytes,
; WY σε γραμμές — η πάνω-αριστερή γωνία του sprite. Στην οθόνη:
; SX = WX - cam_x (0..76), SY = WY - cam_y (0..128), αλλιώς δεν φαίνεται.

RAM_BASE    equ #C0             ; gate array: οι 64 KB της βάσης
RAM_BG      equ #C4             ; extra τράπεζα 0 στο #4000: ο καθρέφτης
RAM_SPR     equ #C5             ; extra τράπεζα 1 στο #4000: τα sprites

UNITS       equ 128
U_SIZE      equ 32
UNIT_TAB    equ #AE00           ; 130 x 32 (+ γωνία, κέρσορας) ως το #BE40
ANCHOR_REC  equ UNIT_TAB + UNITS * U_SIZE
CURSOR_REC  equ ANCHOR_REC + U_SIZE

; Μικροί πίνακες στη RAM μετά τον χάρτη (#A600-#ACFF ελεύθερα).
ACT_TAB     equ #A600           ; 128: 1 = ενεργή. ΣΤΟΙΧΙΣΜΕΝΟ: L = δείκτης
ORDER       equ #A680           ; 40 x δείκτης εγγραφής: η σειρά σχεδίασης
NEWLIST     equ #A6D0           ; 40: όσες φάνηκαν αυτό το καρέ
RLIST       equ #A720           ; 40: όσες σβήνονται αυτό το καρέ
RECTS       equ #A780           ; 96 x (x, y)
MAX_ORD     equ 38

U_WX        equ 0               ; dw: θέση στον κόσμο, bytes
U_WY        equ 2               ; dw: γραμμές
U_TX        equ 4               ; dw: ο στόχος
U_TY        equ 6               ; dw
U_SET       equ 8               ; ποιο σετ sprites
U_STEP      equ 9               ; μετρητής βημάτων: καρέ = (STEP >> 1) AND 3
U_FACE      equ 10              ; 0 S, 1 E, 2 N, 3 W
U_FL        equ 11              ; σημαίες F_*
U_SX        equ 12              ; πού είναι στην οθόνη αυτό το καρέ
U_SY        equ 13              ; (255 = εκτός· και κλειδί ταξινόμησης)
U_DRAWN     equ 14              ; bit 0: είναι στην οθόνη (το OADDR ισχύει)
                                ; bit 1: σβήνεται αυτό το καρέ
                                ; bit 2: ζωγραφίζεται αυτό το καρέ
U_PAR       equ 15              ; σε ποια καρέ κάνει βήμα (0/1)
U_FRAME     equ 16              ; dw: το καρέ, μόνο με το F_FIXED
U_OADDR     equ 18              ; dw: το byte οθόνης όπου ζωγραφίστηκε
U_BASE      equ 20              ; dw: το σετ της στην τράπεζα C5
U_IDX       equ 22              ; ο δείκτης της (για το ACT_TAB)
U_ORD       equ 23              ; 1 = είναι στο ORDER

F_MOVE      equ 0               ; περπατάει προς τον στόχο
F_SEL       equ 1               ; επιλεγμένη
F_WANDER    equ 2               ; περιπλανιέται μόνη της
F_REDRAW    equ 3               ; άλλαξε η επιλογή: ξαναζωγράφισε
F_FIXED     equ 4               ; σταθερό καρέ (κέρσορας, γωνία)

SWAP_TAB    equ #A400           ; 256, στοιχισμένο — αμέσως μετά τον χάρτη
SPR_SETS    equ 3
SPR_BASE    equ #4000
SPR_STRIDE  equ #C80            ; 21 καρέ x 128 + 4 όψεις W x 128
SPR_WEST    equ #A80            ; οι όψεις W μέσα στο σετ
SPR_CURSOR  equ SPR_BASE + SPR_SETS * SPR_STRIDE    ; data/cursor.bin
SPR_MARK    equ SPR_CURSOR + 128
SPR_ANCHOR  equ SPR_CURSOR + 256

; Ο κόσμος όπου κινούνται (η πάνω-αριστερή γωνία του sprite).
WORLD_W     equ 380
WORLD_H     equ 740

TOWN_UNITS  equ 12              ; οι πρώτες: στην πόλη, ακίνητες
TOWN_X      equ 106             ; κάτω από την αρχική κάμερα (98, 303)
TOWN_Y      equ 330

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

; A = δείκτης 0..129 -> IX = η εγγραφή = UNIT_TAB + 32 A. Κρατάει BC, DE, HL.
; Με περιστροφή: τα 3 πάνω bits του A πάνε στο high byte, τα 5 κάτω x 32
; στο low.
idx_ix: rrca
        rrca
        rrca
        push af
        and #1F
        add a,UNIT_TAB >> 8
        ld ixh,a
        pop af
        and #E0
        ld ixl,a
        ret

; Στην εκκίνηση: τα σετ στην C5, οι όψεις W από τις E με καθρέφτισμα, τα
; sprites του κέρσορα, και οι 128 μονάδες.
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
        ld hl,cursor_gfx
        ld de,SPR_CURSOR
        ld bc,3 * 128
        ldir
        ld a,RAM_BASE
        call setram

        ld hl,UNIT_TAB          ; όλα μηδέν
        ld de,UNIT_TAB + 1
        ld bc,(UNITS + 2) * U_SIZE - 1
        ld (hl),0
        ldir
        ld hl,ACT_TAB
        ld b,UNITS
.za:    ld (hl),0
        inc hl
        djnz .za
        xor a
.u:     push af
        call idx_ix
        pop af
        push af
        ld (ix+U_IDX),a
        ld (ix+U_SY),255
        ld c,a
        and 1
        ld (ix+U_PAR),a
        ld a,c                  ; σετ = i mod 3
.mod:   sub 3
        jr nc,.mod
        add a,3
        ld (ix+U_SET),a
        add a,a
        ld e,a
        ld d,0
        ld hl,set_base
        add hl,de
        ld a,(hl)
        ld (ix+U_BASE),a
        inc hl
        ld a,(hl)
        ld (ix+U_BASE+1),a
        ld a,c
        cp TOWN_UNITS
        jr nc,.far
        and 3                   ; οι πρώτες: στην πόλη, 4 στήλες ανά 16 bytes
        add a,a
        add a,a
        add a,a
        add a,a
        ld e,a
        ld d,0
        ld hl,TOWN_X
        add hl,de
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        ld a,c                  ; ... και σειρές ανά 32 γραμμές
        and #FC
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,TOWN_Y
        add hl,de
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        jr .pos
.far:   call rnd_pos            ; οι υπόλοιπες: τυχαία, έξω από την αρχική οθόνη
        set F_WANDER,(ix+U_FL)
.pos:   ld l,(ix+U_WX)          ; ο στόχος = εκεί που είναι
        ld h,(ix+U_WX+1)
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        pop af
        inc a
        cp UNITS
        jr nz,.u
        ld ix,ANCHOR_REC        ; η γωνία και ο κέρσορας: σταθερό καρέ, ποτέ
        ld hl,SPR_ANCHOR        ; στο ORDER των μονάδων
        call .fixed
        ld ix,CURSOR_REC
        ld hl,SPR_CURSOR
.fixed: set F_FIXED,(ix+U_FL)
        ld (ix+U_FRAME),l
        ld (ix+U_FRAME+1),h
        ld (ix+U_ORD),1
        ld (ix+U_SY),255
        ret

; IX: τυχαία θέση στον κόσμο, έξω από την αρχική οθόνη (+ περιθώριο).
rnd_pos:
        call rnd                ; WX = (r AND 255) + (r' AND 127), ≤ 380
        ld e,a
        ld d,0
        push de
        call rnd
        pop de
        and 127
        ld l,a
        ld h,0
        add hl,de
        ld de,WORLD_W
        call min_hl_de
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        call rnd                ; WY = r(0..511) + r'(0..255), ≤ 740
        push af
        call rnd
        and 1
        ld d,a
        pop af
        ld e,a
        push de
        call rnd
        pop de
        ld l,a
        ld h,0
        add hl,de
        ld de,WORLD_H
        call min_hl_de
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        ld de,280               ; μέσα στο [80,200) x [280,470): ξανά
        or a
        sbc hl,de
        ret c
        ld de,190
        or a
        sbc hl,de
        ret nc
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld de,80
        or a
        sbc hl,de
        ret c
        ld de,120
        or a
        sbc hl,de
        jr c,rnd_pos
        ret

; HL = min(HL, DE), χωρίς πρόσημο.
min_hl_de:
        or a
        sbc hl,de
        add hl,de
        ret c
        ex de,hl
        ret

; Ψευδοτυχαίοι, xorshift 16-bit -> A (και HL).
rnd:    ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
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
        call cursor_input
        call scroll_apply
        ld a,(paused)
        or a
        ret nz
        call units_prep
        call units_think
        call units_move
        call units_order
        call units_mark
        call units_restore_list
        jp units_draw

; ΜΟΝΟ Ο,ΤΙ ΑΛΛΑΞΕ — ΚΑΙ ΟΤΑΝ Η ΟΘΟΝΗ ΚΥΛΑΕΙ
;
;   Με την κύλιση του CRTC μια μονάδα που δεν κινήθηκε μένει στην ΙΔΙΑ
;   διεύθυνση μνήμης: δεν χρειάζεται ούτε σβήσιμο ούτε σχεδίαση. Όποια
;   ακουμπάει τη λωρίδα που αποκαλύπτεται βγαίνει εκτός οθόνης (η λωρίδα
;   είναι η μνήμη της αντίθετης άκρης), άρα σβήνεται — ΜΕΤΑ τη λωρίδα, από
;   τον καθρέφτη που την έχει ήδη. Τα παλιά ορθογώνια μετατοπίζονται στις
;   συντεταγμένες της νέας κάμερας (v_shx, v_shy). Ο κέρσορας μένει στην
;   ίδια θέση ΟΘΟΝΗΣ: με κύλιση ξαναζωγραφίζεται.
;
;   Μια μονάδα χωρίς βήμα είναι ήδη σωστή στην οθόνη — εκτός αν την
;   ακουμπάει κάτι που αλλάζει:
;
;     - το σβήσιμο μιας άλλης (το ΠΑΛΙΟ ορθογώνιο μιας που κινήθηκε), ή
;     - η σχεδίαση μιας ΠΙΣΩ της (νωρίτερα στη σειρά), που ζωγραφίζει από
;       πάνω της.
;
;   Τότε ξαναζωγραφίζεται, ΧΩΡΙΣ σβήσιμο: στη θέση της, πάνω από τον εαυτό
;   της, η μάσκα δίνει το ίδιο. Τα ορθογώνια (RECTS) μαζεύονται: πρώτα τα
;   παλιά όσων σβήνονται (units_move), μετά, με τη σειρά του ζωγράφου, τα
;   νέα όσων ζωγραφίζονται (units_mark).

; ---------------------------------------------------------- απόφαση

; 16 μονάδες ανά καρέ, κυκλικά.
units_think:
        ld a,(think_i)
        ld b,16
.l:     push bc
        push af
        call idx_ix
        call unit_think
        pop af
        inc a
        and UNITS - 1
        pop bc
        djnz .l
        ld (think_i),a
        ret

unit_think:
        bit F_MOVE,(ix+U_FL)
        jr nz,.mv
        bit F_WANDER,(ix+U_FL)
        jr z,unit_think_vis
        call rnd                ; ελεύθερη: 1 στις 4 φορές, νέος στόχος
        and 3
        jr nz,unit_think_vis
        call rnd                ; TX = WX - 32 + (0..63)
        and 63
        sub 32
        call add_wx
        ld de,WORLD_W
        call clamp_world
        ld (ix+U_TX),l
        ld (ix+U_TX+1),h
        call rnd                ; TY = WY - 64 + (0..127)
        and 127
        sub 64
        call add_wy
        ld de,WORLD_H
        call clamp_world
        ld (ix+U_TY),l
        ld (ix+U_TY+1),h
        set F_MOVE,(ix+U_FL)
        jr unit_think_vis
.mv:    ld a,(ix+U_SY)          ; περπατάει: αν ΔΕΝ φαίνεται, τα 4 βήματα
        inc a                   ; των 8 καρέ μονομιάς (όσο φαίνεται, βήμα
        jr nz,unit_think_vis     ; σε κάθε 2ο καρέ, στο units_move)
        ld de,#0408             ; ως 4 bytes, 8 γραμμές
        call unit_go
        jr nz,.went
        res F_MOVE,(ix+U_FL)
        ld (ix+U_STEP),0
        jr unit_think_vis
.went:  ld a,(ix+U_STEP)
        add a,4
        ld (ix+U_STEP),a
        ; συνεχίζει στο unit_think_vis

; Ενεργή αν -24 ≤ SX < 104 και -96 ≤ SY < 240. Ποτέ ανενεργή όσο είναι
; ζωγραφισμένη. Μια ενεργή που δεν φαίνεται: μήπως φάνηκε τώρα;
unit_think_vis:
        call unit_activity
        or a
        ret z
        ld a,(ix+U_SY)
        inc a
        ret nz
        jp unit_update

unit_activity:
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        ld de,24
        add hl,de
        ld a,h
        or a
        jr nz,.out
        ld a,l
        cp 128
        jr nc,.out
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        ld de,96
        add hl,de
        ld de,336
        or a
        sbc hl,de
        jr nc,.out
        ld a,1
        jr .set
.out:   ld a,(ix+U_DRAWN)
        and 1
.set:   ld l,(ix+U_IDX)
        ld h,ACT_TAB >> 8
        ld (hl),a
        ret

; Όλες, μονομιάς: μετά από άλμα της κάμερας.
units_activate_all:
        xor a
.l:     push af
        call idx_ix
        call unit_activity
        pop af
        inc a
        cp UNITS
        jr nz,.l
        ret

; A (με πρόσημο) + WX -> HL. Το ίδιο για το WY.
add_wx: ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        jr add_s8
add_wy: ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
add_s8: ld e,a
        rla
        sbc a,a
        ld d,a
        add hl,de
        ret

; HL (με πρόσημο) -> 0..DE.
clamp_world:
        bit 7,h
        jp z,min_hl_de
        ld hl,0
        ret

; Ένα βήμα προς τον στόχο: ως D bytes και E γραμμές. Ορίζει την όψη.
; Z αν είναι ήδη εκεί (δεν κινήθηκε).
unit_go:
        push de
        ld l,(ix+U_TX)
        ld h,(ix+U_TX+1)
        ld c,(ix+U_WX)
        ld b,(ix+U_WX+1)
        or a
        sbc hl,bc
        call clamp_step         ; D = όριο
        ld (g_x),a
        call add_wx
        ld (ix+U_WX),l
        ld (ix+U_WX+1),h
        pop de
        ld d,e
        ld l,(ix+U_TY)
        ld h,(ix+U_TY+1)
        ld c,(ix+U_WY)
        ld b,(ix+U_WY+1)
        or a
        sbc hl,bc
        call clamp_step
        ld (g_y),a
        call add_wy
        ld (ix+U_WY),l
        ld (ix+U_WY+1),h
        ld a,(g_y)              ; η όψη από τα πρόσημα:
        ld c,a                  ;   κάτω: E αν δεξιά, αλλιώς S
        ld a,(g_x)              ;   πάνω: W αν αριστερά, αλλιώς N
        or c                    ;   οριζόντια: E ή W
        ret z
        ld a,(g_x)
        ld b,0                  ; B = πρόσημο του g_x
        or a
        jr z,.sx
        ld b,1
        bit 7,a
        jr z,.sx
        ld b,-1
.sx:    ld a,c
        or a
        jr z,.horz
        bit 7,a
        jr nz,.up
        ld a,b                  ; κάτω
        dec a
        ld a,1                  ; E
        jr z,.face
        xor a                   ; S
        jr .face
.up:    ld a,b
        inc a
        ld a,3                  ; W
        jr z,.face
        ld a,2                  ; N
        jr .face
.horz:  ld a,b
        dec a
        ld a,1                  ; E
        jr z,.face
        ld a,3                  ; W
.face:  ld (ix+U_FACE),a
        or 1                    ; NZ: κινήθηκε
        ret

; HL = απόσταση (με πρόσημο) -> A = το βήμα, ως ±D.
clamp_step:
        bit 7,h
        jr nz,.neg
        ld a,h
        or a
        jr nz,.pmax
        ld a,l
        cp d
        ret c
.pmax:  ld a,d
        ret
.neg:   ld a,h
        inc a
        jr nz,.nmax
        ld a,l
        neg
        jr z,.nmax              ; -256
        cp d
        jr nc,.nmax
        neg
        ret
.nmax:  ld a,d
        neg
        ret

; ---------------------------------------------------------- κίνηση

; Πριν από την απόφαση: η κύλιση από το προηγούμενο καρέ, άδειες λίστες.
units_prep:
        ld a,(cam_x)            ; η κύλιση από το προηγούμενο καρέ
        ld b,a
        ld a,(pcx)
        sub b
        ld (v_shx),a
        ld a,b
        ld (pcx),a
        ld a,(cam_y)
        ld b,a
        ld a,(pcy)
        sub b
        ld (v_shy),a
        ld a,b
        ld (pcy),a
        xor a
        ld (rect_n),a
        ld (rl_n),a
        ld (nl_n),a
        ld hl,utick
        inc (hl)
        ret

; ΣΕ ΚΑΘΕ ΚΑΡΕ μόνο όσες φαίνονταν (το ORDER). Όσες δεν φαίνονται τις
; ελέγχει η απόφαση, μία φορά στα 8 καρέ — μια μονάδα που μπαίνει από την
; άκρη αργεί το πολύ 4 bytes. ΑΝ ΚΥΛΗΣΕ Η ΚΑΜΕΡΑ, όλες οι ενεργές (με
; CPIR στο ACT_TAB): αλλιώς η λωρίδα θα αποκάλυπτε μονάδες με καθυστέρηση.
; Τέλος η γωνία και ο κέρσορας.
units_move:
        ld a,(ord_n)
        or a
        jr z,.scr
        ld b,a
        ld hl,ORDER
.o:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        pop ix
        call unit_update
        pop hl
        pop bc
        djnz .o
.scr:   ld a,(v_shx)
        ld hl,v_shy
        or (hl)
        jr z,.ents
        ld hl,ACT_TAB
        ld bc,UNITS
.scan:  ld a,1
        cpir
        jr nz,.ents
        push hl
        push bc
        ld a,l
        dec a
        call idx_ix
        ld a,(ix+U_SY)
        inc a
        call z,unit_update
        pop bc
        pop hl
        ld a,b
        or c
        jr nz,.scan
.ents:  ld ix,ANCHOR_REC
        ld a,(box_on)
        or a
        jr z,.noanc
        call unit_update
        jr .cur
.noanc: call unit_still
        call unit_hide
.cur:   ld ix,CURSOR_REC
        jp cur_update

; IX = ενεργή μονάδα (ή η γωνία).
unit_update:
        call unit_still
        ld c,0                  ; C = άλλαξε
        bit F_MOVE,(ix+U_FL)
        jr z,.nostep
        ld a,(ix+U_SY)          ; όσο δεν φαίνεται, τα βήματα τα κάνει το
        inc a                   ; units_think
        jr z,.nostep
        ld a,(utick)
        xor (ix+U_PAR)
        rra
        jr c,.nostep
        ld de,#0102             ; 1 byte, 2 γραμμές: η ισομετρική διαγώνιος
        call unit_go
        jr nz,.went
        res F_MOVE,(ix+U_FL)    ; έφτασε: στέκεται, με την τελευταία όψη
        ld (ix+U_STEP),0
        jr .ch
.went:  inc (ix+U_STEP)
.ch:    ld c,1
.nostep:
        bit F_REDRAW,(ix+U_FL)  ; άλλαξε η επιλογή, χωρίς βήμα: ΧΩΡΙΣ
        jr z,.n3                ; σβήσιμο. Επιλέχτηκε: οι αγκύλες από πάνω.
        res F_REDRAW,(ix+U_FL)  ; Ξεεπιλέχτηκε: σβήνονται μόνο οι 2 γραμμές
        ld a,c                  ; τους.
        or a
        jr nz,.n3
        bit 0,(ix+U_DRAWN)
        jr z,.n3
        bit F_SEL,(ix+U_FL)
        call z,unmark
        set 2,(ix+U_DRAWN)
        jr .pos
.n3:    ld a,c
        or a
        jr nz,.chg
        ld a,(ix+U_DRAWN)
        or a
        jr nz,.pos              ; στην οθόνη και ίδια: το αποφασίζει το mark
        jr .new
.chg:   bit 0,(ix+U_DRAWN)
        call nz,old_rect
.new:   set 2,(ix+U_DRAWN)      ; ζωγραφίζεται (αν φαίνεται)
.pos:   ld l,(ix+U_WX)          ; SX = WX - cam_x, 0..76
        ld h,(ix+U_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,unit_hide
        ld a,l
        cp 77
        jr nc,unit_hide
        ld c,a
        ld l,(ix+U_WY)          ; SY = WY - cam_y, 0..128
        ld h,(ix+U_WY+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,unit_hide
        ld a,l
        cp VIEW_H - 16 + 1
        jr nc,unit_hide
        ld (ix+U_SX),c
        ld (ix+U_SY),a
        ld a,(ix+U_ORD)         ; μόλις φάνηκε: στη λίστα των νέων
        or a
        ret nz
        ld (ix+U_ORD),1
        ld hl,nl_n
        ld a,(hl)
        inc (hl)
        add a,a
        ld l,a
        ld h,NEWLIST >> 8
        ld de,NEWLIST & 255
        add hl,de
        push ix
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; Μένει μόνο το «είναι στην οθόνη» -> A.
unit_still:
        ld a,(ix+U_DRAWN)
        and 1
        ld (ix+U_DRAWN),a
        ret

; Εκτός οθόνης. Αν ήταν μέσα και δεν σβήνεται ήδη (βγήκε με την κύλιση,
; χωρίς βήμα): σβήνεται, με το παλιό ορθογώνιο στη νέα κάμερα = W - cam.
unit_hide:
        ld (ix+U_SY),255
        res 2,(ix+U_DRAWN)
        ld a,(ix+U_DRAWN)
        cp 1
        ret nz
        set 1,(ix+U_DRAWN)
        ld a,(cam_x)
        ld b,a
        ld a,(ix+U_WX)
        sub b
        ld c,a
        ld a,(cam_y)
        ld b,a
        ld a,(ix+U_WY)
        sub b
        ld b,a
        call add_rect
        jr add_rlist

; Σβήνεται: το παλιό ορθογώνιο (SX, SY ακόμα τα παλιά) στη νέα κάμερα.
old_rect:
        set 1,(ix+U_DRAWN)
        ld a,(v_shx)
        add a,(ix+U_SX)
        ld c,a
        ld a,(v_shy)
        add a,(ix+U_SY)
        ld b,a
        call add_rect
add_rlist:
        ld hl,rl_n
        ld a,(hl)
        inc (hl)
        add a,a
        ld l,a
        ld h,RLIST >> 8
        ld de,RLIST & 255
        add hl,de
        push ix
        pop de
        ld (hl),e
        inc hl
        ld (hl),d
        ret

; Ο κέρσορας: σταθερή θέση ΟΘΟΝΗΣ (cur_x, cur_y). Αλλάζει αν κινήθηκε ή
; αν κύλησε η οθόνη από κάτω του.
cur_update:
        call unit_still
        or a
        jr z,.new
        ld a,(v_shx)
        ld hl,v_shy
        or (hl)
        jr nz,.chg
        ld a,(cur_x)
        cp (ix+U_SX)
        jr nz,.chg
        ld a,(cur_y)
        cp (ix+U_SY)
        ret z
.chg:   call old_rect
.new:   set 2,(ix+U_DRAWN)
        ld a,(cur_x)
        ld (ix+U_SX),a
        ld a,(cur_y)
        ld (ix+U_SY),a
        ret

; ---------------------------------------------------------- σειρά

; Το ORDER: όσες φαίνονταν και φαίνονται ακόμα (με την ίδια σειρά), και
; στο τέλος όσες μόλις φάνηκαν· μετά ταξινόμηση με εισαγωγή κατά SY — ο
; πίνακας είναι σχεδόν ταξινομημένος. Τελευταίες, εκτός ταξινόμησης, η
; γωνία (αν φαίνεται) και ο κέρσορας: μπροστά από όλα.
units_order:
        ld hl,ORDER
        ld de,ORDER
        ld a,(ord_n)
        ld c,0
        or a
        jr z,.app
        ld b,a
.f:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push bc
        pop ix
        pop bc
        ld a,(ix+U_SY)
        cp 255
        jr z,.drop
        ld a,ixl
        ld (de),a
        inc de
        ld a,ixh
        ld (de),a
        inc de
        inc c
        jr .nx
.drop:  ld (ix+U_ORD),0
.nx:    djnz .f
.app:   ld a,(nl_n)             ; + οι νέες
        or a
        jr z,.sort
        ld b,a
        add a,c
        ld c,a
        ld hl,NEWLIST
.ap:    push bc
        ldi
        ldi
        pop bc
        djnz .ap
.sort:  ld a,c
        cp MAX_ORD
        jr c,.nok
        ld a,MAX_ORD
.nok:   ld (ord_n),a
        call order_sort
        ld a,(ord_n)            ; + γωνία, κέρσορας
        ld c,a
        add a,a
        ld l,a
        ld h,ORDER >> 8
        ld de,ORDER & 255
        add hl,de
        ld a,(ANCHOR_REC + U_SY)
        cp 255
        jr z,.nanc
        ld (hl),ANCHOR_REC & 255
        inc hl
        ld (hl),ANCHOR_REC >> 8
        inc hl
        inc c
.nanc:  ld (hl),CURSOR_REC & 255
        inc hl
        ld (hl),CURSOR_REC >> 8
        inc c
        ld a,c
        ld (ord_tot),a
        ret

; Εισαγωγή κατά SY στα ord_n πρώτα του ORDER.
order_sort:
        ld a,(ord_n)
        cp 2
        ret c
        ld c,1                  ; C = θέση προς εισαγωγή
.outer: ld a,c
        add a,a
        ld l,a
        ld h,0
        ld de,ORDER
        add hl,de               ; HL = &ORDER[c]
        ld e,(hl)
        inc hl
        ld d,(hl)
        dec hl
        ld (s_key),de
        ld a,U_SY
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld a,(de)
        ld (s_y),a
        ld b,c                  ; B = j
.in:    ld a,b
        or a
        jr z,.place
        dec hl                  ; HL = &ORDER[j-1]
        ld d,(hl)
        dec hl
        ld e,(hl)
        push hl
        ld hl,U_SY
        add hl,de
        ld a,(s_y)
        cp (hl)
        pop hl
        jr nc,.stop             ; y ≥ y[j-1]: σταθερή, μένει εδώ
        inc hl                  ; ORDER[j] = ORDER[j-1]
        inc hl
        ld (hl),e
        inc hl
        ld (hl),d
        dec hl
        dec hl
        dec hl
        dec b
        jr .in
.stop:  inc hl
        inc hl
.place: ld de,(s_key)
        ld (hl),e
        inc hl
        ld (hl),d
        inc c
        ld a,(ord_n)
        cp c
        jr nz,.outer
        ret

; ---------------------------------------------------------- σχεδίαση

; Με τη σειρά του ζωγράφου: όποια δεν άλλαξε, αλλά τέμνει κάποιο ορθογώνιο
; που σβήνεται ή ζωγραφίζεται πριν από αυτή, ζωγραφίζεται κι αυτή.
units_mark:
        ld a,(ord_tot)
        or a
        ret z
        ld b,a
        ld hl,ORDER
.u:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push bc
        pop ix
        ld b,(ix+U_SY)
        ld c,(ix+U_SX)
        bit 2,(ix+U_DRAWN)
        jr nz,.add
        call hits
        jr nc,.next
        set 2,(ix+U_DRAWN)
.add:   call add_rect
.next:  pop hl
        pop bc
        djnz .u
        ret

; C = x, B = y (θέση στην οθόνη) -> carry αν το 4 x 16 εκεί τέμνει κάποιο
; από τα RECTS: |dx| < 4 και |dy| < 16.
hits:   ld a,(rect_n)
        or a
        ret z
        ld e,a
        ld hl,RECTS
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
        cp 96
        ret nc
        inc (hl)
        add a,a
        ld l,a
        ld h,0
        ld de,RECTS
        add hl,de
        ld (hl),c
        inc hl
        ld (hl),b
        ret

; Σβήνει όλες και σταματάει: η οθόνη πρέπει να ξαναγίνει ΑΚΡΙΒΩΣ το φόντο.
; Οι έλεγχοι το χρησιμοποιούν για να αποδείξουν ότι δεν μένουν σκουπίδια.
units_erase:
        ld a,RAM_BG
        call setram
        xor a
.u:     push af
        call idx_ix
        bit 0,(ix+U_DRAWN)
        jr z,.n
        ld e,(ix+U_OADDR)
        ld d,(ix+U_OADDR+1)
        call restore16
.n:     ld (ix+U_DRAWN),0
        pop af
        inc a
        cp UNITS + 2
        jr nz,.u
        ld a,RAM_BASE
        call setram
        xor a
        ld (erase_req),a
        inc a
        ld (paused),a
        ret

; Όσες σβήνονται αυτό το καρέ (RLIST): όποια σβήνεται δεν είναι πια στην
; οθόνη (bit 0).
units_restore_list:
        ld a,(rl_n)
        or a
        ret z
        ld b,a
        ld a,RAM_BG
        push bc
        call setram
        pop bc
        ld hl,RLIST
.u:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push bc
        pop ix
        res 0,(ix+U_DRAWN)
        ld e,(ix+U_OADDR)       ; όπου ζωγραφίστηκε — το κράτησε η σχεδίαση
        ld d,(ix+U_OADDR+1)
        call restore16
        pop hl
        pop bc
        djnz .u
        ld a,RAM_BASE
        jp setram

units_draw:
        ld a,(ord_tot)
        or a
        ret z
        ld b,a
        ld a,RAM_SPR
        push bc
        call setram
        pop bc
        ld hl,ORDER
.u:     push bc
        ld c,(hl)
        inc hl
        ld b,(hl)
        inc hl
        push hl
        push bc
        pop ix
        bit 2,(ix+U_DRAWN)
        jr z,.skip              ; δεν άλλαξε
        ld a,(ix+U_SY)
        ld b,(ix+U_SX)
        call line_x
        ld (ix+U_OADDR),e
        ld (ix+U_OADDR+1),d
        push de
        call unit_frame
        pop de
        call blit16
        bit F_SEL,(ix+U_FL)     ; επιλεγμένη: οι αγκύλες, στο ίδιο ορθογώνιο
        call nz,blit_mark
        set 0,(ix+U_DRAWN)
.skip:  pop hl
        pop bc
        djnz .u
        ld a,RAM_BASE
        jp setram

; Ξεεπιλογή: οι γραμμές των αγκυλών πίσω από τον καθρέφτη, και το
; ορθογώνιο στα RECTS — όποια ακουμπάει, ξαναζωγραφίζεται (και η ίδια).
unmark: ld a,RAM_BG
        call setram
        ld a,(v_shy)            ; η παλιά θέση στη νέα κάμερα
        add a,(ix+U_SY)
        ld b,a
        ld a,(v_shx)
        add a,(ix+U_SX)
        ld c,a
        push bc
        ld a,b
        add a,MARK_L0
        call .line
        pop bc
        push bc
        ld a,b
        add a,MARK_L0 + 1
        call .line
        ld a,RAM_BASE
        call setram
        pop bc
        jp add_rect
.line:  ld b,c
        call line_x
        ld b,4
.b:     ld h,d
        ld l,e
        res 7,h
        ld a,(hl)
        ld (de),a
        inc e
        call z,de_carry
        djnz .b
        ret

; Οι αγκύλες της επιλογής: μόνο οι γραμμές 13-14 του SPR_MARK, όχι 16.
MARK_L0     equ 13
blit_mark:
        ld hl,SPR_MARK + MARK_L0 * 8
        ld a,(ix+U_SY)
        add a,MARK_L0
        call .line
        ld a,(ix+U_SY)
        add a,MARK_L0 + 1
.line:  push hl
        ld b,(ix+U_SX)
        call line_x
        pop hl
        ld b,4
.b:     ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        call z,de_carry
        djnz .b
        ret

; IX -> HL = το καρέ: σετ + όψη + καρέ βαδίσματος x 128.
unit_frame:
        bit F_FIXED,(ix+U_FL)
        jr z,.calc
        ld l,(ix+U_FRAME)
        ld h,(ix+U_FRAME+1)
        ret
.calc:  ld a,(ix+U_FACE)
        add a,a
        ld e,a
        ld d,0
        ld hl,face_off
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld l,(ix+U_BASE)
        ld h,(ix+U_BASE+1)
        add hl,de
        ld a,(ix+U_STEP)        ; καρέ = (STEP >> 1) AND 3, x 128
        rrca
        and 3
        rrca                    ; bit 0 -> 7 (x128), bit 1 -> 0 (x256)
        ld e,a
        and 1
        ld d,a
        ld a,e
        and #80
        ld e,a
        add hl,de
        ret

face_off:   dw 0, 4 * 128, 8 * 128, SPR_WEST        ; S, E, N, W

; Μετά από πλήρη σχεδίαση: καμία δεν έχει ίχνος να σβήσει, το ORDER
; ξαναχτίζεται, και η κάμερα μπορεί να πήδηξε: ενεργές από την αρχή.
units_forget:
        xor a
.u:     push af
        call idx_ix
        ld (ix+U_DRAWN),0
        pop af
        push af
        cp UNITS
        jr nc,.n
        ld (ix+U_ORD),0
.n:     pop af
        inc a
        cp UNITS + 2
        jr nz,.u
        xor a
        ld (ord_n),a
        ld (ord_tot),a
        ld a,(cam_x)
        ld (pcx),a
        ld a,(cam_y)
        ld (pcy),a
        jp units_activate_all
