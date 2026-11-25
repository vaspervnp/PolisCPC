; mouse.asm — το ποντίκι AMX (2026-11-25), όπως στο V-OS (src/drivers/mouse.asm).
;
; Το AMX μπαίνει στη θύρα του joystick: φαίνεται στη γραμμή 9 του πίνακα
; πλήκτρων (bits 0-3 πάνω / κάτω / αριστερά / δεξιά, 5 το αριστερό κουμπί =
; fire 1, 4 το δεξί = fire 2). Η κίνηση έρχεται σε παλμούς στις γραμμές των
; κατευθύνσεων, πιο σύντομους από ένα καρέ: το ms_isr διαβάζει τη γραμμή 9
; σε ΚΑΘΕ διακοπή (300 Hz) και μετράει κάθε ανάγνωση με ενεργή γραμμή ως ένα
; βήμα (ms_x, ms_y, με πρόσημο: όπως το «LEVELS» του V-OS). Το ms_dirs (από
; το read_cin, input.asm) τα κάνει τα bits κατεύθυνσης του κέρσορα: όποιος
; μετρητής φτάσει τα ±6 δίνει ένα βήμα (2 bytes / 6 γραμμές, όσο ένα πλήκτρο)
; και ξαναρχίζει από το 0. Τα κουμπιά δεν θέλουν τίποτα: είναι τα fire του
; joystick, που το read_cin τα διαβάζει ήδη (SPACE, RETURN).
;
; Και το joystick περνάει από εδώ: πατημένο δίνει 6 μετρήσεις ανά καρέ, άρα
; ένα βήμα σε κάθε καρέ των μονάδων (25 Hz) — όπως πριν.
;
; ΣΒΗΣΤΟ ΩΣ ΤΗΝ ΠΡΩΤΗ ΚΙΝΗΣΗ: η ανάγνωση κοστίζει ~85 µs ανά διακοπή, ~1 ms
; ανά καρέ μονάδων — το M5 (128 μονάδες) θα περνούσε τα 40 ms (39,8 -> 41,1).
; Μόλις η ανάγνωση του καρέ (keyrows) δει μια κατεύθυνση στη γραμμή 9
; (joystick, ή ένας παλμός του AMX που έτυχε), το ms_gate κάνει το #0038
; «rst 0» (από JP int_handler): από εκεί και πέρα κάθε διακοπή περνάει από
; το ms_isr, ως την επόμενη εκκίνηση. (Η πρώτη κίνηση αργεί ένα καρέ.)
;
; ΧΩΡΟΣ: ο κύριος κώδικας είναι γεμάτος. Τα κομμάτια ταξιδεύουν στο INIT
; (main.asm, μετά τα HI) και το init_go (init.asm) τα βάζει, μετά το
; φόρτωμα μιας παρτίδας, σε κενά που μετρήθηκαν άγραφτα σε ολόκληρη παρτίδα
; (ο έλεγχος με «δηλητήριο», 2026-11-25):
;   #0000-#0007   η αρχή του ms_isr (το rst 0)
;   MSI_AT #A8C0  το ms_isr (μετά το MOVERS, ως το BLOCK_TAB)
;   MS_V #A770    ms_x, ms_y, και μετά το ms_gate (μετά το RLIST, ως το RECTS)
;   MSD_AT #AD50  το ms_dirs (μετά το 2ο buffer γραμμής, ως το FD_TAB)
;   MSX_AT #3FEE  το ms_ax (μετά τα ψηφία του SQ_FONT, ως το #4000)
; Το μενού (MENU_AT, ως το #AD5E) και το init γράφουν πάνω τους πριν από το
; init_go. Το #0038 το ξαναγράφει JP int_handler το start (και το φόρτωμα,
; savegame.asm, περνάει από το start).
;
; ΝΑ ΕΛΕΓΧΘΕΙ ΣΕ ΠΡΑΓΜΑΤΙΚΟ CPC: το πλάτος των παλμών (όπως στο V-OS).

