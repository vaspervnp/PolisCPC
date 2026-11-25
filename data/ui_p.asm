; ΠΑΡΑΓΕΤΑΙ από src/make_ui.py (M20).

; ο πίνακας των εικονιδίων (UI_P): η πρώτη γραμμή | η τράπεζα x 16 (0: C0)
ui_ic_tab:
        dw ui_ic_0
        db 1 | 0 << 4, 15   ; build (B)
        dw #7380
        db 0 | 5 << 4, 16   ; eject (T)
        dw #7AC0
        db 1 | 5 << 4, 15   ; research (R)
        dw ui_ic_3
        db 2 | 0 << 4, 14   ; patrol (S)
        dw #73C0
        db 0 | 5 << 4, 16   ; age_up (N)
        dw ui_ic_5
        db 1 | 0 << 4, 15   ; idle (I)
        dw #7A40
        db 0 | 5 << 4, 16   ; save (V)
        dw #7A80
        db 0 | 5 << 4, 16   ; cancel (C)
        dw #5F48
        db 2 | 6 << 4, 14   ; pause (U)
