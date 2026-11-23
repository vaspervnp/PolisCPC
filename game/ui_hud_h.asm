; ui_hud_h.asm — (M22) τα κουμπιά του HUD: η σχεδίαση ενός κουμπιού, και ο
; κέρσορας μόνο στα φανερά. Στο UI_H, μόνο με την C0.

; A = θέση: ζωγραφίζεται όπως λέει το hb_vis (M22: το κουμπί της θέσης,
; hb_vb — ή άδεια).
hb_draw:
        ld c,a
        call hb_vk
        ld de,(UB_BG_L | UB_PEN_R) * 256 + UB_PEN_L + UB_PEN_R
        ld a,UB_PEN_L | UB_BG_R
        jr c,.s
        ld de,UB_BG_L + UB_BG_R + (UB_BG_L + UB_BG_R) * 256
        ld a,e
.s:     ld (.v5 + 1),a
        push de
        ld a,c
        ld hl,ui_btn
        call um_ptrn            ; HL = το πλαίσιο
        pop de
        push hl
        ld b,UB_H
.f:     push hl                 ; το φόντο: η αριστερή άκρη (το δεξί pixel
        ld (hl),d               ; του byte 0), 4 bytes, η δεξιά άκρη
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
        ld (hl),e
        inc hl
.v5:    ld (hl),0
        pop hl
        call hb_nl
        djnz .f
        pop hl
        ld a,c
        call hb_vk
        ret nc                  ; άδεια
        call hb_vb              ; το κουμπί της
        add a,a                 ; το εικονίδιο: ui_ic_tab (dw γραμμές, db η
        add a,a                 ; πρώτη, db πόσες)
        ld e,a
        ld d,0
        ld ix,ui_ic_tab
        add ix,de
        ld b,(ix+2)
        inc b
        jr .s0
.sk:    call hb_nl
.s0:    djnz .sk
        inc hl
        ld e,(ix+0)
        ld d,(ix+1)
        ld a,d                  ; οι γραμμές στην C5 (#7xxx: make_ui.py) ή
        cp #70                  ; εδώ, με το rst 8 (bcopy_to)
        ld a,RAM_SPR
        jr nc,.b
        ld a,RAM_BASE
.b:     ld (BC_SRC),a
        ld b,(ix+3)
.i:     push bc
        push hl
        ex de,hl
        ld bc,4
        ld a,RAM_BASE
        call bcopy_to
        ex de,hl
        pop hl
        call hb_nl
        pop bc
        djnz .i
        ld a,RAM_RES            ; (το age_load το θέλει C6)
        ld (BC_SRC),a
        ld a,(hb_on)            ; ο κέρσορας πάνω του: φωτισμένο
        or a
        ret z
        ld a,(hb_i)
        cp c
        ret nz
        jp hb_lit

; HL = γραμμή της σελίδας του HUD -> η επόμενη (+ #800, και μετά την
; όγδοη + 80 από την αρχή). Μόνο A, HL.
hb_nl:  ld a,h
        add a,8
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
        ret

