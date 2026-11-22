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
        dw 0
        db 0, 0         ; save: πάντα
        dw ui_ic_7
        db 0, 14
ui_ic_3:  ; patrol, γραμμές 2-13
        db #CC, #CC, #66, #CC
        db #CC, #CC, #33, #CC
        db #33, #33, #33, #66
        db #CC, #CC, #33, #CC
        db #CC, #CC, #66, #CC
        db #CC, #CC, #CC, #CC
        db #CC, #CC, #CC, #CC
        db #CC, #99, #CC, #CC
        db #CC, #33, #CC, #CC
        db #99, #33, #33, #33
        db #CC, #33, #CC, #CC
        db #CC, #99, #CC, #CC
