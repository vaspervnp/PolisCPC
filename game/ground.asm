; ground.asm — το ισομετρικό έδαφος, ολόκληρο το παράθυρο χάρτη. M1.
;
; Ο ΚΟΣΜΟΣ
;
;   Το πλακίδιο (i, j) έχει το κουτί του (4 bytes x 8 γραμμές) στο
;       X = (i - j)*2 + XOFF   bytes        Y = (i + j)*4   γραμμές
;   και η κάμερα (cam_x, cam_y) είναι η πάνω αριστερή γωνία του παραθύρου σε
;   αυτές τις συντεταγμένες. cam_x ΖΥΓΟ (βήμα κύλισης = 2 bytes = 4 pixels),
;   cam_y ≡ 3 (mod 4) (βήμα 4 γραμμές) — έτσι κάθε ζεύγος γραμμών οθόνης
;   ξεκινάει σε ζυγή γραμμή και η 2η είναι πάντα +#800.
;
; ΟΙ ΔΥΟ ΤΥΠΟΙ ΖΕΥΓΟΥΣ
;
;   Ο ρόμβος των bytes έχει γραμμές 1-2: bytes 1-2, 3-4: bytes 0-3, 5-6:
;   bytes 1-2. Άρα η οθόνη χωρίζεται σε ζώνες των 2 γραμμών, και σε κάθε ζώνη
;   κάθε 2 bytes ανήκουν σε ΕΝΑ πλακίδιο:
;
;   A  (Y ≡ 3 mod 4)  η μέση της σειράς r: κάθε πλακίδιο δίνει 4 bytes από
;                     τις γραμμές 3-4 του (offset 4 και 8). Βήμα (i+1, j-1).
;   B  (Y ≡ 1 mod 4)  η ραφή των σειρών r και r+1: εναλλάξ το ΚΑΤΩ μισό ενός
;                     πλακιδίου της r (γραμμές 5-6, offset 12) και το ΠΑΝΩ
;                     μισό ενός της r+1 (γραμμές 1-2, offset 0), 2 bytes το
;                     καθένα. Κάτω (I,J) -> πάνω (I+1,J) -> κάτω (I+1,J-1).
;
;   Κάθε byte της οθόνης γράφεται ΜΙΑ φορά, χωρίς μάσκα, χωρίς επικάλυψη.
;
; ΤΑ ΑΚΡΑ
;
;   Τα στοιχεία δεν πέφτουν πάντα πάνω στα όρια της οθόνης: στον τύπο A το
;   πρώτο πλακίδιο μπορεί να αρχίζει στο byte -2, στον B το πρώτο στοιχείο
;   αρχίζει ΠΑΝΤΑ στο -1. Αυτά τα μισά ζωγραφίζει το `partial`.
;
;   Έξω από τον χάρτη (i ή j εκτός 0..95) ζωγραφίζεται pen 0 — μαύρο.
;   Ο έλεγχος είναι δύο `cp 96` ανά στοιχείο: οι αρνητικοί γίνονται ≥ 128
;   ως bytes και πέφτουν κι αυτοί έξω.

XOFF        equ 190             ; bytes: το (0,95) αρχίζει στο X=0
MAP         equ #8000
MAPW        equ 96
VIEW_H      equ 144             ; γραμμές του παραθύρου χάρτη

; ------------------------------------------------------------------

; Ολόκληρο το έδαφος του παραθύρου, 72 ζεύγη γραμμών.
draw_ground:
        ld hl,(cam_x)           ; cam_h = (cam_x - XOFF) / 2, προσημασμένο
        ld de,-XOFF
        add hl,de
        sra h
        rr l
        ld (cam_h),hl
        xor a
.pair:  push af
        call draw_pair
        pop af
        add a,2
        cp VIEW_H
        jr nz,.pair
        ret

; A = y (ζυγό). Ζωγραφίζει τις γραμμές y και y+1.
draw_pair:
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (scr),de

        ld hl,(cam_y)           ; Y = cam_y + y
        ld e,a
        ld d,0
        add hl,de
        ld a,l
        and 3
        ld (ptype),a            ; 3 = A, 1 = B
        inc hl                  ; r = ((Y+1) >> 2) - 1
        sra h
        rr l
        sra h
        rr l
        dec hl
        ld (var_r),hl
        ld a,(ptype)
        cp 3
        jp nz,pair_b

; ---------------------------------------------------------- τύπος A
; m = το μεγαλύτερο ≤ h με την ίδια ισοτιμία με το r· το πλακίδιο m πιάνει
; τα bytes 2m..2m+3 του κόσμου (σχετικά με XOFF), η οθόνη αρχίζει στο 2h.
pair_a:
        ld de,(cam_h)
        ld a,e
        xor l
        and 1
        ld (lead),a
        jr z,.even
        dec de                  ; m = h - 1: το πρώτο πλακίδιο μισό, στο -2
