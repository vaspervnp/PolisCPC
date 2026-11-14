; sound.asm — ο ήχος (M12). Στον κύριο κώδικα από το M14 (ως τότε στην C7,
; που γέμισε). Τον καλεί ΜΟΝΟ η C7 (hit, ζημιά κτιρίου, proj_on), άρα τρέχει
; με την C7 στο #4000: εκεί διαβάζει τα κτίρια (brec_iy).

; ------------------------------------------------------------ ήχος (M12)

; Τέσσερα εφέ στο AY, ΟΛΑ με την περιβάλλουσα του chip (σχήμα 0: πέφτει και
; σβήνει): μία εγγραφή καταχωρητών και τίποτα ανά καρέ. Ένα τη φορά· νέο
; παίζει αν είναι ίσης ή μεγαλύτερης προτεραιότητας, ή αν τελείωσε το
; προηγούμενο (snd_t, καρέ μονάδων). Οι τρεις έντασεις γράφονται πάντα: ένα
; κανάλι που έμεινε στην περιβάλλουσα θα ξαναχτυπούσε με το νέο εφέ.
;
;   κλικ        το SPACE (επιλογή): ψηλός τόνος, A, ~25 ms
;   χτύπημα     μονάδα ή κτίριο που χτυπιέται: θόρυβος, B, ~60 ms
;   κτίριο      του παίκτη έτοιμο: τόνος, C, ~250 ms
;   επίθεση     στον παίκτη, το πολύ μία στα SND_ALERT καρέ: χαμηλός τόνος
;               με θόρυβο, A, ~0,6 s
;
; Το R7 κρατάει πάντα τα bits 6-7 στο 0: η θύρα A του AY είναι είσοδος (το
; πληκτρολόγιο, read_matrix).
SND_CLICK   equ 0
SND_HIT     equ 1
SND_BUILD   equ 2
SND_ALERT_S equ 3
SND_ALERT   equ 250             ; καρέ μονάδων (10 s) ανάμεσα σε ειδοποιήσεις

; A = εφέ. Κρατάει BC, DE, HL, IX, IY.
snd_play:
        push hl
        push de
        push bc
        ld l,a
        ld h,0
        ld de,snd_pri
        add hl,de
        ld b,(hl)               ; η προτεραιότητά του
        ld e,a
        ld a,(snd_t)
        or a
        jr z,.go
        ld a,(snd_cur)
        cp b
        jr c,.go
        jr nz,.out              ; παίζει κάτι σημαντικότερο
        ld a,e                  ; ίσης: όχι ξανά αν μόλις άρχισε (M14: στη
        ld hl,snd_len           ; μάχη, 9 καταχωρητές σε κάθε χτύπημα)
        call tab_a
        ld hl,snd_t
        cp (hl)
        jr z,.out
.go:    ld a,b
        ld (snd_cur),a
        ld a,e
        ld hl,snd_len
        call tab_a
        ld (snd_t),a
        ld a,e                  ; HL = snd_fx + 18 x A
        add a,a
        add a,a
        add a,a
        add a,e
        ld l,a
        ld h,0
        add hl,hl
        ld de,snd_fx
        add hl,de
        ld b,9                  ; 9 ζεύγη (καταχωρητής, τιμή)
.w:     ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        push bc
        call psg_w
        pop bc
        djnz .w
.out:   pop bc
        pop de
        pop hl
        ret

; A = καταχωρητής του AY, C = τιμή.
psg_w:  ld b,#F4
        out (c),a
        ld b,#F6
        ld a,#C0
        out (c),a
        xor a
        out (c),a
        ld b,#F4
        out (c),c
        ld b,#F6
        ld a,#80
        out (c),a
        xor a
        out (c),a
        ret

; Από το hit και τη ζημιά κτιρίου: A = η ομάδα του θύματος. Χτύπημα, και
; στον παίκτη και ειδοποίηση (αν πέρασαν SND_ALERT καρέ). Κρατάει όλα εκτός
; από AF.
snd_struck:
        and #7F
        jr nz,.hit
        ld a,(snd_al)
        or a
        jr nz,.hit
        ld a,SND_ALERT
        ld (snd_al),a
        ld a,SND_ALERT_S
        jp snd_play
.hit:   ld a,SND_HIT
        jp snd_play

; Μία φορά ανά καρέ μονάδων (proj_on): οι μετρητές, το SPACE, το V (η
; αποθήκευση: save_req), και τα κτίρια του παίκτη που έγιναν έτοιμα.
snd_tick:
        push iy
        call .go
        pop iy
        ret
.go:    ld hl,snd_t
        ld a,(hl)
        or a
        jr z,.t
        dec (hl)
.t:     ld hl,snd_al
        ld a,(hl)
        or a
        jr z,.k
        dec (hl)
.k:     ld a,(keyrows + 6)      ; V: σώσε την παρτίδα (main.asm, save_go)
        and #80
        ld hl,snd_vp
        ld c,(hl)
        ld (hl),a
        jr z,.sp
        cp c
        jr z,.sp
        ld a,1
        ld (save_req),a
.sp:    ld a,(keyrows + 5)      ; SPACE: γραμμή 5, bit 7
        and #80
        ld hl,snd_kp
        ld c,(hl)
        ld (hl),a
        jr z,.b
        cp c
        ld a,SND_CLICK
        call nz,snd_play
.b:     ld c,0                  ; τα έτοιμα κτίρια του παίκτη
        ld a,(bld_top)
        or a
        jr z,.cmp
        ld b,a
.l:     ld a,b
        dec a
        push bc
        call brec_iy
        pop bc
        ld a,(iy+B_TYPE)
        inc a
        jr z,.n
        ld a,(iy+B_OWN)
        or a
        jr nz,.n
        ld a,(iy+B_ST)
        or a
        jr z,.n
        inc c
.n:     djnz .l
.cmp:   ld hl,snd_nb
        ld a,(hl)
        ld (hl),c
        cp 255                  ; η πρώτη φορά: μόνο μετράει
        ret z
        cp c
        ret nc
        ld a,SND_BUILD
        jp snd_play

;              R      R      R      R      R      R      R      R      R13
snd_fx: db 0,#28, 1,0,   7,#3E, 8,16,  9,0,   10,0,  11,6,   12,0,  13,0    ; κλικ
        db 6,#0C, 7,#2F, 8,0,   9,16,  10,0,  11,14, 12,0,  2,0,   13,0    ; χτύπημα
        db 4,#A0, 5,0,   7,#3B, 8,0,   9,0,   10,16, 11,60, 12,0,  13,0    ; κτίριο
        db 0,#80, 1,1,   6,#1F, 7,#36, 8,16,  9,0,   10,0,  11,#90, 13,0   ; επίθεση
snd_pri:    db 2, 1, 3, 4
snd_len:    db 2, 2, 7, 15
snd_t:      db 0                ; καρέ ως το τέλος του εφέ που παίζει
snd_cur:    db 0                ; η προτεραιότητά του
snd_al:     db 0                ; καρέ ως την επόμενη ειδοποίηση
snd_kp:     db 0                ; το SPACE στο προηγούμενο καρέ
snd_vp:     db 0                ; το V στο προηγούμενο καρέ
snd_nb:     db 255              ; τα έτοιμα κτίρια του παίκτη (255: άγνωστο)
