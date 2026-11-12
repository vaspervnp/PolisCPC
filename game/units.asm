; units.asm — οι μονάδες: 128 στον κόσμο, όσες φαίνονται στην οθόνη. M3 + M4.
;
; ΟΙ ΤΡΑΠΕΖΕΣ
;
;   C4 -> #4000  Ο ΚΑΘΡΕΦΤΗΣ ΤΟΥ ΦΟΝΤΟΥ. Αντίγραφο της οθόνης (#C000-#FFFF)
;                με την ΙΔΙΑ διάταξη: το φόντο κάτω από το byte οθόνης
;                #C000+k είναι στο #4000+k. Η επαναφορά δεν υπολογίζει
;                τίποτα: πηγή = προορισμός με το bit 15 σβηστό (`res 7,h`).
;   C5 -> #4000  ΤΑ SPRITES: τα σετ των μονάδων, αποσυμπιεσμένα εκεί στην
;                εκκίνηση, με τις όψεις W από καθρέφτισμα, και μετά τους ο
;                κέρσορας, το σημάδι επιλογής και η γωνία του κουτιού.
;   C7 -> #4000  ΤΑ ΜΕΤΑΓΛΩΤΤΙΣΜΕΝΑ SPRITES: κώδικας ανά καρέ βαδίσματος
;                (src/make_compiled.py), ~2x πιο γρήγορος από το blit16.
;                Το blit16 μένει για κέρσορα, γωνία, και γραμμές που περνάνε
;                όριο σελίδας.
;
; ΤΡΙΑ ΡΟΛΟΓΙΑ (milestones.md, Μέρος Β)
;
;   ΑΠΟΦΑΣΗ, τεμαχισμένη: 6 μονάδες ανά καρέ με κυκλικό δείκτη, άρα κάθε
;   μονάδα μία φορά στα ~22 καρέ (units_think). Μια ελεύθερη μονάδα διαλέγει
;   νέο στόχο· μια μακρινή που περπατάει κάνει μονομιάς τα 8 βήματα που της
;   αναλογούν· και κρίνεται αν είναι ΕΝΕΡΓΗ: κοντά στην κάμερα.
;
;   ΚΙΝΗΣΗ, σε κάθε καρέ, ΜΟΝΟ οι ενεργές (units_move): βήμα κάθε 2ο καρέ
;   (οι μισές στα μονά, οι μισές στα ζυγά), καρέ βαδίσματος, όψη, θέση στην
;   οθόνη. Το περιθώριο της «ενεργής» ζώνης είναι όσο μπορούν να κινηθούν
;   κάμερα + μονάδα σε 22 καρέ: καμία ανενεργή δεν προλαβαίνει να φανεί.
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
MOVERS      equ #A880           ; 32: όσες πήραν την τελευταία εντολή
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
U_WF        equ 15              ; ακολουθεί τοίχο: bit 7 + η κατεύθυνση 0..7
U_FRAME     equ 16              ; dw: το καρέ, μόνο με το F_FIXED
U_LOOK      equ 16              ; χωρίς F_FIXED: το σετ με το οποίο ζωγραφίστηκε
U_OADDR     equ 18              ; dw: το byte οθόνης όπου ζωγραφίστηκε
U_BASE      equ 20              ; dw: το σετ της στην τράπεζα C5
U_IDX       equ 22              ; ο δείκτης της (για το ACT_TAB)
U_WD        equ 23              ; η απόσταση (/4) όταν άρχισε να ακολουθεί

F_MOVE      equ 0               ; περπατάει προς τον στόχο
F_SEL       equ 1               ; επιλεγμένη
F_WANDER    equ 2               ; περιπλανιέται μόνη της
F_REDRAW    equ 3               ; άλλαξε η επιλογή: ξαναζωγράφισε
F_FIXED     equ 4               ; σταθερό καρέ (κέρσορας, γωνία)
F_INBLK     equ 5               ; στέκεται μέσα σε εμπόδιο (βγαίνει ελεύθερα)
F_MVR       equ 6               ; είναι στο MOVERS: βήματα σε κάθε καρέ
F_ORD       equ 7               ; είναι στο ORDER

