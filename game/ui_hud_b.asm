; ui_hud_b.asm — (M20) τα κουμπιά του HUD: ο φωτισμός (μετά τη γραμματοσειρά).

; A = κουμπί: φωτισμένο (hb_lit) ή όχι (hb_dim) — το φόντο του πλαισίου
; αλλάζει pen, pixel προς pixel (το εικονίδιο μένει).
hb_lit: ld bc,UB_PEN_L * 256 + UB_PEN_R
        ld de,UB_HI_L * 256 + UB_HI_R
        jr hb_swap
hb_dim: ld bc,UB_HI_L * 256 + UB_HI_R
        ld de,UB_PEN_L * 256 + UB_PEN_R
hb_swap:
        ld hl,.c1 + 1
        ld (hl),b
        ld hl,.c2 + 1
        ld (hl),c
        ld hl,.o1 + 1
        ld (hl),d
        ld hl,.o2 + 1
        ld (hl),e
        ld hl,ui_btn            ; η διεύθυνση του πλαισίου (src/make_ui.py)
        call um_ptrn
        ld c,UB_H
.y:     push hl
        ld b,UB_W
.x:     ld a,(hl)
        and #AA
.c1:    cp 0
        jr nz,.n1
        ld a,(hl)
        and #55
.o1:    or 0
        ld (hl),a
.n1:    ld a,(hl)
        and #55
.c2:    cp 0
        jr nz,.n2
        ld a,(hl)
        and #AA
.o2:    or 0
        ld (hl),a
.n2:    inc hl
        djnz .x
        pop hl
        ld a,h                  ; η επόμενη γραμμή: + #800, και μετά την
        add a,8                 ; όγδοη + 80 από την αρχή
        cp #80
        jr c,.n
        sub #40
        ld h,a
        ld a,l
        add a,80
        ld l,a
        ld a,h
        adc a,0
.n:     ld h,a
        dec c
        jr nz,.y
        ret

