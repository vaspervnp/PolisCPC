; res.asm — οι πόροι του χάρτη (δέντρα, ορυχεία, ψάρια ...) πάνω στο έδαφος. M1.
;
; Κάθε πόρος είναι sprite 8x16 με μάσκα (data/resources.bin, πλεγμένα
; mask,data ανά byte: AND mask, OR data). Πατάει στο πλακίδιό του: το sprite
; αρχίζει στο X του κουτιού του πλακιδίου και 10 γραμμές πάνω από αυτό — ίδια
; τοποθέτηση με το src/mockup.py.
;
; ΣΕΙΡΑ: ο ζωγράφος. Οι σειρές ρόμβων (r = i+j) από πίσω προς τα μπρος· ένα
; δέντρο της σειράς r+1 σκεπάζει όσα είναι πίσω του. Μέσα στην ίδια σειρά τα
; sprites απέχουν 4 bytes και δεν επικαλύπτονται, άρα η σειρά δεν μετράει.
;
; ΨΑΛΙΔΙ: στα όρια του παραθύρου χάρτη, ανά byte οριζόντια και ανά γραμμή
; κάθετα — ένα δέντρο στην άκρη δεν πηδάει, κόβεται.

RES_W       equ 4               ; bytes δεδομένων ανά γραμμή
RES_H       equ 16
RES_SZ      equ 128             ; μάσκα + δεδομένα

draw_resources:
        ; Σειρές που φαίνονται: το sprite της r πιάνει τις γραμμές
        ; 4r - cam_y - 10 ... +16. Από r = (cam_y - 6) >> 2 + 1 ...
        ld hl,(cam_y)
        ld de,-6
        add hl,de
        sra h
        rr l
        sra h
        rr l
        inc hl
        ld (var_r),hl
        ld a,(VIEW_H + 10 + 6) / 4 + 2  ; πόσες σειρές, με περιθώριο
        ld (rows_left),a

.row:   ; i0 = (r + h) >> 1: το πρώτο πλακίδιο με X οθόνης ≥ -2
        ld hl,(var_r)
        ld de,(cam_h)
        add hl,de
        ; x0 = 4*i0 - 2(r+h): 0 αν το r+h είναι ζυγό, -2 αν μονό
        ld a,l
        and 1
        neg
        add a,a
        ld (rx),a
        sra h
        rr l
        ld (var_i),hl
        ; y = 4r - cam_y - 10, με +16 ώστε να χωράει σε byte χωρίς πρόσημο
        ld hl,(var_r)
        add hl,hl
        add hl,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld de,16 - 10
        add hl,de
        ld a,h
        or a
        jr nz,.next             ; έξω από το παράθυρο κάθετα
        ld a,l
        cp VIEW_H + 16
        jr nc,.next
        ld (ry),a
        ; J = r - i0, ptr = MAP + J*96 + i0
        ld hl,(var_r)
        ld de,(var_i)
        or a
        sbc hl,de
        ld a,l
        ld (rj),a
        add hl,hl
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
        ld a,(var_i)
        ld b,a                  ; B = I
        ld a,(rj)
        ld c,a                  ; C = J
        ld a,(rx)
        ld ixl,a                ; IXL = X οθόνης του πλακιδίου
        ld ixh,21               ; 21 πλακίδια καλύπτουν -2 .. 80
        ld de,1-MAPW            ; DE = βήμα (i+1, j-1)
        ; Όλη η σειρά μέσα στον χάρτη: (I, J) και (I+20, J-20).
        ld a,b
        cp MAPW - 20
        jr nc,.tile
        ld a,c
        cp MAPW
        jr nc,.tile
        cp 20
        jr nc,.ftile

.tile:  ld a,b                  ; με ελέγχους ορίων
        cp MAPW
        jr nc,.skip
        ld a,c
        cp MAPW
        jr nc,.skip
        ld a,(hl)
        and #0F
        call nz,res_here
.skip:  inc b
        dec c
        add hl,de
        ld a,ixl
        add a,4
        ld ixl,a
        dec ixh
        jr nz,.tile
        jr .next

.ftile: ld a,(hl)               ; χωρίς: όλη η σειρά είναι μέσα
        and #0F
        call nz,res_here
        add hl,de
        ld a,ixl
        add a,4
        ld ixl,a
        dec ixh
        jr nz,.ftile

.next:  ld hl,(var_r)
        inc hl
        ld (var_r),hl
        ld a,(rows_left)
        dec a
        ld (rows_left),a
        jp nz,.row
        ret

