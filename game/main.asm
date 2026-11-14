; main.asm — Polis, Amstrad CPC 6128.
;
;     ./game/build.sh            -> build/polis.dsk, build/polis.sna, .sym
;
; M1: ο χάρτης 96x96 στη μνήμη (#8000) και το ισομετρικό έδαφος + οι πόροι
; σε ολόκληρο το παράθυρο χάρτη (ground.asm, res.asm).
; M3: οι μονάδες στα 25 Hz, με επαναφορά από τον καθρέφτη του φόντου στην
; τράπεζα C4 και sprites στην C5 (units.asm). M2: κύλιση με το CRTC και HUD
; με split-screen (scroll.asm, screen.asm). M4: 128 μονάδες, κέρσορας,
; επιλογή και εντολή κίνησης (units.asm, input.asm). M5: εύρεση δρόμου
; και κάδοι (pathing.asm). M6: πόροι και χωρικοί (gather.asm). Με -DBARS=1 βγαίνει η
; οθόνη ελέγχου του M0 (λωρίδες παλέτας) αντί για τον χάρτη.
;
; Τι κάνει το M0 (η υποδομή κάτω από όλα):
;
;   1. κλείνει το firmware: δικός μας χειριστής διακοπής (EI/RET στο #38),
;      ROMs κλειστές, στοίβα στην κορυφή της περιοχής δεδομένων
;   2. Mode 0 και οι 16 ΣΩΣΤΕΣ αποχρώσεις, απευθείας στο gate array από τον
;      πίνακα `polis_hw` του ../palette.asm (που παράγεται από src/gfx.py —
;      ένας ορισμός της παλέτας για γραφικά ΚΑΙ κώδικα)
;   3. ζωγραφίζει τα 16 pens ως κάθετες λωρίδες των 10 pixels, για να
;      κρίνεται η παλέτα με μια ματιά
;   4. ο κύριος βρόχος: συγχρονισμός με το VSYNC, και το BORDER γίνεται
;      κόκκινο όσο τρέχει η δουλειά του καρέ — το ύψος της κόκκινης λωρίδας
;      ΕΙΝΑΙ ο χρόνος. Μια γραμμή σάρωσης = 64 µs, ένα καρέ = 312 γραμμές.
;
; ΧΑΡΤΗΣ ΜΝΗΜΗΣ (milestones.md, Μέρος Β)
;
;   #0000-#003F   restarts — μόνο το RST #38 χρησιμοποιείται
;   #0040-#3FFF   κώδικας
;   #4000-#7FFF   παράθυρο τράπεζας (γραφικά) — όχι ακόμα
;   #8000-#BFFF   χάρτης, μονάδες, buffers — η στοίβα στην κορυφή
;   #C000-#FFFF   οθόνη

SCREEN      equ #C000
RAM_RES     equ #C6             ; extra τράπεζα 2: πόροι και κτίρια
RAM_CMP     equ #C7             ; extra τράπεζα 3: τα μεταγλωττισμένα sprites
STACK_TOP   equ #C000           ; η στοίβα κατεβαίνει ΚΑΤΩ από την οθόνη

GA          equ #7F             ; gate array: high byte της θύρας
GA_RMR      equ #8C             ; Mode 0, κάτω ΚΑΙ πάνω ROM κλειστές
PPI_B       equ #F5             ; bit 0 = VSYNC
CRTC_SEL    equ #BC
CRTC_DAT    equ #BD

HW_BLACK    equ #54
HW_RED      equ #4C             ; firmware 6, bright red
HW_GREEN    equ #52             ; firmware 18, bright green
HW_YELLOW   equ #4A             ; firmware 24, bright yellow
BD_DISK     equ HW_BLACK        ; το περιθώριο όσο σώζεται / φορτώνεται: μαύρο,
                                ; όπως πάντα (ως το M14 κίτρινο)

        ifdef SNA
        buildsna                ; ο τύπος εξόδου: snapshot αντί για .bin
        bankset 0               ; οι 64 KB της βάσης
        endif

        org #0040

start:
        di
        ld sp,STACK_TOP
        ifndef BARS
        ld hl,map_z             ; ο χάρτης στη θέση του (#8000), ΠΡΩΤΟΣ: είναι
        ld de,MAP               ; το τελευταίο του POLIS.BIN, και μπορεί να
        call dzx0               ; περνάει πάνω από το BOOT (M12)
        endif
        ld hl,boot_phys         ; οι ρουτίνες της εκκίνησης στο BOOT (boot.asm)
        ld de,BOOT
        ld bc,BOOT_LEN
        ldir
        im 1
        ld a,#C3                ; JP int_handler (screen.asm)
        ld (#0038),a
        ld hl,int_handler
        ld (#0039),hl
        ld hl,rst_code          ; RST #28: η αλλαγή γραμμής των
        ld de,#0028             ; μεταγλωττισμένων sprites (units.asm)
        ld bc,rst_len
        ldir

        ld bc,GA*256+GA_RMR     ; Mode 0, ROMs κλειστές
        out (c),c

        call crtc_setup
        call set_palette
        ifdef BARS
        call draw_bars
        else
        ; ΤΑ ΣΥΜΠΙΕΣΜΕΝΑ ΖΟΥΝ ΜΕΤΑ ΤΟΝ ΚΩΔΙΚΑ, ακόμα και πέρα από το #4000
        ; (κύρια RAM): διαβάζονται ΜΟΝΟ εδώ, με την C0, και πριν το HUD
        ; γράψει πάνω τους. Η οθόνη (#C000) είναι ο ενδιάμεσος χώρος.
        ld hl,ugfx_phys         ; (ugfx.asm: μόνο εδώ, στο #B000)
        ld de,UGFX
        ld bc,UGFX_LEN
        ldir
        call units_gfx          ; τα sprites -> C5, μέσω της οθόνης
        call menu               ; πολιτισμός ή φόρτωμα (menu.asm, M12)
        ld hl,init_z            ; οι ρουτίνες της εκκίνησης στην οθόνη
        ld de,INIT              ; (init.asm, M11), και πίσω τους η
        call dzx0               ; αποθήκευση (savegame.asm, M12) και οι
                                ; ρουτίνες της σελίδας του HUD
        ld hl,hud_z             ; (από εδώ: ο rasm δίνει λάθος τιμή στις
        call hud_init           ; ετικέτες των συμπιεσμένων μέσα στο init_z)
                                ; το HUD -> #4000, μέσω της οθόνης
        ld hl,VOID16            ; το «πλακίδιο» εκτός χάρτη της κύλισης
        ld b,16
.z:     ld (hl),0
        inc hl
        djnz .z
        call units_init
        ld hl,hp_init           ; η υγεία όλων (bank7.asm)
        call far7
        call bld_init           ; το Κέντρο Πόλης στον χάρτη, πριν την εύρεση
        call nav_init           ; δρόμου (η κάτοψή του είναι εμπόδιο)
        call gather_init        ; οι πηγές, και οι αριθμοί του HUD
        call fog_init           ; ο εξερευνημένος χάρτης (M11)
        call clear_screen       ; (και ο κώδικας της εκκίνησης στο INIT)
        ld de,#067F             ; R6 = 127, μία φορά (screen.asm)
        call crtc_w
        ld a,1
        ld (split_req),a        ; από το επόμενο VSYNC: δύο καρέ CRTC, χάρτης + HUD
        ld (redraw),a
        endif
        ei

; ---------------------------------------------------------- κύριος βρόχος

frame:
        call wait_vsync
        ld a,(redraw)           ; ολόκληρο το παράθυρο, μόνο όταν ζητηθεί:
        or a                    ; στην αρχή και σε άλμα της κάμερας
        jr z,.idle
        xor a
        ld (redraw),a
        ld (v_pend),a           ; μια κάθετη κύλιση στη μέση: ξεχνιέται
        inc a
        ld (phase),a            ; 1 = σχεδιάζει (το διαβάζει το tests/m1_check.py)
        ld hl,0                 ; πλήρης σχεδίαση: η κύλιση ξεκινάει από το 0,
        ld (scr_s),hl           ; οπότε καμία γραμμή δεν σπάει στα 2 KB
        call build_lines
        call render
        ld a,2                  ; 2 = το παράθυρο σχεδιάστηκε
        ld (phase),a
        call bg_snapshot        ; ο καθρέφτης του φόντου για τις μονάδες
        call units_forget       ; η οθόνη ξαναγράφτηκε: δεν έχουν ίχνη να σβήσουν
        ld a,6                  ; 6 = και ο καθρέφτης έτοιμος
        ld (phase),a
.idle:  ld hl,ticks             ; οι μονάδες στα 25 Hz: κάθε 2ο καρέ
        inc (hl)
        bit 0,(hl)
        jr nz,frame
        ld a,(phase)
        cp 6
        jr nz,frame             ; όχι πριν τον καθρέφτη
        ld a,(tut_on)           ; το tutorial (tutor.asm, στην C6): με το
        or a                    ; παράθυρο ανοιχτό (carry), το παιχνίδι
        ld hl,tut_go            ; περιμένει
        call nz,far6
        jr c,frame
        ld a,(bd_busy)          ; η λωρίδα του χρόνου (το τέλος της παρτίδας,
        call border             ; M10: ένα χρώμα και στα δύο)
        ld a,3
        ld (uphase),a           ; 3 = τρέχει το καρέ μονάδων (tests/m3_check.py)
        call units_tick
        ld a,(save_req)         ; V (bank7.asm, snd_tick): η παρτίδα στη
        or a                    ; δισκέτα, στο τέλος του καρέ (M12)
        call nz,save_go
        ld a,4
        ld (uphase),a
        ld a,(bd_idle)
        call border
        jr frame

; Η δουλειά του καρέ. Στο M0 είναι άδεια: η κόκκινη λωρίδα δείχνει μόνο το
; κόστος του ίδιου του μετρητή. Τα επόμενα milestones μπαίνουν εδώ.
frame_work:
        ret

; Η αποθήκευση (savegame.asm): από τις κρυφές σειρές της σελίδας του HUD
; στην οθόνη, εκεί τρέχει, και μετά η οθόνη από την αρχή.
save_go:
        ld hl,SVM_STORE
        ld de,SVM
        ld bc,SVM_LEN
        ldir
        ld hl,save_req          ; 2: το τέλος μιας πίστας της εκστρατείας
        dec (hl)                ; (M13: δεν γυρίζει)
        jp nz,mod_camp
        call mod_save
        ld a,1
        ld (redraw),a
        ret

; Το παράθυρο χάρτη από το μηδέν: έδαφος, μετά οι πόροι από πάνω.
render:
        ld a,RAM_RES            ; έδαφος, πόροι και κτίρια: στην C6
        call setram
        call draw_ground
        call rg_full            ; τα κτίρια του παραθύρου (buildings.asm)
        call bld_cands
        call draw_resources
        ld a,255                ; και όσα είναι μπροστά από όλους τους πόρους
        call bld_flush
        ld a,RAM_BASE
        jp setram

; ------------------------------------------------------------ ρουτίνες

; Περιμένει την ΑΡΧΗ του VSYNC: πρώτα να τελειώσει τυχόν τρέχον, μετά να
; ξεκινήσει νέο. Αλλιώς δύο καρέ μέσα στον ίδιο παλμό θα μετρούσαν ως δύο.
wait_vsync:
        ld b,PPI_B
.on:    in a,(c)
        rra
        jr c,.on
.off:   in a,(c)
        rra
        jr nc,.off
        ret

; A = hardware colour του border (pen 16).
border:
        ld bc,GA*256+#10
        out (c),c
        out (c),a
        ret

; Το τέλος της παρτίδας (ai_end, με call0): στην κάρτα του HUD η σημαία
; (νίκη) ή η νεκροκεφαλή (ήττα) από το πάνελ των εντολών, πάνω από το
; ψηφίο της. Το περιθώριο μένει μαύρο.
END_Y       equ 36              ; γραμμή του HUD: η 2η σειρά των εντολών
END_WIN_X   equ 57              ; rally (η σημαία), byte
END_LOSE_X  equ 64              ; delete (η νεκροκεφαλή)
END_TOP     equ 19              ; η κάρτα: 4 bytes x 16 γραμμές από εδώ
hud_end:
        ld a,(game_end)
        ld hl,HUD_PAGE + (END_Y & 7) * #800 + (END_Y >> 3) * 80 + END_WIN_X
        dec a
        jr z,.s
        ld hl,HUD_PAGE + (END_Y & 7) * #800 + (END_Y >> 3) * 80 + END_LOSE_X
.s:     ld de,HUD_PAGE + (END_TOP & 7) * #800 + (END_TOP >> 3) * 80 + CARD_X
        ld b,16
.l:     push bc
        push hl
        push de
        ld bc,4
        ldir
        pop hl
        call .nl
        ex de,hl
        pop hl
        call .nl
        pop bc
        djnz .l
        ret
.nl:    ld a,h                  ; η γραμμή από κάτω (όπως το next_line,
        add a,#08               ; που υπάρχει μόνο στο BARS)
        ld h,a
        and #38
        ret nz
        ld a,l
        add a,80
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
        ret

        ifdef BARS            ; μόνο στην οθόνη ελέγχου του M0
; Δεκάξι κάθετες λωρίδες των 5 bytes (10 pixels): pen 0 αριστερά, pen 15
; δεξιά. Μία γραμμή 80 bytes χτίζεται μία φορά και αντιγράφεται 200 φορές.
draw_bars:
        ld de,linebuf
        ld hl,pen_pair
        ld c,16
.pen:   ld a,(hl)
        ld b,5
.byte:  ld (de),a
        inc de
        djnz .byte
        inc hl
        dec c
        jr nz,.pen

        ld hl,SCREEN            ; η γραμμή y είναι στο #C000 + (y%8)*#800 + (y/8)*80
        ld b,200
.line:  push bc
        push hl
        ex de,hl
        ld hl,linebuf
        ld bc,80
        ldir
        pop hl
        call next_line
        pop bc
        djnz .line
        ret


; HL = διεύθυνση γραμμής -> HL = η από κάτω της.
next_line:
        ld a,h
        add a,#08
        ld h,a
        and #38
        ret nz                  ; ίδια σειρά χαρακτήρων
        ld a,l                  ; τέλος σειράς: πίσω 8 γραμμές, μπρος 80 bytes
        add a,80
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
        ret

; Το byte Mode 0 με ΤΟ ΙΔΙΟ pen και στα δύο pixels. Η σειρά των bits είναι
; αντιδιαισθητική (src/cpcimg.py)· ο έλεγχος tests/m0_check.py διαβάζει
; πίσω την οθόνη και επιβεβαιώνει κάθε λωρίδα.
pen_pair:
        db #00,#C0,#0C,#CC,#30,#F0,#3C,#FC,#03,#C3,#0F,#CF,#33,#F3,#3F,#FF
        endif

        include "../palette.asm"
        include "ground.asm"
        include "res.asm"
        include "zx0.asm"
        include "screen.asm"
        include "scroll.asm"
        include "units.asm"
        include "pathing.asm"
        include "../data/nav.asm"
        include "../data/gather.asm"
        include "gather.asm"
        include "../data/bld.asm"
        include "../data/compiled.asm"
        include "buildings.asm"
        include "occlude.asm"
        include "disk.asm"
        include "fog.asm"
        include "minimap.asm"
        include "sound.asm"

        ifdef BARS
linebuf:
        ds 80
        endif

; Η διεύθυνση κάθε γραμμής οθόνης: #C000 + (y%8)*#800 + (y/8)*80.
line_addr:
ly = 0
        repeat 200
        dw SCREEN + (ly & 7) * #800 + (ly >> 3) * 80
ly = ly + 1
        rend

zeros:  ds 16                   ; «πλακίδιο» έξω από τον χάρτη

; ---------------------------------------------------------- μεταβλητές
cam_x:      dw 98               ; bytes κόσμου, ζυγό — η πόλη του παίκτη
cam_y:      dw 303              ; γραμμές κόσμου, ≡ 3 (mod 4)
cam_h:      dw 0                ; (cam_x - XOFF) / 2
redraw:     db 0
save_req:   db 0                ; 1: σώσε την παρτίδα (V, M12)· 2: η
                                ; επόμενη πίστα (lv_after, M13)
load_req:   db 0                ; 1: το μενού διάλεξε φόρτωμα (M12)
phase:      db 0
scr:        dw 0
ptype:      db 0
lead:       db 0
fast:       db 0
var_r:      dw 0
var_i:      dw 0
var_j:      dw 0
p_off:      db 0
p_n:        db 0
p_str:      db 0
rows_left:  db 0
rx:         db 0
ry:         db 0
rj:         db 0
b_src:      dw 0
b_c0:       db 0
b_n:        db 0
b_l0:       db 0
b_lines:    db 0
b_y:        db 0
rn:         db 0
clip_x0:    db 0                ; το παράθυρο ψαλιδίσματος των πόρων (res.asm)
clip_x1:    db 80
clip_y0:    db 0
clip_y1:    db VIEW_H
sdx:        db 0                ; κύλιση που ζητήθηκε αυτό το καρέ (scroll.asm)
sdy:        db 0
sdiag:      db 0                ; η διαγώνια κύλιση εναλλάξ (scroll.asm)
v_pend:     db 0                ; η κάθετη κύλιση στη μέση (2 καρέ)
v_y0:       db 0                ; η γραμμή της λωρίδας: 0 ή VIEW_H - 8
v_ny:       dw 0                ; η νέα cam_y
v_ns:       dw 0                ; η νέα μετατόπιση
v_oy:       dw 0
v_r:        dw 0                ; η επόμενη σειρά ρόμβων των πόρων
v_save:     ds 16               ; οι 8 γραμμές του line_addr που άλλαξαν
v_shx:      db 0                ; η κύλιση από το προηγούμενο καρέ μονάδων
v_shy:      db 0
rect_n:     db 0                ; ορθογώνια που σβήνονται/ζωγραφίζονται (units.asm)
col_c:      db 0
col_y:      db 0
col_off:    db 0
col_w:      dw 0
col_par:    db 0                ; draw_column: η ισοτιμία του s
col_n:      db 0
col_i:      dw 0
col_j:      dw 0
col_ptr:    dw 0
col_t0:     dw 0
col_t1:     dw 0
col_lp:     dw 0
col_r0:     db 0                ; ο πόρος του τρέχοντος / επόμενου πλακιδίου
col_r1:     db 0
col_sy:     db 0
col_y0:     db 0                ; το κάθετο παράθυρο του draw_column (γραμμές)
col_y1:     db VIEW_H
sr_y0:      db 0                ; strip_resources
sr_n:       db 0
sr_res:     db 0
sr_src:     db 0
sr_line:    dw 0                ; η πρώτη γραμμή του sprite της ομάδας
el_t:       db 0
row_ent:    dw 0
row_dst:    dw 0
pcx:        db 98               ; η κάμερα στο προηγούμενο καρέ μονάδων (low)
pcy:        db 303 & 255
utick:      db 0                ; τα καρέ μονάδων (η ισοτιμία του βήματος)
think_i:    db 0                ; ο κυκλικός δείκτης της απόφασης
seed:       dw #ACE1
g_x:        db 0                ; το τελευταίο βήμα του unit_go
g_y:        db 0
rl_n:       db 0                ; πόσες στο RLIST, NEWLIST, ORDER
nl_n:       db 0
ord_n:      db 0                ; μονάδες στο ORDER
ord_tot:    db 0                ; + γωνία + κέρσορας
cur_x:      db 40               ; ο κέρσορας στην οθόνη (input.asm)
cur_y:      db 64
cin:        db 0
keyrows:    ds 10               ; ο πίνακας πλήκτρων αυτού του καρέ
cin_prev:   db 0
box_on:     db 0
sel_n:      db 0
cw_x:       dw 0
cw_y:       dw 0
bx0:        dw 0
bx1:        dw 0
by0:        dw 0
by1:        dw 0
mv_n:       db 0                ; πόσες στο MOVERS
cmd_cell:   db 0                ; pathing.asm
n_cell:     db 0
n_t:        db 0
n_i:        dw 0
n_j:        dw 0
n_lim:      dw 0
n_ti:       dw 0                ; το πλακίδιο του σημείου που δοκίμασε το try_step
n_tj:       dw 0
n_a:        dw 0                ; nav_step: 2 fx + fy - 383, fy - 2 fx + 383
n_b:        dw 0
n_na:       dw 0
n_nb:       dw 0
n_same:     db 0
n_gd:       db 0                ; ακολούθηση τοίχου
n_try:      db 0
n_dist:     db 0
n_rd:       db 0                ; BFS: ανάγνωση και γράψιμο στην ουρά
n_wr:       db 0
n_cnt:      db 0
n_busy:     db 0                ; 1 = το BFS συνεχίζει στο επόμενο καρέ
n_wx:       dw 0
n_wy:       dw 0
n_way:      db 0
n_in:       db 0
n_dir:      db 0
n_page:     db 0
w_page:     db 0                ; η σελίδα του πεδίου στο way_point (pathing.asm)
bfs_c:      db 0                ; το κελί-στόχος του BFS σε εξέλιξη (pathing.asm)
field_rr:   db 0
field_f:    db 0
field_tc:   db 255, 255
nphase:     db 0                ; 1 -> 2 γύρω από το BFS (tests/m5_check.py)
bphase:     db 0                ; 1 -> 2 γύρω από τη μέτρηση στόχευσης
bench_req:  db 0
t_bestd:    db 0                ; στόχευση
hud_val:    dw 200, 200, 100, 200, START_VIL, START_AGE ; η μπάρα: τροφή, ξύλο,
                                ; χρυσό, πέτρα, πληθυσμός, εποχή (gather.asm)
ai_val:     dw 200, 200, 100, 200 ; ο αντίπαλος (M10): τροφή, ξύλο, χρυσό, πέτρα
ai_on:      db 1                ; 0: ο αντίπαλος δεν σκέφτεται (tests M0-M9)
tut_on:     db 0                ; το tutorial τρέχει (menu.asm, tutor.asm)
tut_win:    db 0                ; 2 να ζωγραφιστεί, 1 ανοιχτό, 0 κλειστό
tut_step:   db 0                ; το βήμα
town_full:  db 0                ; 1: η αρχή με 12 + 12 μονάδες της πόλης
                                ; (tests M1-M11: το M4.Game το γράφει στο .sna)
fr_j:       db 0                ; fog_reveal (fog.asm, M11)
fr_j1:      db 0
fr_i0:      db 0
fr_i1:      db 0
fd_x:       dw 0                ; fd_add: η νέα εγγραφή (wx, y0, y1)
fd_y0:      dw 0
fd_y1:      dw 0
fd_c:       db 0
fog_on:     db 1                ; 0: όλα εξερευνημένα (tests M1-M10, M11)
mm_my:      db 0                ; minimap.asm: η γραμμή του καρέ
mm_buf:     ds MM_N             ; τα pens της
game_end:   db 0                ; 1 νίκη, 2 ήττα (bank7.asm: ai_end)
        ifdef BARS              ; η λωρίδα του χρόνου: μόνο στην οθόνη
bd_busy:    db HW_RED           ; ελέγχου του M0 — στο παιχνίδι το
        else                    ; περιθώριο είναι πάντα μαύρο (το τέλος
bd_busy:    db HW_BLACK         ; της παρτίδας στο HUD: hud_end)
        endif
bd_idle:    db HW_BLACK
hud_dirty:  db 0                ; bits 0-5: ποιοι αριθμοί της μπάρας άλλαξαν
u_rescan:   db 0                ; units_forget: όλες οι ενεργές, στο επόμενο καρέ
bmode:      db 255              ; ο τύπος κτιρίου που τοποθετείται (255 κανένας)
sel_bld:    db 255              ; το επιλεγμένο κτίριο (255 κανένα)
bk_prev:    db 255              ; το πλήκτρο κτιρίων του προηγούμενου καρέ
cur_force:  db 0                ; ο κέρσορας άλλαξε όψη: ξαναζωγράφισέ τον
bn_t:       db 0                ; bld_new
bn_n:       db 0
bp_ij:      dw 0                ; bld_place: j0, i0
bp_slot:    db 0
cand_n:     db 0                ; τα υποψήφια κτίρια μιας σχεδίασης
cand_k:     db 0
cand_c:     db 0
cand:       ds 2 * CAND_MAX
rg_x0:      db 0                ; η περιοχή της σχεδίασης
rg_x1:      db 0
rg_y0:      db 0
rg_y1:      db 0
bf_r:       db 0
bb_sx:      dw 0                ; blit_bld
bb_c0:      db 0
bb_cn:      db 0
bb_l0:      db 0
bb_ln:      db 0
bb_x:       db 0
bb_y:       db 0
bb_w2:      db 0
col_rr:     dw 0                ; draw_column: η σειρά ρόμβων της ομάδας
rq_x:       dw 0                ; η επανασχεδίαση ενός κτιρίου
rq_yb:      dw 0
rq_h:       db 0
rq_n:       db 255
rq_half:    db 0                ; τα κομμάτια RQ_ROWS της στήλης του rq που έγιναν
RQ_LEN      equ $ - rq_x        ; (hudc.asm: rq_free, rqp_x)
bq_tot:     db 0                ; μονάδες σε όλες τις ουρές
bld_top:    db 1                ; οι βρόχοι των κτιρίων: ως εδώ (bld_new, >= 1)
DQ_MAX      equ 4
dq_n:       db 0                ; bank7.asm: οι νεκροί για το died_flush
dq:         ds DQ_MAX
c_dx:       dw 0
c_dy:       dw 0
occ_c:      db 0                ; occlude.asm: πόσα στο OCC_L
occ_dirty:  db 1                ; η λίστα ξανά (και η κάμερα: occ_cx, occ_cy)
occ_cx:     dw 0
occ_cy:     dw 0
occ_w:      dw 0
occ_q:      ds 8
occ_u:      dw 0
occ_v:      dw 0
occ_uvd:    db 0                ; τα occ_u, occ_v ισχύουν
card_on:    db 0                ; η κάρτα του HUD δείχνει κτίριο
anc_force:  db 0                ; η γωνία / το σημάδι άλλαξε
dr_kind:    db 0                ; job_go_drop
dr_best:    db 0
dr_rec:     dw 0
int_t:      db 0                ; 300 Hz, πάντα (η διακοπή)
t0:         db 0                ; η αρχή του καρέ μονάδων
cmd_kind:   db 255              ; το είδος του πόρου κάτω από την εντολή
cmd_sj:     db 0                ; (ld (cmd_sj),de: j και μετά i)
cmd_si:     db 0
sp_ui:      db 0                ; stand_point (και occlude.asm: μαζί)
sp_uj:      db 0
sp_sj:      db 0
sp_si:      db 0
sp_bj:      db 0
sp_bi:      db 0
sp_best:    db 0
src_spare:  dw 0
nf_n:       db 0                ; near_free
sn_kind:    db 0                ; src_next
sn_r:       db 0
sn_j:       db 0
sn_i0:      db 0
sn_dj:      db 0
sn_best:    db 0
sn_bi:      db 0
sn_bj:      db 0
hn_x:       db 0                ; hud_num
hn_c:       db 0
hn_d:       ds 4
ticks:      db 0
res_n:      db 0                ; έρευνες σε εξέλιξη (bank7.asm, M9)
age_req:    db 0                ; 1: τελείωσε η Χαλκού, φόρτωσε το AGE3.BIN
age_q:      db 255              ; το επόμενο κτίριο να ξαναζωγραφιστεί (255 κανένα)
age_chg:    dw 0                ; bit τύπου: άλλαξε εικόνα στη νέα εποχή
carry_max:  db 10, 10, 10, 10   ; πόσο κουβαλάει ο χωρικός, ανά είδος (gather.asm)
cm_cur:     db 10               ; (το όριο της τρέχουσας)
        ifndef BARS             ; (η οθόνη του M0 δεν τρέχει το παιχνίδι)
        assert (carry_max & 255) <= 252, 'carry_max: one page'
        endif
dk_blk:     ds 16               ; τα blocks του αρχείου (disk.asm)
dk_res:     ds 8                ; η φάση αποτελέσματος του FDC
scr_s:      dw 0                ; η μετατόπιση του CRTC, σε λέξεις (screen.asm)
int_n:      db 0
split_on:   db 0
split_req:  db 0
uphase:     db 0
erase_req:  db 0
paused:     db 0
s_key:      dw 0
s_y:        db 0

set_base:   dw SPR_BASE, SPR_BASE + SPR_STRIDE, SPR_BASE + 2 * SPR_STRIDE
            dw SPR_BASE                         ; 3: με φορτίο = ο χωρικός + δέμα
            dw SPR_BASE + 3 * SPR_STRIDE        ; 4: ο οπλίτης (HOPL.BIN, M9)

; ------------------------------------------------------------ γραφικά
; Τα 16 πλακίδια x 16 bytes = ΜΙΑ σελίδα, στοιχισμένη, στην τράπεζα C6
; (src/make_bank6.py): το byte του χάρτη AND #F0 είναι κατευθείαν το low
; byte της διεύθυνσης. Όποιος ζωγραφίζει έδαφος τρέχει με την C6 μέσα.
TILE_PAGE   equ #48

; Οι πόροι (και τα κτίρια, M7) ζουν στην τράπεζα C6 (RAM_RES): res_gfx =
; #4000. Οι ρουτίνες που ζωγραφίζουν πόρους τρέχουν με την C6 μέσα
; (render, scroll_h, scroll_v, col_redraw).
res_gfx     equ #4000

; Ως εδώ ό,τι χρειάζεται το παιχνίδι ΟΣΟ ΤΡΕΧΕΙ: πριν το παράθυρο τράπεζας.
code_end:
        ifndef BARS             ; (η οθόνη ελέγχου του M0 δεν γράφει ποτέ στο
        assert code_end <= #4000, 'code past #4000'   ; #4000: ούτε HUD ούτε
        endif                   ; τράπεζες — ο κώδικας της μπορεί να το περάσει)

; Από εδώ μόνο για την εκκίνηση: μπορούν να περάσουν το #4000.
C7_CODE     equ #67A0           ; ο κώδικας της C7: αμέσως μετά τα μεταγλωττισμένα
        assert #4000 + CMP_LEN <= C7_CODE, 'compiled past C7_CODE'

; Η εκκίνηση (boot.asm): συναρμολογημένη για το BOOT, αντιγράφεται εκεί από
; το start. Πριν από τα συμπιεσμένα (ο rasm μετράει τις ετικέτες μετά από
; LZX0 με το ασυμπίεστο μέγεθος).
BOOT        equ #7A30           ; σειρές της σελίδας του HUD που δεν φαίνονται
boot_phys:
        org BOOT,boot_phys
        include "boot.asm"
boot_end:
        org boot_phys + boot_end - BOOT
BOOT_LEN    equ boot_end - BOOT
        assert BOOT + BOOT_LEN <= J_SI, 'boot past J_SI'
        assert boot_phys + BOOT_LEN <= BOOT, 'boot_phys overlaps BOOT'


; Το μενού έναρξης (menu.asm, M12): τρέχει στη θέση του, πριν από το BOOT.
        include "menu.asm"
menu_end:
        assert menu_end <= BOOT, 'menu over BOOT'

; Τα γραφικά των μονάδων στις τράπεζες (ugfx.asm, M12): στο #B000, στις
; εγγραφές των μονάδων, πριν τις γράψει το units_init.
UGFX        equ #B000
ugfx_phys:
        org UGFX,ugfx_phys
        include "ugfx.asm"
ugfx_end:
        org ugfx_phys + ugfx_end - UGFX
UGFX_LEN    equ ugfx_end - UGFX
        assert UGFX >= UNIT_TAB && UGFX + UGFX_LEN <= BLD_TAB2, 'UGFX'

; Το HUD: οι 7 σειρές του (560 bytes) από καθεμία από τις 8 οκτάδες της
; σελίδας #4000 — τα υπόλοιπα είναι μηδενικά.
hud_z:
        lzx0
k = 0
        repeat 8
        incbin "../data/hud_page.bin",k * #800,HUD_ROWS * 80
k = k + 1
        rend
        incbin "../data/digits.bin"     ; -> digits (hud_init)
        lzclose
        assert digits >= PORTAL + 256 && digits + DIGITS_LEN <= HUD_PAGE + #800, 'digits'

; Τα σετ των μονάδων, συμπιεσμένα· αποσυμπιέζονται στην τράπεζα C5.
; Ένα μπλοκ και για τα τρία (M14: κοινό λεξικό, για χώρο).
spr_z:
        lzx0
        incbin "../data/c5_set0.bin"    ; (το καρέ 12: το W της επίθεσης)
        incbin "../data/c5_set1.bin"
        incbin "../data/c5_set2.bin"
        lzclose
; Η τράπεζα C6: πόροι και κτίρια (src/make_bank6.py).
res_z:
        lzx0
        incbin "../data/bank6.bin"
        lzclose
; Κέρσορας, σημάδι επιλογής, γωνία -> C5 (μέσω της οθόνης). Συμπιεσμένα
; από το M10 (ο κώδικας της C7 μεγάλωσε).
cursor_gfx:                     ; -> C5, SPR_CURSOR: κέρσορας, αγκύλες, γωνία,
        lzx0
        incbin "../data/cursor.bin"     ; το βέλος, και τα περιγράμματα των
        incbin "../data/arrow.bin"      ; καρέ (src/make_edges.py)
        incbin "../data/occ_edges.bin"
        lzclose
; Τα μεταγλωττισμένα sprites (src/make_compiled.py) -> τράπεζα C7.
cmp_z:
        lzx0
        incbin "../data/compiled.bin"
        lzclose

; Ο κώδικας της C7 (bank7.asm, M13: συμπιεσμένος). Τον συμπιέζει ο rasm από
; το build/c7.bin, που το γράφει ένα πρώτο πέρασμα (-DC7RAW, build.sh): ο
; ίδιος κώδικας συναρμολογείται και πιο κάτω (για τις ετικέτες), έξω από
; το POLIS.BIN. Το units_gfx τον αποσυμπιέζει στην οθόνη και από εκεί στην C7.
        ifndef C7RAW
c7_z:
        lzx0
        incbin "../build/c7.bin"
        lzclose
        else
c7_z        equ 0
        endif

; Οι ρουτίνες της εκκίνησης, η αποθήκευση και οι ρουτίνες της σελίδας του
; HUD (M14: συμπιεσμένα, σε ένα μπλοκ, από το build/init.bin του πρώτου
; περάσματος, όπως η C7). Το start τα αποσυμπιέζει στο INIT μετά το μενού
; (που ζωγραφίζει στην οθόνη). Ο κώδικάς τους συναρμολογείται πιο κάτω, μετά
; το end, για τις ετικέτες. ΜΕΤΑ το c7_z: το πρώτο πέρασμα δεν το έχει, και
; ό,τι είναι πιο πίσω μετακινείται (το init αναφέρεται μόνο στο hud_z).
        ifndef C7RAW
init_z:
        lzx0
        incbin "../build/init.bin"
        lzclose
        else
init_z      equ 0
        endif

; Ο χάρτης συμπιεσμένος από τον ίδιο τον rasm (9.216 -> ~2 KB). ΤΕΛΕΥΤΑΙΟΣ:
; αποσυμπιέζεται πριν από οτιδήποτε, άρα μπορεί να περνάει πάνω από το BOOT
; (#7A30) ως το #8000 — όλα τα άλλα όχι (build.sh).
map_z:
        lzx0
        incbin "../data/map96.bin"
        lzclose

; ΤΙΠΟΤΑ ΜΕ `align` ΜΕΤΑ ΑΠΟ ΜΠΛΟΚ LZX0: ο rasm στοιχίζει με τη διεύθυνση
; ΠΡΙΝ τη συμπίεση, και μετά τη συμπίεση η ετικέτα μετακινείται σε μη
; στοιχισμένη θέση. Ό,τι θέλει στοίχιση μπαίνει πριν ή ζει εκτός binary.

end:



; Το «end < #4000» ΔΕΝ ελέγχεται εδώ: ο rasm αποτιμά τις ετικέτες μετά από
; μπλοκ LZX0 με το ασυμπίεστο μέγεθος. Το ελέγχει το build.sh στο πραγματικό
; POLIS.BIN.

; ---------------------------------------------------------- έξοδοι
; Το ίδιο αρχείο βγάζει δύο πράγματα. Με -DSNA=1: snapshot που ξεκινάει
; κατευθείαν στο `start`. Αλλιώς: POLIS.BIN με κεφαλίδα AMSDOS μέσα σε
; .dsk, για `RUN"POLIS`.
        ifdef SNA
        run start
        else
        ifndef C7RAW
        save 'POLIS.BIN',start,end-start,DSK,'build/polis.dsk'
        endif
        endif

; Τα αρχεία των εποχών (ένα ανά πολιτισμό) και του οπλίτη μπαίνουν στη
; δισκέτα από το game/build.sh (src/dsk.py), χωρίς κεφαλίδα AMSDOS (M12).

; ------------------------------------------------------------ το init_z
; Ο κώδικας του init_z, ΕΞΩ από το POLIS.BIN, σε ΔΙΚΟ ΤΟΥ χώρο μνήμης του
; rasm (όπως η C7, πιο κάτω): συναρμολογημένος για το INIT, όπου τον
; αποσυμπιέζει το start. Στο snapshot πέφτει στην C4 (ο καθρέφτης, που τον
; ξαναζωγραφίζει έτσι κι αλλιώς η πρώτη σχεδίαση).
        ifdef SNA
        bank 4
        else
        bank
        endif
INIT        equ #E000           ; (ως το M14 #F000: δεν χωρούσαν πια ως το
                                ; #FFFF· ο ενδιάμεσος χώρος της εκκίνησης
                                ; φτάνει ως το ~#D200)
        org INIT
; Οι ρουτίνες της εκκίνησης (init.asm, M11): στη μνήμη της οθόνης, πάνω από
; ό,τι χρησιμοποιεί ως ενδιάμεσο χώρο το hud_init.
init_phys:
        org INIT,init_phys
        include "init.asm"
init_end:
        org init_phys + init_end - INIT
INIT_LEN    equ init_end - INIT
        assert SCREEN + 8 * HUD_ROWS * 80 + DIGITS_LEN <= INIT, 'hud_init temp over INIT'

; Η αποθήκευση (savegame.asm, M12): τρέχει στην οθόνη (SVM), ταξιδεύει
; ΑΜΕΣΩΣ μετά το INIT (αντιγράφονται μαζί, στο SVM_AT), και το fog_init τη
; φυλάει στο SVM_STORE.
SVM         equ #C000
SVM_BUF     equ #C800           ; ο κατάλογος (2 KB), μετά ο τομέας (512)
mod_phys:
        org SVM,mod_phys
        include "savegame.asm"
mod_end:
        org mod_phys + mod_end - SVM
SVM_LEN     equ mod_end - SVM
SVM_AT      equ INIT + INIT_LEN
        assert SVM_AT + SVM_LEN <= #FFFF && SVM + SVM_LEN <= SVM_BUF, 'SVM'

; Ρουτίνες του παιχνιδιού στις κρυφές σειρές της σελίδας του HUD (οι 7-24
; κάθε οκτάδας: σειρές του καρέ Β που δεν φαίνονται από το M11), όπως το
; BOOT: μόνο με την C0 στο #4000, χωρίς δική τους αλλαγή τράπεζας εκεί, από
; την C7 με το call0. Ταξιδεύουν ΑΜΕΣΩΣ μετά την αποθήκευση (αντιγράφονται
; μαζί με το INIT), και το hud_init τις βάζει στη θέση τους αφού καθαρίσει
; τη σελίδα. Ελεύθερα ακόμα (μετρημένα σε παρτίδα, M14): #5230, #6A30,
; #7230, από 1.120 ως 1.232 bytes το καθένα.
HI_A        equ #5A30           ; ο κέρσορας, η επιλογή, η εντολή (input.asm)
hia_phys:
        org HI_A,hia_phys
        include "input.asm"
hia_end:
        org hia_phys + hia_end - HI_A
HIA_LEN     equ hia_end - HI_A
        assert HI_A + HIA_LEN <= PX, 'HI_A past PX'
HI_B        equ #6230           ; οι δουλειές των χωρικών (jobs.asm)
hib_phys:
        org HI_B,hib_phys
        include "jobs.asm"
hib_end:
        org hib_phys + hib_end - HI_B
HIB_LEN     equ hib_end - HI_B
        assert HI_B + HIB_LEN <= PN, 'HI_B past PN'
HI_C        equ #4230           ; επανασχεδίαση, ομίχλη, μίνι χάρτης (hudc.asm)
hic_phys:
        org HI_C,hic_phys
        include "hudc.asm"
hic_end:
        org hic_phys + hic_end - HI_C
HIC_LEN     equ hic_end - HI_C
        assert HI_C + HIC_LEN <= PORTAL, 'HI_C past PORTAL'
HIA_AT      equ SVM_AT + SVM_LEN        ; στην οθόνη, μετά το INIT
HI_LEN      equ HIA_LEN + HIB_LEN + HIC_LEN
        assert HIA_AT + HI_LEN <= #FFFF, 'HI past #FFFF'
        assert SVM_BUF + 2048 + 512 <= INIT, 'SVM_BUF over INIT'
        assert SVM_STORE + SVM_LEN <= BKT0, 'SVM_STORE'
INIT_ALL    equ HIA_AT + HI_LEN - INIT
        ifndef SNA
        ifdef C7RAW
        save 'build/init.bin',INIT,INIT_ALL     ; -> init_z (το δεύτερο πέρασμα)
        else
        save 'build/initchk.bin',INIT,INIT_ALL  ; (build.sh: ίδιο με το init.bin)
        endif
        endif

; ------------------------------------------------------------ το tutorial
; Στην C6 (game/tutor.asm), σε δικό του χώρο του rasm: build/tutor.bin, και
; το build.sh το βάζει στη δισκέτα ως TUTOR.BIN. Το φορτώνει το μενού.
TUT_AT      equ #5700           ; μετά τις εικόνες της Εποχής των Εργαλείων
        ifdef SNA               ; στο snapshot των ελέγχων (χωρίς μενού) δεν
tut_go      equ TUT_AT          ; χρειάζεται: μόνο τα σύμβολα — ο rasm θα το
tut_end     equ TUT_AT + 1      ; έβαζε στο #4000 της C6, πάνω στους πόρους
        else
        bank
        org TUT_AT
        include "tutor.asm"
        assert tut_end <= FOG, 'tutorial past FOG (C6)'
        assert tut_end - TUT_AT <= #800, 'tutor past TUT_CP_AT (menu.asm)'
        ifndef C7RAW
        save 'build/tutor.bin',TUT_AT,tut_end - TUT_AT
        endif
        endif

; ------------------------------------------------------------ η C7 (M8)
; Ο κώδικας της τράπεζας C7 (bank7.asm), συναρμολογημένος για το C7_CODE, σε
; ΔΙΚΟ ΤΟΥ χώρο μνήμης του rasm (M13): στο POLIS.BIN μπαίνει συμπιεσμένος
; (c7_z, από το build/c7.bin του πρώτου περάσματος). Στο snapshot πέφτει
; στην C7, που την ξαναγράφει έτσι κι αλλιώς το units_gfx. ΤΕΛΕΥΤΑΙΟΣ: μετά
; από εδώ ο rasm γράφει στον χώρο του.
        ifdef SNA
        bank 7
        else
        bank
        endif
        org C7_CODE
        include "bank7.asm"
c7_end:
C7_LEN      equ c7_end - C7_CODE
        assert C7_CODE + C7_LEN <= CH_D, 'C7 code past tables'
        ifndef SNA
        ifdef C7RAW
        save 'build/c7.bin',C7_CODE,C7_LEN      ; -> c7_z (το δεύτερο πέρασμα)
        else
        save 'build/c7chk.bin',C7_CODE,C7_LEN   ; (build.sh: ίδιο με το c7.bin)
        endif
        endif