SWAP_TAB    equ #A400           ; 256, στοιχισμένο — αμέσως μετά τον χάρτη
SPR_SETS    equ 4               ; + ο χωρικός που κουβαλάει (M6)
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

; HL = ρουτίνα της C7 (bank7.asm): με την C7 στο #4000, και μετά την C0.
; Κρατάει AF (το αποτέλεσμα), C.
far7:   ld a,RAM_CMP
        call setram
        call .go
        push af
        ld a,RAM_BASE
        call setram
        pop af
        ret
.go:    jp (hl)

; Οι νεκροί του dq (bank7.asm): έξω από τους κάδους τους (M8).
died_flush:
        ld a,(dq_n)
        or a
        ret z
        ld b,a
        ld hl,dq
.l:     ld a,(hl)
        inc hl
        push hl
        push bc
        call died_a
        pop bc
        pop hl
        djnz .l
        xor a
        ld (dq_n),a
        ret

; A = μονάδα που μόλις πέθανε: έξω από τον κάδο της.
died_a: push ix
        call idx_ix
        ld a,(ix+U_BKT)
        cp 255
        call nz,bucket_out
        ld (ix+U_BKT),255
        pop ix
        ret

; A = 0 / 1: η IX στόχος ή όχι (NT, pathing.asm).
nt_put: push hl
        ld l,(ix+U_IDX)
        set 7,l
        ld h,NT >> 8
        ld (hl),a
        pop hl
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

