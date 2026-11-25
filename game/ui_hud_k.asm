; ui_hud_k.asm — (2026-11-25) στο UI_K, μετά το εικονίδιο του IDLE
; VILLAGER (data/ui_k.asm): ο πίνακας των πλήκτρων των κουμπιών (hb_hot,
; ui_hud_j.asm).

hk_prev: db 0                   ; 1: ένα πλήκτρο κουμπιού κρατιέται
; Ανά κουμπί (mockup.BUTTONS / BUTTON_KEYS): η γραμμή του πίνακα πλήκτρων
; και το bit — B T R S N I F1 C U (2026-11-25: το SAVE GAME με το F1,
; γραμμή 1 bit 5, όχι με το V).
hk_tab: db 6, #40, 6, #08, 6, #04, 7, #10, 5, #40, 4, #08, 1, #20, 7, #40
        db 5, #04