; Πόρος A στο πλακίδιο του σαρωτή: X από το IXL. Κρατάει BC, DE, HL, IX.
res_here:
        push bc
        push de
        push hl
        ld b,a
        ld a,ixl
        ld (rx),a
        ld a,b
        call blit_res
        pop hl
        pop de
        pop bc
        ret

; A = πόρος (1-15), (rx) = X οθόνης σε bytes (προσημασμένο), (ry) = Y + 16.
blit_res:
        ; sprite = res_gfx + (A-1)*128
        dec a
        rrca                    ; *128 = >> 1 με το bit 0 στο 7
        ld e,a
        and #7F
        ld d,a
        ld a,e
        and #80
        ld e,a
        ld hl,res_gfx
        add hl,de
        ld (b_src),hl

        ; Ολόκληρο μέσα στο παράθυρο; 0 ≤ X ≤ 76 και 0 ≤ Y ≤ 128. Τότε χωρίς
        ; ψαλίδι, ξετυλιγμένο — η συνηθισμένη περίπτωση.
        ld a,(rx)
        cp 80 - RES_W + 1
        jr nc,.clip
        ld a,(ry)
        sub 16
        jr c,.clip
        cp VIEW_H - RES_H + 1
        jr nc,.clip
        ld l,a                  ; DE = line_addr[y] + x
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(rx)
        add a,e
        ld e,a
        jr nc,.nc
        inc d
.nc:    ld hl,(b_src)
        ld b,RES_H
.fline: push de
        repeat RES_W - 1
        ld a,(de)
        and (hl)
        inc l                   ; το sprite είναι στοιχισμένο στα 128:
        or (hl)                 ; οι 8 bytes της γραμμής δεν αλλάζουν σελίδα
        inc l
        ld (de),a
        inc de
        rend
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc hl
        ld (de),a
        pop de
        ld a,d                  ; η επόμενη γραμμή οθόνης
        add a,#08
        ld d,a
        and #38
        jr nz,.fok
        ld a,e
        add a,80
        ld e,a
        ld a,d
        adc a,#C0
        ld d,a
.fok:   djnz .fline
        ret

.clip:
        ; στήλες: c0 = max(0, -x)/... σε bytes δεδομένων
        ld a,(rx)
        ld c,0
        bit 7,a
        jr z,.xpos
        neg
        ld c,a                  ; c0 = -x
        cp RES_W
        ret nc
.xpos:  ld a,c
        ld (b_c0),a
        ld a,(rx)               ; c1 = min(4, 80 - x)
        ld b,a
        ld a,80
        sub b
        jr c,.xc1               ; (για αρνητικό x το 80-x > 4)
        cp RES_W
        jr c,.xok
.xc1:   ld a,RES_W
.xok:   ld hl,b_c0
        sub (hl)
        ret z
        ret c
        ld (b_n),a

        ; γραμμές: l0 = max(0, -y), l1 = min(16, 144 - y)
        ld a,(ry)
        sub 16                  ; y (μπορεί αρνητικό)
        ld c,0
        jr nc,.ypos
        neg
        ld c,a
.ypos:  ld a,c
        ld (b_l0),a
        ld a,(ry)
        ld b,a
        ld a,VIEW_H + 16
        sub b                   ; 144 - y
        cp RES_H
        jr c,.yok
        ld a,RES_H
.yok:   ld hl,b_l0
        sub (hl)
        ret z
        ret c
        ld (b_lines),a

        ; πρώτη γραμμή οθόνης: y + l0
        ld a,(ry)
        sub 16
        ld hl,b_l0
        add a,(hl)
        ld (b_y),a
        ; πηγή: + l0*8 + c0*2
        ld a,(b_l0)
        add a,a
        add a,a
        add a,a
        ld e,a
        ld a,(b_c0)
        add a,a
        add a,e
        ld e,a
        ld d,0
        ld hl,(b_src)
        add hl,de
        ld (b_src),hl

.line:  ld a,(b_y)              ; DE = line_addr[y] + x + c0
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(rx)
        ld hl,b_c0
        add a,(hl)
        ld l,a
        ld h,0
        add hl,de
        ex de,hl
        ld hl,(b_src)
        ld a,(b_n)
        ld b,a
.byte:  ld a,(de)
        and (hl)
        inc hl
        or (hl)
        inc hl
        ld (de),a
        inc de
        djnz .byte
        ld hl,(b_src)
        ld de,RES_W * 2
        add hl,de
        ld (b_src),hl
        ld hl,b_y
        inc (hl)
        ld hl,b_lines
        dec (hl)
        jr nz,.line
        ret
