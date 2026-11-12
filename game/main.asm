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

        ifdef SNA
        buildsna                ; ο τύπος εξόδου: snapshot αντί για .bin
        bankset 0               ; οι 64 KB της βάσης
        endif

        org #0040

start:
        di
        ld sp,STACK_TOP
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
        ld hl,map_z             ; ο χάρτης στη θέση του (#8000)
        ld de,MAP
        call dzx0
        call units_gfx          ; τα sprites -> C5, μέσω της οθόνης
        call hud_init           ; το HUD -> #4000, μέσω της οθόνης
        call clear_screen
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
        ld a,HW_RED
        call border
        ld a,3
        ld (uphase),a           ; 3 = τρέχει το καρέ μονάδων (tests/m3_check.py)
        call units_tick
        ld a,4
        ld (uphase),a
        ld a,HW_BLACK
        call border
        jr frame

; Η δουλειά του καρέ. Στο M0 είναι άδεια: η κόκκινη λωρίδα δείχνει μόνο το
; κόστος του ίδιου του μετρητή. Τα επόμενα milestones μπαίνουν εδώ.
frame_work:
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

; Όλη η οθόνη pen 0.
clear_screen:
        ld hl,SCREEN
        ld de,SCREEN + 1
        ld bc,#3FFF
        ld (hl),0
        ldir
        ret

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

; Τα 16 pens από το polis_hw. Το firmware είναι κλειστό, άρα κανείς δεν
; ξαναγράφει τα INK στη διακοπή — μένουν όπως τα αφήνουμε.
set_palette:
        ld hl,polis_hw
        ld b,GA
        ld e,0
.pen:   out (c),e               ; επιλογή pen
        ld a,(hl)
        out (c),a               ; το χρώμα του
        inc hl
        inc e
        ld a,e
        cp 16
        jr nz,.pen
        ld a,HW_BLACK
        jr border

; Η τυπική οθόνη 160x200 στο #C000, γραμμένη ρητά: να μη στηριζόμαστε σε ό,τι
; άφησε το firmware ή ένα snapshot.
crtc_setup:
        ld hl,crtc_regs
        ld d,0
.reg:   ld bc,CRTC_SEL*256
        out (c),d
        ld a,(hl)
        ld b,CRTC_DAT
        out (c),a
        inc hl
        inc d
        ld a,d
        cp 14
        jr nz,.reg
        ret

crtc_regs:
        ;   R0  R1  R2  R3  R4  R5  R6  R7  R8  R9 R10 R11 R12 R13
        db  63, 40, 46,#8E, 38,  0, 25, 30,  0,  7,  0,  0,#30,  0

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
        include "input.asm"
        include "pathing.asm"
        include "../data/nav.asm"
        include "../data/gather.asm"
        include "gather.asm"
        include "../data/bld.asm"
        include "../data/compiled.asm"
        include "buildings.asm"
        include "occlude.asm"

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
field_rr:   db 0
field_f:    db 0
field_tc:   db 255, 255
nphase:     db 0                ; 1 -> 2 γύρω από το BFS (tests/m5_check.py)
bphase:     db 0                ; 1 -> 2 γύρω από τη μέτρηση στόχευσης
bench_req:  db 0
t_bestd:    db 0                ; στόχευση
hud_val:    dw 200, 200, 100, 200, TOWN_UNITS, START_AGE ; η μπάρα: τροφή, ξύλο,
                                ; χρυσό, πέτρα, πληθυσμός, εποχή (gather.asm)
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
            dw SPR_BASE + 3 * SPR_STRIDE
spr_tab:    dw spr_z0, spr_z1, spr_z2, spr_z3

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
; ------------------------------------------------------------ η C7 (M8)
; Ο κώδικας της τράπεζας C7 (bank7.asm): συναρμολογημένος για το C7_CODE,
; αποθηκευμένος εδώ — πριν από τα συμπιεσμένα, που ο rasm τα μετακινεί — και
; στην C7 από το units_gfx (μαζί με τα sprites).
C7_CODE     equ #7500           ; μετά τα μεταγλωττισμένα (13.524 bytes)
c7_phys:
        org C7_CODE,c7_phys
        include "bank7.asm"
c7_end:
        org c7_phys + c7_end - C7_CODE
C7_LEN      equ c7_end - C7_CODE
        assert C7_CODE + C7_LEN <= C7_HP, 'C7 code past tables'

; Ο χάρτης συμπιεσμένος από τον ίδιο τον rasm (9.216 -> ~2 KB).
map_z:
        lzx0
        incbin "../data/map96.bin"
        lzclose

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
spr_z0:
        lzx0
        incbin "../data/villager_m.bin"
        lzclose
spr_z1:
        lzx0
        incbin "../data/swordsman.bin"
        lzclose
spr_z2:
        lzx0
        incbin "../data/archer.bin"
        lzclose
; Η τράπεζα C6: πόροι και κτίρια (src/make_bank6.py).
res_z:
        lzx0
        incbin "../data/bank6.bin"
        lzclose
; Κέρσορας, σημάδι επιλογής, γωνία -> C5 (μέσω της οθόνης).
cursor_gfx:                     ; -> C5, SPR_CURSOR: κέρσορας, αγκύλες, γωνία,
        incbin "../data/cursor.bin"     ; το βέλος, και τα περιγράμματα των
        incbin "../data/arrow.bin"      ; καρέ (src/make_edges.py)
        incbin "../data/occ_edges.bin"
        assert $ - cursor_gfx == C5_TAIL, 'C5_TAIL'
; Τα μεταγλωττισμένα sprites (src/make_compiled.py) -> τράπεζα C7.
cmp_z:
        lzx0
        incbin "../data/compiled.bin"
        lzclose
spr_z3:
        lzx0
        incbin "../data/set3.bin"       ; με τα W της επίθεσης (make_edges.py)
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
        save 'POLIS.BIN',start,end-start,DSK,'build/polis.dsk'
        endif
