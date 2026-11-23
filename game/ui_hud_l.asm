; ui_hud_l.asm — (M22) τα κουμπιά του HUD: στο UI_L (#BF00), στον πάτο της
; περιοχής της στοίβας — μετρημένη σε ολόκληρη παρτίδα ως το #BF9E (98
; bytes)· της μένουν 160. Δεν σώζεται με την παρτίδα (STACK_LOW): σταθερό,
; το γράφει το ui_load σε κάθε εκκίνηση. Μετά το εικονίδιο του SAVE GAME.

; A = θέση, E = τα φανερά -> A = το A-οστό κουμπί τους· μετά το τελευταίο
; το PAUSE (8: πάντα φανερό, όχι στη μάσκα)· 255: κανένα.
hb_nthe:
        push bc
        inc a
        ld c,a
        ld a,e
        ld b,0
.l:     rrca
        jr nc,.n
        dec c
        jr z,.y
.n:     inc b
        bit 3,b
        jr z,.l
        dec c                   ; μία θέση μετά: το PAUSE (B = 8)
        jr z,.y
        ld b,255
.y:     ld a,b
        pop bc
        ret

; (M22) Οι μονές θέσεις (hb_odd, UI_P): ό,τι άλλαξε από το hb_old.
hb_od2: ld a,(hb_vis)
        ld c,a
        ld hl,hb_old
        ld b,1
        jp hb_sync

; (M22) Η συνέχεια του sn_ctr (ui_hud_d.asm): το σπίτι του αντιπάλου.
sn_ct2: ld hl,(sn_home)
        ld (sn_cj),hl
        ret
sn_home:
        db 0, 0                 ; j, i: το lv_home (init.asm, lv_init)