.even:  call set_ij             ; I = (m+r)/2, J = (r-m)/2, ptr, alt regs
        ; Όλη η γραμμή μέσα στον χάρτη; Η περιοχή του χάρτη είναι κυρτή, άρα
        ; αρκεί το πρώτο και το τελευταίο πλακίδιο: (I0, J0) και
        ; (I0+n, J0-n) με n = 19 + lead.
        ld a,(lead)
        add a,19
        call check_fast
        exx
        ld de,1-MAPW            ; βήμα (i+1, j-1)
        exx
        ld de,(scr)
        ld a,(lead)
        or a
        ld a,20
        jr z,.full
        ld a,6                  ; τα bytes 2-3 της μέσης
        ld bc,#0204
        call partial
        exx
        inc b
        dec c
        add hl,de
        exx
        ld a,19
.full:  ld ixl,a
        ld a,(fast)
        or a
        jr nz,.floop

.loop:  exx
        ld a,b
        cp MAPW
        jr nc,.void
        ld a,c
        cp MAPW
        jr nc,.void
        ld a,(hl)
        inc b
        dec c
        add hl,de
        exx
        and #F0
        or 4                    ; γραμμή 3 του ρόμβου
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        ldi
        ldi
        set 3,d                 ; η γραμμή από κάτω: +#800
        dec de
        dec de
        dec de
        dec de
        ldi                     ; γραμμή 4: συνεχόμενη, offset 8
        ldi
        ldi
        ldi
        res 3,d
        dec ixl
        jr nz,.loop
        jr .tail
.void:  inc b
        dec c
        add hl,de
        exx
        xor a
        call zero4
        dec ixl
        jr nz,.loop
        jr .tail

; Η γρήγορη διαδρομή: ίδια, χωρίς τους δύο ελέγχους ορίων ανά πλακίδιο.
.floop: exx
        ld a,(hl)
        inc b
        dec c
        add hl,de
        exx
        and #F0
        or 4
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        ldi
        ldi
        set 3,d
        dec de
        dec de
        dec de
        dec de
        ldi
        ldi
        ldi
        ldi
        res 3,d
        dec ixl
        jr nz,.floop

.tail:  ld a,(lead)
        or a
        ret z
        ld a,4                  ; τα bytes 0-1 του τελευταίου
        ld bc,#0204
        jp partial

; ---------------------------------------------------------- τύπος B
; Τα στοιχεία είναι 2 bytes στα 2n+1, 2n+2 του κόσμου. Η οθόνη (2h) πέφτει
; στο ΔΕΥΤΕΡΟ byte του στοιχείου n0 = h-1. Είδος t = (n + r) & 1: 0 κάτω,
; 1 πάνω. Το i της σειράς r: i = (n - t + r) / 2.
pair_b:
        ld de,(cam_h)
        ld a,e
        xor l
        and 1
        xor 1                   ; t0 = (h - 1 + r) & 1
        ld (lead),a
        dec de                  ; n0 = h - 1
        ld a,(lead)
        or a
        jr z,.t0
        dec de                  ; n0 - t0
.t0:    call set_ij             ; ως A με m = n0 - t0: I = i, J = r - i
        ; γρήγορη διαδρομή: το πρώτο στοιχείο (I0, J0) και το 41ο, ίδιου
        ; είδους, στο (I0+20, J0-20). Για πάνω μισό, I0 = i+1.
        ld a,(lead)
        ld hl,var_i
        add a,(hl)
        ld (hl),a
        ld a,20
        call check_fast
        ld a,(lead)
        or a
        jr z,.ti
        ld hl,var_i             ; set_ij έγραψε i· το alt B παίρνει +1 πιο κάτω
        dec (hl)
.ti:    ld de,(scr)
        ld a,(lead)
        or a
        jr nz,.top0
        ; πρώτο στοιχείο: κάτω μισό του (i, J)
        ld a,13
        ld bc,#0102
        call partial
        ld ixl,39
        exx
        ld de,-MAPW
        inc b                   ; -> πάνω (i+1, J)
        inc hl
        exx
        ld a,(fast)
        or a
        call z,b_from_top
        call nz,bf_from_top
        ld a,12                 ; το 41ο είναι ξανά κάτω μισό
        ld bc,#0102
        jp partial
.top0:  ; πρώτο στοιχείο: πάνω μισό του (i+1, J)
        exx
        inc b
        inc hl
        exx
        ld a,1
        ld bc,#0102
        call partial
        ld ixl,39
        exx
        ld de,-MAPW
        dec c                   ; -> κάτω (i+1, J-1)
        add hl,de
        exx
        ld a,(fast)
        or a
        call z,b_from_bottom
        call nz,bf_from_bottom
        ld a,0                  ; το 41ο είναι ξανά πάνω μισό
        ld bc,#0102
        jp partial

; Ο βρόχος του B. Μπαίνει από το είδος του επόμενου στοιχείου και βγαίνει
; με τους alt καταχωρητές στο στοιχείο ΜΕΤΑ το τελευταίο — που είναι το 41ο.
b_from_bottom:
.bot:   exx
        ld a,b
        cp MAPW
        jr nc,.bvoid
        ld a,c
        cp MAPW
        jr nc,.bvoid
        ld a,(hl)
        inc b                   ; κάτω (I,J) -> πάνω (I+1,J)
        inc hl
        exx
        and #F0
        or 12                   ; γραμμή 5
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        set 3,d
        dec de
        dec de
        ldi                     ; γραμμή 6
        ldi
        res 3,d
        dec ixl
        ret z
        jr b_from_top