ms_x        equ MS_V
ms_y        equ MS_V + 1

; ---- #0000: από το rst 0 του #0038 (στη στοίβα το #0039: γίνεται το HL)
ms0_p:
        org #0000,ms0_p
        ex (sp),hl
        push af
        push bc
        ld b,#F4
        jp ms_isr
ms0_e:
        org ms0_p + ms0_e
        assert ms0_e <= #0008, 'ms: #0000 past #0008 (bcopy)'

; ---- MSI_AT: η γραμμή 9 -> οι μετρητές, και μετά η κανονική διακοπή
ms1_p:
        org MSI_AT,ms1_p
ms_isr: ld c,#0E                ; PSG: ο καταχωρητής 14 (θύρα A)
        out (c),c
        ld bc,#F6C0
        out (c),c
        ld c,0
        out (c),c
        ld bc,#F792             ; PPI θύρα A: είσοδος
        out (c),c
        ld bc,#F649             ; PSG: ανάγνωση, γραμμή 9
        out (c),c
        ld b,#F4
        in a,(c)
        ld bc,#F782             ; PPI θύρα A: έξοδος
        out (c),c
        ld bc,#F600
        out (c),c
        cpl                     ; 1 = ενεργή
        ld hl,ms_y
        rra                     ; 0 πάνω
        jr nc,$ + 3
        dec (hl)
        rra                     ; 1 κάτω
        jr nc,$ + 3
        inc (hl)
        dec hl                  ; ms_x
        rra                     ; 2 αριστερά
        jr nc,$ + 3
        dec (hl)
        rra                     ; 3 δεξιά
        jr nc,$ + 3
        inc (hl)
        pop bc
        pop af
        pop hl
        jp int_handler
ms1_e:
        org ms1_p + ms1_e - MSI_AT
        assert ms1_e <= BLOCK_TAB, 'ms: MSI_AT past BLOCK_TAB'

; ---- MS_V + 2: από το read_cin, με E = η γραμμή 9 του καρέ. Μια κατεύθυνση
; εκεί: η ανάγνωση στις 300 Hz από τώρα (rst 0 στο #0038).
ms2_p:
        org MS_V + 2,ms2_p
ms_gate:
        ld a,e
        and #0F
        jp z,ms_dirs
        ld a,#C7                ; rst 0
        ld (#0038),a
        jp ms_dirs
ms2_e:
        org ms2_p + ms2_e - MS_V - 2
        assert ms2_e <= RECTS, 'ms: ms_gate past RECTS'

; ---- MSD_AT: -> A = τα bits κατεύθυνσης (IN_UP ... IN_RIGHT) από τους
; μετρητές. Χαλάει C, HL.
ms3_p:
        org MSD_AT,ms3_p
ms_dirs:
        ld hl,ms_x
        call ms_ax              ; 0, 1 αριστερά, 2 δεξιά
        add a,a
        add a,a
        ld c,a
        inc hl                  ; ms_y
        call ms_ax              ; 0, 1 πάνω, 2 κάτω
        or c
        ret
ms3_e:
        org ms3_p + ms3_e - MSD_AT
        assert ms3_e <= FD_TAB, 'ms: MSD_AT past FD_TAB'

; ---- MSX_AT: (HL) = ένας μετρητής -> A = 0 (ως ±5), 1 (≤ -6), 2 (≥ 6),
; και ο μετρητής από το 0 όταν έδωσε βήμα.
ms4_p:
        org MSX_AT,ms4_p
ms_ax:  ld a,(hl)
        add a,5
        cp 11
        ld a,0
        ret c
        ld a,(hl)
        ld (hl),0
        rla
        ld a,1
        ret c
        inc a
        ret
ms4_e:
        org ms4_p + ms4_e - MSX_AT
        assert ms4_e <= #4000, 'ms: MSX_AT past #4000'
ms_end:
