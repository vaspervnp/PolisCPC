; ΠΑΡΑΓΕΤΑΙ από src/make_ui.py (M20).

; ο πίνακας των εικονιδίων (UI_K)
ui_ic_1     equ SPR_ARROW + 0    ; eject (C5)
ui_ic_4     equ SPR_ARROW + 64    ; age_up (C5)
ui_ic_2     equ OCC_E + 1600 + 0    ; research (C5)
ui_ic_7     equ OCC_E + 1600 + 52    ; cancel (C5)
ui_ic_5     equ OCC_E + 1600 + 108    ; idle (C5)
ui_ic_tab:
        dw ui_ic_0
        db 1, 14
        dw ui_ic_1
        db 0, 16
        dw ui_ic_2
        db 1, 13
        dw ui_ic_3
        db 2, 12
        dw ui_ic_4
        db 0, 16
        dw ui_ic_5
        db 1, 15
        dw ui_ic_6
        db 0, 12
        dw ui_ic_7
        db 0, 14
        dw ui_ic_8
        db 2, 10
ui_ic_8:  ; pause, γραμμές 2-11
        db #C8, #C0, #C8, #C0
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #42, #C8, #42
        db #C8, #C0, #C8, #C0
