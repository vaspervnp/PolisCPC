; main.asm — Polis, Amstrad CPC 6128.
;
;     ./game/build.sh            -> build/polis.dsk, build/polis.sna, .sym
;
; M1: ο χάρτης 96x96 στη μνήμη (#8000) και το ισομετρικό έδαφος + οι πόροι
; σε ολόκληρο το παράθυρο χάρτη (ground.asm, res.asm).
; M3: 16 μονάδες κινούνται στα 25 Hz, με επαναφορά από τον καθρέφτη του
; φόντου στην τράπεζα C4 και sprites στην C5 (units.asm). Με -DBARS=1 βγαίνει η
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
        ld hl,#C9FB             ; EI ; RET
        ld (#0038),hl

        ld bc,GA*256+GA_RMR     ; Mode 0, ROMs κλειστές
        out (c),c

        call crtc_setup
        call set_palette
        ifdef BARS
        call draw_bars
        else
        call clear_screen
        ld hl,map_z             ; ο χάρτης στη θέση του (#8000), από ZX0
        ld de,MAP
        call dzx0
        call units_init
        ld a,1
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
        inc a
        ld (phase),a            ; 1 = σχεδιάζει (το διαβάζει το tests/m1_check.py)
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
        call draw_ground
        jp draw_resources

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

        include "../palette.asm"
        include "ground.asm"
        include "res.asm"
        include "zx0.asm"
        include "units.asm"

linebuf:
        ds 80

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
ticks:      db 0
uphase:     db 0
erase_req:  db 0
paused:     db 0
s_key:      db 0
s_y:        db 0
; Η σειρά σχεδίασης: το low byte της εγγραφής κάθε μονάδας (δείκτης x 16).
order:      db 0,16,32,48,64,80,96,112,128,144,160,176,192,208,224,240
        align 256               ; (πριν από κάθε μπλοκ LZX0: εδώ ισχύει)
unit_tab:   ds UNITS * U_SIZE

; Οι 16 μονάδες του M3: x (bytes), y (γραμμές), dx, dy, σετ.
unit_init:
        db 10,20,1,1,0,   30,40,-1,1,1,   50,10,1,-1,2,   70,60,-1,-1,0
        db 12,90,1,-1,1,  40,100,1,1,2,   60,120,-1,-1,0, 20,70,-1,1,1
        db 74,30,-1,1,2,  4,128,1,-1,0,   36,64,1,1,1,    56,80,-1,-1,2
        db 26,4,1,1,0,    66,100,-1,1,1,  46,50,1,-1,2,   16,116,-1,-1,0

set_base:   dw SPR_BASE, SPR_BASE + SPR_STRIDE, SPR_BASE + 2 * SPR_STRIDE
spr_tab:    dw spr_z0, spr_z1, spr_z2

; ------------------------------------------------------------ γραφικά
; Τα 16 πλακίδια x 16 bytes = ΜΙΑ σελίδα, στοιχισμένη: το byte του χάρτη
; AND #F0 είναι κατευθείαν το low byte της διεύθυνσης.
        align 256
tile_gfx:
        incbin "../data/terrain.bin"
TILE_PAGE   equ tile_gfx >> 8
        assert $ - tile_gfx == 256, 'terrain.bin must be exactly one page'
res_gfx:                        ; στοιχισμένο στα 128 (το blit το χρειάζεται)
        assert (res_gfx & 127) == 0, 'res_gfx must be 128-aligned'
        incbin "../data/resources.bin"
; Ο χάρτης συμπιεσμένος από τον ίδιο τον rasm (9.216 -> ~2 KB).
map_z:
        lzx0
        incbin "../data/map96.bin"
        lzclose

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
