; fog6.asm — (2026-11-26) το fog_hl και το fog_iy (fog.asm), στην τράπεζα
; C6: στο κενό FOG6_AT (#4780-#47FF, μετά τις εικόνες των πόρων και πριν από
; τα πλακίδια του εδάφους: src/make_bank6.py, μηδενικά). Διαβάζουν το FOG,
; που είναι μόνο στην C6, άρα τα καλούν μόνο όσοι τρέχουν με την C6 μέσα (η
; σχεδίαση του εδάφους, των πόρων, των κτιρίων). Ελευθέρωσαν 87 bytes του
; κύριου κώδικα (jobmsg.asm).
;
; Ταξιδεύουν στο INIT, μετά το ποντίκι (mouse.asm), και το init_go τα
; αντιγράφει με την C6 μέσα — μετά το units_gfx του start, που γράφει όλη
; την C6 από το res_z.

fg6_p:
        org FOG6_AT,fg6_p
; HL = δείκτης χάρτη -> NZ αν το πλακίδιο είναι εξερευνημένο (με την C6
; μέσα). Κρατάει BC, DE, HL.
fog_hl: push hl
        push bc
        ld a,l
        and 7
        ld c,a
        ld a,h
        and #7F                 ; - MAP
        srl a
        rr l
        srl a
        rr l
        srl a
        rr l
        ld h,a
        ld a,l
        add a,FOG & 255
        ld l,a
        ld a,h
        adc a,FOG >> 8
        ld h,a
        ld a,c
        add a,fog_bit & 255
        ld c,a
        ld b,fog_bit >> 8
        ld a,(bc)
        and (hl)
        pop bc
        pop hl
        ret

; B = i, C = j (με πρόσημο: στο παράθυρο |i|, |j| < 128) -> IY = το byte του
; στο FOG, IXH = το bit του (και έξω από τον χάρτη: συνεπές βήμα). Κρατάει
; BC, DE, HL.
fog_iy: push hl
        push de
        ld a,c
        ld l,a
        rla
        sbc a,a
        ld h,a                  ; HL = j
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de               ; 12 j
        ld a,b
        sra a
        sra a
        sra a
        ld e,a
        add a,a
        sbc a,a
        ld d,a
        add hl,de               ; + i / 8
        ld de,FOG
        add hl,de
        push hl
        pop iy
        ld a,b
        and 7
        add a,fog_bit & 255
        ld l,a
        ld h,fog_bit >> 8
        ld a,(hl)
        ld ixh,a
        pop de
        pop hl
        ret

fg6_e:
        org fg6_p + fg6_e - FOG6_AT
fg6_end:
        assert fg6_e <= TILE_PAGE * 256, 'fog6 past the ground tiles (C6)'
