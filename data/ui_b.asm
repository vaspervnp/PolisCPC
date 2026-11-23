; ΠΑΡΑΓΕΤΑΙ από src/make_ui.py (M20).

; τα κτίρια, με τη σειρά των τύπων: δείκτες
ui_bld:     dw ub_0, ub_1, ub_2, ub_3, ub_4, ub_5, ub_6, ub_7, ub_8, ub_9, ub_10, ub_11, ub_12
ub_0: db 11, 21, 16, 24, 15, 0, 4, 6, 15, 21, 6, 19  ; TOWN CENTER
ub_1: db 5, 9, 16, 22, 20, 6  ; HOUSE
ub_2: db 8, 3, 2, 19, 19, 2, 4, 12, 20  ; BARRACKS
ub_3: db 7, 8, 19, 2, 15, 2, 19, 26  ; GRANARY
ub_4: db 11, 20, 21, 16, 19, 2, 8, 6, 0, 17, 10, 21  ; STORAGE PIT
ub_5: db 6, 14, 2, 19, 12, 6, 21  ; MARKET
ub_6: db 13, 2, 19, 4, 9, 6, 19, 26, 0, 19, 2, 15, 8, 6  ; ARCHERY RANGE
ub_7: db 6, 20, 21, 2, 3, 13, 6  ; STABLE
ub_8: db 4, 7, 2, 19, 14  ; FARM
ub_9: db 5, 21, 16, 24, 6, 19  ; TOWER
ub_10: db 6, 21, 6, 14, 17, 13, 6  ; TEMPLE
ub_11: db 17, 8, 16, 23, 6, 19, 15, 14, 6, 15, 21, 0, 4, 6, 15, 21, 6, 19  ; GOVERNMENT CENTER
ub_12: db 7, 2, 4, 2, 5, 6, 14, 26  ; ACADEMY

; οι μονάδες, ανά σετ
ui_unit:    dw uu_0, uu_1, uu_2, uu_3, uu_4, uu_5
uu_0: db 8, 23, 10, 13, 13, 2, 8, 6, 19  ; VILLAGER
uu_1: db 9, 20, 24, 16, 19, 5, 20, 14, 2, 15  ; SWORDSMAN
uu_2: db 6, 2, 19, 4, 9, 6, 19  ; ARCHER
uu_3: db 8, 23, 10, 13, 13, 2, 8, 6, 19  ; VILLAGER
uu_4: db 7, 9, 16, 17, 13, 10, 21, 6  ; HOPLITE
uu_5: db 7, 4, 2, 23, 2, 13, 19, 26  ; CAVALRY

ui_w_build: db 5, 3, 22, 10, 13, 5  ; BUILD
ui_w_close: db 5, 4, 13, 16, 20, 6  ; CLOSE
ui_w_train: db 5, 21, 19, 2, 10, 15  ; TRAIN
ui_w_split: db 11, 20, 17, 13, 10, 21, 0, 20, 18, 22, 2, 5  ; SPLIT SQUAD
ui_w_busy: db 11, 19, 6, 20, 6, 2, 19, 4, 9, 10, 15, 8  ; RESEARCHING

UB_N        equ 8
UB_W        equ 6              ; bytes
UB_H        equ 17
ui_btn:     dw #50AC, #50B2, #50B8, #50BE, #694C, #6952, #6958, #695E
ui_blbl:    dw ul_0, ul_1, ul_2, ul_3, ul_4, ul_5, ul_6, ul_7, ul_8, ul_9
ul_0: db 5, 3, 22, 10, 13, 5  ; BUILD
ul_1: db 5, 21, 19, 2, 10, 15  ; TRAIN
ul_2: db 8, 19, 6, 20, 6, 2, 19, 4, 9  ; RESEARCH
ul_3: db 11, 20, 17, 13, 10, 21, 0, 20, 18, 22, 2, 5  ; SPLIT SQUAD
ul_4: db 8, 15, 6, 25, 21, 0, 2, 8, 6  ; NEXT AGE
ul_5: db 13, 10, 5, 13, 6, 0, 23, 10, 13, 13, 2, 8, 6, 19  ; IDLE VILLAGER
ul_6: db 9, 20, 2, 23, 6, 0, 8, 2, 14, 6  ; SAVE GAME
ul_7: db 6, 4, 2, 15, 4, 6, 13  ; CANCEL
ul_8: db 5, 17, 2, 22, 20, 6  ; PAUSE
ul_9: db 8, 4, 16, 15, 21, 10, 15, 22, 6  ; CONTINUE
