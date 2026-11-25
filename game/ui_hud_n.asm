; ui_hud_n.asm — (2026-11-25) στο UI_N = make_swap (game/boot.asm: στη
; σελίδα του HUD, τρέχει μόνο στην εκκίνηση, πριν από το ui_load). 18 bytes.

; (M22) Τα καρέ χωρίς έλεγχο των φανερών (hudvis.asm, hb_tick): οι μονές
; θέσεις — ό,τι άλλαξε από το hb_old (hb_sync, ui_hud_i.asm) — και μετά το
; hb_lab (UI_I).
hb_odd: ld hl,hb_lab
        push hl
        ld a,(hb_vis)
        ld c,a
        ld hl,hb_old
        ld b,1
        jp hb_sync
