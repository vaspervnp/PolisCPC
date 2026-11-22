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
        call hb_nl              ; η επόμενη γραμμή (ui_hud_k.asm)
        dec c
        jr nz,.y
        ret


; (M22) A = κουμπί της άλλης σειράς -> C = το ίδιο αν φαίνεται, αλλιώς το
; πιο κοντινό φανερό της σειράς του (στήλες A, A^1, A^2, A^3), και carry·
; κανένα: NC, το C όπως ήταν.
hb_vrow:
        ld e,0
.l:     push af
        xor e
        call hb_vk
        jr c,.y
        pop af
        inc e
        bit 2,e
        jr z,.l
        ret
.y:     ld c,a
        pop af
        scf
        ret
