; minimap.asm — ο μίνι χάρτης στο HUD. M11.
;
; Ο ίδιος κανόνας με το src/mockup.py: ρόμβος 20 pixels x 21 γραμμές, και το
; pixel (mx, my) είναι το πλακίδιο (F[my + mx + 1], F[my - mx]) με F[k] =
; 96 k / 20 — όταν και τα δύο k είναι στο 0..19 (αλλιώς το φόντο του HUD).
; Εξερευνημένο: το χρώμα του εδάφους του (ή πράσινο για δέντρο)·
; ανεξερεύνητο: μαύρο. Από πάνω το πλαίσιο της κάμερας (mm_rect, bank7.asm).
;
; ΜΙΑ ΓΡΑΜΜΗ ΑΝΑ ΚΑΡΕ ΜΟΝΑΔΩΝ (~2 ms), και μόνο όταν το καρέ είναι ακόμα
; κάτω από το MM_T (units_tick): όλος σε 21 καρέ (~0,8 s) όταν η οθόνη
; ησυχάζει, και περιμένει στα βαριά καρέ — αλλιώς οι αποφάσεις της μάχης
; έπεφταν πέρα από το T_LATE και δεν γίνονταν ποτέ (M8, M10). Τα χρώματα
; της γραμμής με την C6 μέσα (το FOG), μετά στη σελίδα του HUD με την C0.

        include "../data/minimap.asm"
MM_T        equ 5               ; 1/300 s από την αρχή του καρέ: ως εκεί

; Από το units_tick, με την C0.
mm_line:
        ld hl,mm_my             ; η επόμενη γραμμή
        ld a,(hl)
        inc a
        cp MM_N + 1
        jr c,.y
        xor a
.y:     ld (hl),a
        ld a,RAM_RES
        call setram
        ld b,0                  ; k = mx + 10
.p:     push bc
        ld a,(mm_my)            ; u = my + mx + 1
        sub 9
        add a,b
        cp MM_N
        jr nc,.bg               ; (και τα αρνητικά)
        ld hl,mm_f
        call mm_tab
        ld d,a                  ; i
        ld a,(mm_my)            ; v = my - mx
        add a,10
        sub b
        cp MM_N
        jr nc,.bg
        ld hl,mm_f
        call mm_tab
        ld e,a                  ; j
        call fog_at
        and (hl)
        jr z,.st                ; ανεξερεύνητο: pen 0 (A = 0)
        call map_ptr
        ld a,(hl)
        ld c,a
        and 15
        ld hl,mm_res
        call mm_tab
        cp 255
        jr nz,.st
        ld a,c
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,mm_ter
        call mm_tab
        jr .st
.bg:    ld a,MM_BG
.st:    pop bc
        ld hl,mm_buf
        ld e,b
        ld d,0
        add hl,de
        ld (hl),a
        inc b
        ld a,b
        cp MM_N
        jr nz,.p
        ld a,RAM_BASE
        call setram
        ld hl,mm_rect           ; το πλαίσιο της κάμερας (bank7.asm)
        call far7
        ld a,(mm_my)            ; η γραμμή στη σελίδα του HUD
        add a,MM_Y - VIEW_H
        ld c,a
        and 7
        add a,a
        add a,a
        add a,a
        add a,HUD_PAGE >> 8
        ld d,a
        ld a,c                  ; + (y >> 3) x 80 + το πρώτο byte
        rrca
        rrca
        rrca
        and 31
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl               ; 16 r
        ld b,h
        ld c,l
        add hl,hl
        add hl,hl               ; 64 r
        add hl,bc
        ld bc,(MM_X - MM_N / 2) >> 1
        add hl,bc
        ld a,h
        add a,d
        ld h,a
        ld de,mm_buf            ; τα pixels: δεξί του byte, αριστερό του
        ld b,MM_N / 2           ; επόμενου (το x = MM_X - 10 είναι μονό)
.w:     ld a,(de)
        inc de
        call mm_pl
        srl a
        ld c,a
        ld a,(hl)
        and #AA
        or c
        ld (hl),a
        inc hl
        ld a,(de)
        inc de
        call mm_pl
        ld c,a
        ld a,(hl)
        and #55
        or c
        ld (hl),a
        djnz .w
        ret

; A = pen -> το byte του ως αριστερό pixel. Κρατάει HL.
mm_pl:  push hl
        ld hl,mm_penl
        call mm_tab
        pop hl
        ret

; HL = πίνακας, A = δείκτης -> A = το στοιχείο.
mm_tab: add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        ret