; Στην εκκίνηση: τα σετ στην C5 (αποσυμπίεση στην οθόνη, με την C0, και
; αντιγραφή από εκεί: η πηγή μπορεί να είναι στο #4000), οι όψεις W από τις
; E με καθρέφτισμα, και τα sprites του κέρσορα.
units_gfx:
        call make_swap
        ld ix,spr_tab
        ld de,SPR_BASE
        ld b,SPR_SETS
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
        ld bc,C5_TAIL           ; τα περιγράμματα (occlude.asm)
        ldir
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

; Οι 128 μονάδες.
units_init:
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
        ld c,a                  ; σετ = i mod 3
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
.far:   cp UNITS_LIVE           ; οι τελευταίες: ελεύθερες θέσεις (M7), μακριά
        jr c,.wan               ; από τον κόσμο, για όσες θα βγουν
        ld (ix+U_TEAM),TEAM_FREE
        ld (ix+U_WY+1),2000 >> 8
        jr .pos
.wan:   call rnd_pos            ; οι υπόλοιπες: τυχαία, έξω από την αρχική οθόνη
        set F_WANDER,(ix+U_FL)  ; — η άλλη ομάδα· ουδέτερες στη μάχη (NT)
        ld (ix+U_TEAM),1
        ld a,1
        call nt_put
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
        jp nz,.u
        ld ix,ANCHOR_REC        ; η γωνία και ο κέρσορας: σταθερό καρέ, ποτέ
        ld hl,SPR_ANCHOR        ; στο ORDER των μονάδων
        call .fixed
        ld ix,CURSOR_REC
        ld hl,SPR_CURSOR
.fixed: set F_FIXED,(ix+U_FL)
        ld (ix+U_FRAME),l
        ld (ix+U_FRAME+1),h
        set F_ORD,(ix+U_FL)
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
        ld a,(int_t)            ; η αρχή του καρέ, σε 1/300 s
        ld (t0),a
        ld hl,proj_off          ; τα βέλη (bank7.asm) σβήνουν πρώτα
        call far7
        ld a,(bench_req)
        or a
        call nz,bench_targets
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
        ld a,(n_busy)           ; το BFS μιας εντολής, σε κομμάτια
        or a
        call nz,field_cont
        ld a,(t0)               ; αργό καρέ (κύλιση): οι αποφάσεις στο επόμενο
        ld b,a
        ld a,(int_t)
        sub b
        cp T_LATE
        call c,units_think
        call bld_tick           ; κτίρια: επανασχεδίαση, ουρές (buildings.asm)
        call hud_card
        ld a,(hud_dirty)        ; άλλαξε η μπάρα (gather.asm)
        or a
        call nz,hud_update
        call units_move
        call units_order
        call units_mark
        call units_restore_list
        call units_draw
        ld hl,proj_on           ; και τα βέλη, τελευταία, από πάνω
        call far7
        jp died_flush

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

; THINK_N μονάδες ανά καρέ, κυκλικά. (Ήταν 16 στο M4· με την εύρεση δρόμου
; του M5 το βήμα ακρίβυνε, και τα αθροιστικά βήματα των μακρινών έτρωγαν
; το καρέ. Με 6, κάθε μονάδα μία φορά στα ~22 καρέ.)
THINK_N     equ 6
T_BUDGET    equ 5               ; σε 1/300 s: μετά από 17 ms, όχι άλλα βήματα
T_LATE      equ 8               ; σε 1/300 s: μετά από 27 ms, καμία απόφαση
units_think:
        ld a,(think_i)
        ld b,THINK_N
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
        ld a,(ix+U_TEAM)        ; νεκρή ή βέλος (M8): bank7.asm
        cp 2
        jr c,.alive
        inc a
        jr z,.alive             ; (ελεύθερη θέση: όπως πριν)
        ld hl,dead_think
        call far7
        jp unit_think_vis
.alive: bit F_WANDER,(ix+U_FL)  ; ΜΑΧΗ: στρατιώτες (σετ 1, 2) που δεν
        jr nz,.nc               ; περιπλανιούνται — ο κοντινότερος εχθρός,
        ld a,(ix+U_SET)         ; και η απόφαση στην C7
        dec a
        cp 2
        jr nc,.nc
        call find_nearest
        ld hl,combat_think
        call far7
        call died_flush
.nc:    ld a,(ix+U_JOB)         ; χωρικός με δουλειά (gather.asm)
        or a
        call nz,job_tick
        bit F_MOVE,(ix+U_FL)
        jr nz,.mv
        bit F_WANDER,(ix+U_FL)
        jr z,unit_think_vis
        call rnd                ; ελεύθερη: 1 στις 2 φορές, νέος στόχος
        and 1
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
        ex de,hl                ; ο στόχος σε εμπόδιο: όχι αυτή τη φορά
        ld l,(ix+U_TX)
        ld h,(ix+U_TX+1)
        call spot_blk
        or a
        jr nz,unit_think_vis
        set F_MOVE,(ix+U_FL)
        jr unit_think_vis
.mv:    ld a,(ix+U_FIELD)       ; με εντολή ΚΑΙ στο MOVERS: βήμα σε κάθε
        or a                    ; 2ο καρέ, πάντα (units_move)
        jr z,.far
        bit F_MVR,(ix+U_FL)
        jr nz,unit_think_vis
.far:   ld a,(ix+U_SY)          ; περπατάει: αν ΔΕΝ φαίνεται, 8 βήματα
        inc a                   ; μονομιάς (όσο φαίνεται, βήμα σε κάθε
        jr nz,unit_think_vis    ; 2ο καρέ, στο units_move)
        ld de,#0810             ; ως 8 bytes, 16 γραμμές
        call nav_step
        jr nz,.went
        res F_MOVE,(ix+U_FL)
        ld (ix+U_STEP),0
        jr unit_think_vis
.went:  ld a,(ix+U_STEP)
        add a,8
        ld (ix+U_STEP),a
        ; συνεχίζει στο unit_think_vis

; Ενεργή αν -56 ≤ SX < 136 και -200 ≤ SY < 344 (κάμερα 22 x 2 bytes / 22 x 8
; γραμμές, + 8 βήματα της μονάδας). Ποτέ ανενεργή όσο είναι
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
        ld de,56
        add hl,de
        ld a,h
        or a
        jr nz,.out
        ld a,l
        cp 192
        jr nc,.out
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        ld de,200
        add hl,de
        ld de,544
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

; Η όψη από το τελευταίο βήμα (g_x, g_y). NZ πάντα.
;   κάτω: E αν δεξιά, αλλιώς S      πάνω: W αν αριστερά, αλλιώς N
;   οριζόντια: E ή W                κανένα βήμα: μένει
set_face:
        ld a,(g_y)
        ld c,a
        ld a,(g_x)
        or c
        jr nz,.f
        or 1
        ret
.f:
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
; ελέγχει η απόφαση, μία φορά στα ~22 καρέ — μια μονάδα που μπαίνει από την
; άκρη αργεί το πολύ 8 bytes. ΑΝ ΚΥΛΗΣΕ Η ΚΑΜΕΡΑ, όσες είναι στη λωρίδα
; που αποκαλύφθηκε (από τα PX/PY): αλλιώς θα φαίνονταν με καθυστέρηση.
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
        ld a,(mv_n)             ; όσες έχουν εντολή και δεν φαίνονται
        or a
        jr z,.scr
        ld b,a
        ld hl,MOVERS
.m:     push bc
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        push hl
        push de
        pop ix
        ld a,(ix+U_SY)
        inc a
        jr nz,.mn
        bit F_MOVE,(ix+U_FL)
        call nz,unit_update
.mn:    pop hl
        pop bc
        djnz .m
.scr:   ld bc,77 << 8           ; x: από 0, 77 τιμές (SX 0..76)
        ld de,(VIEW_H - 15) << 8 ; y: από 0, 129 τιμές (SY 0..128)
        ld a,(u_rescan)         ; μετά από πλήρη σχεδίαση: όλη η οθόνη
        or a
        jr nz,.full
        ld a,(v_shx)            ; αλλιώς μόνο η λωρίδα που αποκαλύφθηκε:
        or a                    ; μια μονάδα έξω από αυτήν είτε φαινόταν
        jr z,.sy                ; ήδη είτε δεν φαίνεται ούτε τώρα
        ld b,2
        bit 7,a                 ; η κάμερα δεξιά: SX 75..76, αριστερά: 0..1
        jr z,.go
        ld c,75
        jr .go
.sy:    ld a,(v_shy)
        or a
        jr z,.ents
        ld d,8
        bit 7,a                 ; κάτω: SY 121..128, πάνω: 0..7
        jr z,.go
        ld e,VIEW_H - 16 - 7
        jr .go
.full:  xor a
        ld (u_rescan),a
.go:    ld a,(cam_x)            ; με τα low bytes (PX, PY, L = ο δείκτης),
        add a,c                 ; mod 256: όσες περάσουν, ο πλήρης έλεγχος
        ld c,a
        ld a,(cam_y)
        add a,e
        ld e,a
        ld hl,PX
.scan:  ld a,(hl)
        sub c
        cp b
        jr nc,.sk
        set 7,l
        ld a,(hl)
        res 7,l
        sub e
        cp d
        jr nc,.sk
        push hl
        push bc
        push de
        ld a,l
        call idx_ix
        ld a,(ix+U_SY)          ; δεν φαινόταν: φαίνεται τώρα;
        inc a
        call z,vis_test
        call z,unit_update
        pop de
        pop bc
        pop hl
.sk:    inc l
        bit 7,l
        jr z,.scan
.ents:  ld ix,ANCHOR_REC          ; η γωνία του κουτιού, ή το σημάδι του
        ld hl,SPR_ANCHOR        ; επιλεγμένου κτιρίου (buildings.asm)
        ld a,(box_on)
        or a
        jr nz,.anc
        call bld_mark
        jr z,.noanc
.anc:   ld (ix+U_FRAME),l
        ld (ix+U_FRAME+1),h
        ld hl,anc_force         ; άλλαξε: σβήσιμο και σχεδίαση από την αρχή
        ld a,(hl)
        or a
        jr z,.au
        ld (hl),0
        bit 0,(ix+U_DRAWN)
        call nz,old_rect
        ld (ix+U_DRAWN),0
        ld (ix+U_SY),255
.au:    call unit_update
        jr .cur
.noanc: call unit_still
        call unit_hide
.cur:   ld ix,CURSOR_REC
        jp cur_update

; IX = ενεργή μονάδα (ή η γωνία).
unit_update:
        call unit_still
        xor a                   ; το βήμα αυτού του καρέ (το γράφει το nav_step)
        ld (g_x),a
        ld (g_y),a
        ld c,a                  ; C = άλλαξε
        bit 7,(ix+U_FACE)       ; ΠΟΖΑ (επίθεση, θάνατος, βέλος — M8): κανένα
        jr z,.np                ; βήμα· το καρέ της, στην C7
        ld hl,pose_tick
        call far7
        ld a,c
        cp 2
        jp z,unit_hide          ; η θέση ελευθερώθηκε
        jr .nostep
.np:    bit F_MOVE,(ix+U_FL)
        jr z,.nostep
        ld a,(ix+U_FIELD)       ; με εντολή: βήματα πάντα εδώ
        or a
        jr nz,.stepok
        ld a,(ix+U_SY)          ; αλλιώς, όσο δεν φαίνεται, τα βήματα τα
        inc a                   ; κάνει το units_think
        jr z,.nostep
.stepok:
        ld a,(utick)
        xor (ix+U_IDX)          ; οι μισές στα μονά, οι μισές στα ζυγά
        rra
        jr c,.nostep
        ld a,(t0)               ; ΟΡΙΟ ΧΡΟΝΟΥ: αν το καρέ έχει ήδη φάει
        ld b,a                  ; T_BUDGET / 300 s (κύλιση, απόφαση, βήματα
        ld a,(int_t)            ; και τα σβησίματα και οι σχεδιάσεις τους που
        sub b                   ; ακολουθούν), η μονάδα δεν κάνει βήμα αυτό
        cp T_BUDGET             ; το καρέ. Στο επόμενο, ξανά.
        jr nc,.nostep
        ld de,#0102             ; 1 byte, 2 γραμμές: η ισομετρική διαγώνιος
        call nav_step
        jr nz,.went
        res F_MOVE,(ix+U_FL)    ; έφτασε: στέκεται, με την τελευταία όψη
        ld (ix+U_STEP),0
        jr .ch
.went:  inc (ix+U_STEP)
.ch:    ld c,1
.nostep:
        bit F_FIXED,(ix+U_FL)   ; άλλαξε σετ (ο χωρικός πήρε ή άφησε φορτίο):
        jr nz,.look             ; σβήσιμο και σχεδίαση, σαν βήμα
        ld a,(ix+U_SET)
        cp (ix+U_LOOK)
        jr z,.look
        ld (ix+U_LOOK),a
        ld c,1
.look:  bit F_REDRAW,(ix+U_FL)  ; άλλαξε η επιλογή, χωρίς βήμα: ΧΩΡΙΣ
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
        jr z,.new
        ld a,(v_shx)            ; στην οθόνη και ίδια: το αποφασίζει το mark
        ld hl,v_shy             ; — και χωρίς κύλιση, τίποτα δεν άλλαξε
        or (hl)
        ret z
        jr .pos
.chg:   bit 0,(ix+U_DRAWN)
        call nz,old_rect
.new:   set 2,(ix+U_DRAWN)      ; ζωγραφίζεται (αν φαίνεται)
.pos:   ld a,(v_shx)            ; χωρίς κύλιση, και φαινόταν: SX, SY + το
        ld hl,v_shy             ; βήμα, σε 8 bits
        or (hl)
        jr nz,.full
        ld a,(ix+U_SY)
        inc a
        jr z,.full
        ld a,(g_x)
        add a,(ix+U_SX)
        cp 77
        jp nc,unit_hide
        ld c,a
        ld a,(g_y)
        add a,(ix+U_SY)
        cp VIEW_H - 16 + 1
        jp nc,unit_hide
        ld (ix+U_SX),c
        ld (ix+U_SY),a
        ret
.full:  ld l,(ix+U_WX)          ; SX = WX - cam_x, 0..76
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
        bit F_ORD,(ix+U_FL)     ; μόλις φάνηκε: στη λίστα των νέων
        ret nz
        set F_ORD,(ix+U_FL)
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

; IX -> Z αν χωράει ολόκληρη στην οθόνη (0 ≤ SX ≤ 76, 0 ≤ SY ≤ 128).
vis_test:
        ld l,(ix+U_WX)
        ld h,(ix+U_WX+1)
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp 77
        jr nc,.no
        ld l,(ix+U_WY)
        ld h,(ix+U_WY+1)
        ld de,(cam_y)
        or a
        sbc hl,de
        ld a,h
        or a
        ret nz
        ld a,l
        cp VIEW_H - 16 + 1
        jr nc,.no
        xor a
        ret
.no:    or 1
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
        ld a,(cur_force)        ; άλλαξε όψη (κτίρια): σβήσιμο και σχεδίαση
        or a
        jr nz,.chg
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
.new:   xor a
        ld (cur_force),a
        set 2,(ix+U_DRAWN)
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
.drop:  res F_ORD,(ix+U_FL)
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
        ld b,a                  ; ΗΔΗ ταξινομημένο; (το συνηθισμένο: ένα
        dec b                   ; πέρασμα, και τέλος)
        ld hl,ORDER
        call .sy
        ld c,a
.chk:   call .sy
        cp c
        jr c,.sort
        ld c,a
        djnz .chk
        ret
.sy:    ld e,(hl)               ; HL = &ORDER[k] -> A = το SY του, HL += 2
        inc hl
        ld d,(hl)
        inc hl
        ex de,hl
        push bc
        ld bc,U_SY
        add hl,bc
        pop bc
        ld a,(hl)
        ex de,hl
        ret
.sort:        ld c,1                  ; C = θέση προς εισαγωγή
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
        ld e,b                  ; E = y, B = πόσα
        ld b,a
        ld hl,RECTS
.l:     ld a,(hl)
        sub c
        add a,3
        cp 7
        jr c,.x
.no:    inc hl
        inc hl
        djnz .l
        or a                    ; carry 0
        ret
.x:     inc hl
        ld a,(hl)
        dec hl
        sub e
        add a,15
        cp 31
        jr nc,.no
        ld b,e                  ; (το B της καλούσας: y)
        ret

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
        ld hl,occ_list          ; τα κτίρια που μπορεί να κρύβουν (bank7.asm)
        call far7
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
        bit F_FIXED,(ix+U_FL)   ; κέρσορας, γωνία: δεδομένα
        jr nz,.data
        push de                 ; πίσω από κτίριο: ζωγραφίστηκε, με το
        call occ_draw           ; περίγραμμα (occlude.asm)
        pop de
        jr nz,.mark
        bit 7,(ix+U_FACE)       ; πόζα: τα καρέ της δεν είναι μεταγλωττισμένα
        jr nz,.data
        ld a,e                  ; καμία γραμμή σε όριο σελίδας: το low byte
        cp #FD                  ; των (ως 3) σειρών χαρακτήρων < #FD
        jr nc,.data
        add a,80
        cp #FD
        jr nc,.data
        add a,80
        cp #FD
        jr nc,.data
        ld a,(ix+U_SET)         ; ο πίνακας της C7: (σετ x 16 + όψη x 4 +
        add a,a                 ; βήμα) x 2
        add a,a
        add a,(ix+U_FACE)
        add a,a
        add a,a
        ld c,a
        ld a,(ix+U_STEP)
        rrca
        and 3
        add a,c
        add a,a
        ld l,a
        ld h,#40
        ld a,RAM_CMP
        call setram
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ld (.cj + 1),hl
        ex de,hl                ; HL = η οθόνη
.cj:    call 0                  ; (αυτο-τροποποιούμενο: η ρουτίνα του καρέ)
        ld a,RAM_SPR
        call setram
        jr .mark
.data:  push de
        call unit_frame
        pop de
        call blit16
.mark:  bit F_SEL,(ix+U_FL)     ; επιλεγμένη: οι αγκύλες, στο ίδιο ορθογώνιο
        call nz,blit_mark
        set 0,(ix+U_DRAWN)
.skip:  pop hl
        pop bc
        dec b
        jp nz,.u
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
        ld a,(ix+U_SY)
        add a,MARK_L0
        ld b,(ix+U_SX)
        call line_x
        ld hl,SPR_MARK + MARK_L0 * 8
        call .line
        ld a,d                  ; η γραμμή 14: D + 8, ή η επόμενη σειρά
        add a,8
        ld d,a
        and #38
        call z,col_wrap
.line:  push de
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
        pop de
        ret

; IX -> HL = το καρέ: σετ + όψη + καρέ βαδίσματος x 128.
unit_frame:
        bit F_FIXED,(ix+U_FL)
        jr z,.calc
        ld l,(ix+U_FRAME)
        ld h,(ix+U_FRAME+1)
        ret
.calc:  bit 7,(ix+U_FACE)       ; πόζα (M8): το καρέ U_STEP του σετ
        jr z,.walk
        ld h,(ix+U_STEP)
        ld l,0
        srl h
        rr l
        ld e,(ix+U_BASE)
        ld d,(ix+U_BASE+1)
        add hl,de
        ret
.walk:  ld a,(ix+U_FACE)
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

; Η αλλαγή γραμμής των μεταγλωττισμένων sprites (src/make_compiled.py):
; αντιγράφεται στο #0028 στην εκκίνηση, ώστε να φαίνεται και με την C7 στο
; #4000. HL = byte οθόνης, C = η αρχή της γραμμής: L = C, H + 8, και στην
; αλλαγή σειράς χαρακτήρων (cwrap) +80, τυλιγμένο στα 2 KB.
rst_code:
        ld l,c                  ; #28
        ld a,h
        add a,8
        ld h,a
        and #38
        ret nz
        jp cwrap                ; #30
rst_len     equ $ - rst_code
        assert rst_len <= #38 - #28, 'rst #28 code overlaps #38'

cwrap:  ld a,c
        add a,80
        ld c,a
        ld l,a
        ld a,h
        adc a,0
        and 7
        or #C0
        ld h,a
        ret

; Μετά από πλήρη σχεδίαση: καμία δεν έχει ίχνος να σβήσει, το ORDER
; ξαναχτίζεται, και η κάμερα μπορεί να πήδηξε: ενεργές από την αρχή.
units_forget:
        ld hl,ARROWS + 7        ; ούτε βέλη (ARROWS: bank7.asm)
        ld de,8
        ld b,PR_N
.a:     ld (hl),255
        add hl,de
        djnz .a
        xor a
.u:     push af
        call idx_ix
        ld (ix+U_DRAWN),0
        pop af
        push af
        cp UNITS
        jr nc,.n
        res F_ORD,(ix+U_FL)
        ld (ix+U_SY),255        ; καμία δεν φαίνεται: το επόμενο καρέ τις
.n:     pop af                  ; ξαναβρίσκει (u_rescan)
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
        ld a,1
        ld (u_rescan),a
        jp units_activate_all