.bvoid: inc b
        inc hl
        exx
        xor a
        call zero2
        dec ixl
        ret z
b_from_top:
.top:   exx
        ld a,b
        cp MAPW
        jr nc,.tvoid
        ld a,c
        cp MAPW
        jr nc,.tvoid
        ld a,(hl)
        dec c                   ; πάνω (I,J) -> κάτω (I,J-1)
        add hl,de
        exx
        and #F0                 ; γραμμή 1, offset 0
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        set 3,d
        dec de
        dec de
        ldi                     ; γραμμή 2
        ldi
        res 3,d
        dec ixl
        ret z
        jr b_from_bottom
.tvoid: dec c
        add hl,de
        exx
        xor a
        call zero2
        dec ixl
        ret z
        jr b_from_bottom

; Η γρήγορη εκδοχή του βρόχου B: χωρίς ελέγχους ορίων.
bf_from_bottom:
        exx
        ld a,(hl)
        inc b
        inc hl
        exx
        and #F0
        or 12
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        set 3,d
        dec de
        dec de
        ldi
        ldi
        res 3,d
        dec ixl
        ret z
bf_from_top:
        exx
        ld a,(hl)
        dec c
        add hl,de
        exx
        and #F0
        ld l,a
        ld h,TILE_PAGE
        ldi
        ldi
        set 3,d
        dec de
        dec de
        ldi
        ldi
        res 3,d
        dec ixl
        jr nz,bf_from_bottom
        ret

; ------------------------------------------------------- βοηθητικά

; A = n. fast = 1 αν (var_i, var_j) ΚΑΙ (var_i + n, var_j - n) είναι μέσα
; στον χάρτη, δηλαδή I0 < 96 - n, n ≤ J0 < 96 (χωρίς πρόσημο: οι αρνητικοί
; είναι ≥ 128 και αποτυγχάνουν).
check_fast:
        ld c,a
        ld a,MAPW
        sub c
        ld b,a
        xor a
        ld (fast),a
        ld a,(var_i)
        cp b
        ret nc
        ld a,(var_j)
        cp MAPW
        ret nc
        cp c
        ret c
        ld a,1
        ld (fast),a
        ret

; DE = m, (var_r) = r -> I = (m+r)/2, J = (r-m)/2, ptr = MAP + J*96 + I.
; Γεμίζει τους alt: B' = I, C' = J, HL' = ptr. Χαλάει όλους τους κύριους.
; Το H (σελίδα πλακιδίων) ξαναμπαίνει στο τέλος.
set_ij:
        ld hl,(var_r)
        push hl
        add hl,de
        sra h
        rr l
        ld (var_i),hl
        pop hl
        or a
        sbc hl,de
        sra h
        rr l
        ld (var_j),hl
        add hl,hl               ; J * 96 = J*32 + J*64
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
        push hl
        exx
        pop hl
        ld a,(var_i)
        ld b,a
        ld a,(var_j)
        ld c,a
        exx
        ld h,TILE_PAGE
        ret

; Μισό στοιχείο στα άκρα. A = offset στο πλακίδιο, B = πόσα bytes (1-2),
; C = απόσταση της 2ης γραμμής στα δεδομένα. Το πλακίδιο είναι αυτό των alt
; καταχωρητών (δεν τους προχωράει). DE = προορισμός, γυρίζει +B.
partial:
        ld (p_off),a
        ld a,b
        ld (p_n),a
        ld a,c
        ld (p_str),a
        exx
        ld a,b
        cp MAPW
        jr nc,.void
        ld a,c
        cp MAPW
        jr nc,.void
        ld a,(hl)
        exx
        and #F0
        ld hl,p_off
        or (hl)
        ld l,a
        ld h,TILE_PAGE
        jr .go
.void:  exx
        ld hl,zeros
.go:    push de
        push hl
        ld a,(p_n)
        ld c,a
        ld b,0
        ldir
        pop hl
        pop de
        push de
        set 3,d
        ld a,(p_str)
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    ld a,(p_n)
        ld c,a
        ld b,0
        ldir
        pop de
        ld a,(p_n)
        add a,e
        ld e,a
        ret nc
        inc d
        ret

; Μηδενικά (pen 0) σε 4 ή 2 bytes και των δύο γραμμών· DE προχωράει.
; Μόνο έξω από τον χάρτη — η ταχύτητα εδώ δεν μετράει.
zero4:  push de
        xor a
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        pop de
        push de
        set 3,d
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        inc de
        ld (de),a
        pop de
        inc de
        inc de
        inc de
        inc de
        ret

zero2:  push de
        xor a
        ld (de),a
        inc de
        ld (de),a
        pop de
        push de
        set 3,d
        ld (de),a
        inc de
        ld (de),a
        pop de
        inc de
        inc de
        ret
