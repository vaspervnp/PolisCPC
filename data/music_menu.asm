; music_menu.asm — από το src/make_music.py (M21). Μην το αλλάζεις με το χέρι.
mus_menu: db 14
        dw mus_menu_a, mus_menu_b
mus_menu_a:
        db #32, #37, #3A, #19, #17, #3A, #37, #73, #35, #39, #3C, #1A, #19, #B7, #30, #33
        db #37, #15, #13, #32, #33, #77, #36, #39, #3E, #1C, #19, #79, #36, #32, #1F
mus_menu_b:
        db #6B, #72, #67, #6E, #69, #70, #6B, #72, #64, #6B, #67, #6E, #66, #6D, #66, #6A
        db #1F
mus_menu_end:
