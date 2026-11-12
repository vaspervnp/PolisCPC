; age3.asm — ΠΑΡΑΓΕΤΑΙ από src/make_bank6.py. Οι εποχές 3 (Χαλκού) και 4
; (Σιδήρου), M9: ανά τύπο το ύψος, η εικόνα (στην C6, από το AGE3.BIN /
; AGE4.BIN) και αν άλλαξε από την προηγούμενη εποχή (1: ξαναζωγραφίζεται).

AGE3_LEN    equ 5072
age3_tab:
        db 46
        dw #4A80
        db 1                    ; town_center
        db 19
        dw #4D60
        db 1                    ; house
        db 29
        dw #4DF8
        db 1                    ; barracks
        db 27
        dw #4F54
        db 1                    ; granary
        db 21
        dw #5098
        db 1                    ; storage_pit
        db 28
        dw #5140
        db 1                    ; market
        db 29
        dw #5290
        db 1                    ; archery
        db 29
        dw #53EC
        db 1                    ; stable
        db 24
        dw #5548
        db 0                    ; farm
        db 28
        dw #5668
        db 1                    ; tower
        db 30
        dw #5748
        db 1                    ; temple
        db 51
        dw #58B0
        db 1                    ; gov_center
        db 39
        dw #5BE0
        db 1                    ; academy
AGE4_LEN    equ 5260
age4_tab:
        db 47
        dw #4A80
        db 1                    ; town_center
        db 19
        dw #4D70
        db 0                    ; house
        db 29
        dw #4E08
        db 0                    ; barracks
        db 27
        dw #4F64
        db 0                    ; granary
        db 21
        dw #50A8
        db 0                    ; storage_pit
        db 28
        dw #5150
        db 0                    ; market
        db 29
        dw #52A0
        db 0                    ; archery
        db 29
        dw #53FC
        db 0                    ; stable
        db 24
        dw #5558
        db 0                    ; farm
        db 36
        dw #5678
        db 1                    ; tower
        db 39
        dw #5798
        db 1                    ; temple
        db 51
        dw #596C
        db 0                    ; gov_center
        db 39
        dw #5C9C
        db 0                    ; academy
