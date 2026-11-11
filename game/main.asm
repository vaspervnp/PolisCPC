; main.asm — Polis, Amstrad CPC 6128. M0: υποδομή.
;
;     ./game/build.sh            -> build/polis.dsk, build/polis.sna, .sym
;
; Τι κάνει το M0, και τίποτα παραπάνω:
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
        call draw_bars
        ei

; ---------------------------------------------------------- κύριος βρόχος

frame:
        call wait_vsync
        ld a,HW_RED
        call border
        call frame_work         ; ό,τι κάνει το καρέ — μετριέται από το border
        ld a,HW_BLACK
        call border
        jr frame

; Η δουλειά του καρέ. Στο M0 είναι άδεια: η κόκκινη λωρίδα δείχνει μόνο το
; κόστος του ίδιου του μετρητή. Τα επόμενα milestones μπαίνουν εδώ.
frame_work:
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

linebuf:
        ds 80

end:

        assert end < #4000, 'code overflows into the bank window at #4000'

; ---------------------------------------------------------- έξοδοι
; Το ίδιο αρχείο βγάζει δύο πράγματα. Με -DSNA=1: snapshot που ξεκινάει
; κατευθείαν στο `start`. Αλλιώς: POLIS.BIN με κεφαλίδα AMSDOS μέσα σε
; .dsk, για `RUN"POLIS`.
        ifdef SNA
        run start
        else
        save 'POLIS.BIN',start,end-start,DSK,'build/polis.dsk'
        endif
