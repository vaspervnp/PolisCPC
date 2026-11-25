; ui_hud_c.asm — (M20) τα κουμπιά του HUD (μετά τα κείμενα, στο UI_S).
; (M22: το hb_idle στο ui_hud_p.asm — εδώ χρειάστηκε ο χώρος για τις ετικέτες)


; C = κουμπί, D = +1 / -1: το επόμενο φανερό της ίδιας σειράς (ή το ίδιο).
hb_step:
        ld e,c
.s:     ld a,e
        add a,d
        ld e,a
        xor c
        and #FC
        ret nz
        ld a,e
        call hb_vk
        jr nc,.s
        ld c,e
        ret

; (2026-11-25) Μεταβλητές του UI_C (ui_hud_d.asm: η ετικέτα, το sn_ctr) —
; εκεί δεν χωρούσαν.
hb_lw:  db 0
sn_cj:  db 0
sn_ci:  db 0
