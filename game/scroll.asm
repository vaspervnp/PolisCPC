; scroll.asm — η κύλιση: το CRTC μετακινεί την εικόνα, εδώ ζωγραφίζεται
; μόνο ό,τι αποκαλύπτεται. M2.
;
;   δεξιά/αριστερά   cam_x ± 2, scr_s ± 1    στήλη 2 bytes x 144 γραμμές
;   κάτω/πάνω        cam_y ± 8, scr_s ± 40   σειρά 80 bytes x 8 γραμμές
;
; Η ΣΤΗΛΗ. Στις ζώνες A τα bytes c, c+1 είναι μισό ενός πλακιδίου· στις
; ζώνες B είναι το ΔΕΥΤΕΡΟ byte ενός στοιχείου και το ΠΡΩΤΟ του επόμενου.
; Το c είναι ζυγό και κάθε γραμμή αρχίζει σε ζυγή μετατόπιση, άρα τα δύο bytes
; δεν περνάνε ποτέ όριο σελίδας ή 2 KB.
;
; Η ΣΕΙΡΑ. Τέσσερις ζώνες ολόκληρες με το draw_pair του M1. Αν η γραμμή
; σπάει στο όριο των 2 KB, ζωγραφίζεται σε buffer και αντιγράφεται σε δύο
; κομμάτια.
;
; ΣΕΙΡΑ ΕΡΓΑΣΙΩΝ. Η νέα μετατόπιση φτιάχνει τον πίνακα γραμμών, η λωρίδα
; ζωγραφίζεται, ΜΕΤΑ γράφεται στο scr_s (και το CRTC την παίρνει στο επόμενο
; καρέ). Η σειρά που αποκαλύπτεται κάθετα είναι εκτός οθόνης ώς τότε: η
; κάθετη κύλιση δεν δείχνει ποτέ μισοτελειωμένη λωρίδα. Η στήλη όμως είναι
; η αριστερή στήλη της επόμενης σειράς χαρακτήρων — ορατή: για ένα καρέ η
; άκρη 4 pixels μπορεί να φανεί πριν ή μετά.

BUF_A       equ #A500           ; buffer γραμμής (γραμμή b στο +#800)
VOID16       equ #A580           ; 16 μηδενικά, στοιχισμένα: «πλακίδιο» εκτός χάρτη
MAX_CAM_X   equ 384 - 80
MIN_CAM_Y   equ -1
MAX_CAM_Y   equ 623

; ---------------------------------------------------------- πληκτρολόγιο

; Όλος ο πίνακας πλήκτρων (γραμμές 0-9) στο keyrows, ΜΙΑ φορά ανά καρέ:
; η ρύθμιση του PSG/PPI γίνεται μία φορά, όχι ανά γραμμή.
read_matrix:
        ld bc,#F40E             ; PSG: καταχωρητής 14 (θύρα A)
        out (c),c
        ld bc,#F6C0
        out (c),c
        ld bc,#F600
        out (c),c
        ld bc,#F792             ; PPI θύρα A: είσοδος
        out (c),c
        ld hl,keyrows
        ld e,#40                ; PSG: ανάγνωση, γραμμή 0
.r:     ld b,#F6
        out (c),e
        ld b,#F4
        in a,(c)
        cpl                     ; 1 = πατημένο
        ld (hl),a
        inc hl
        inc e
        ld a,e
        cp #4A
        jr nz,.r
        ld bc,#F782             ; PPI θύρα A: έξοδος
        out (c),c
        ld bc,#F600
        out (c),c
        ret

; A = γραμμή του πίνακα πλήκτρων -> A = τα bits της, 1 = πατημένο (από το
; read_matrix αυτού του καρέ). Κρατάει BC, DE, HL.
read_row:
        push hl
        ld hl,keyrows
        add a,l
        ld l,a
        jr nc,.n
        inc h
.n:     ld a,(hl)
        pop hl
        ret

; Τα βελάκια -> sdx, sdy (-1, 0, +1).
read_keys:
        call read_matrix
        xor a
        call read_row           ; γραμμή 0: πάνω=0, δεξιά=1, κάτω=2
        ld e,a
        ld a,1
        call read_row           ; γραμμή 1: αριστερά=0
        ld d,a
        xor a
        bit 1,e
        jr z,.nr
        inc a
.nr:    bit 0,d
        jr z,.nl
        dec a
.nl:    ld (sdx),a
        xor a
        bit 2,e
        jr z,.nd
        inc a
.nd:    bit 0,e
        jr z,.nu
        dec a
.nu:    ld (sdy),a
        ret

; --------------------------------------------------------- το βήμα

calc_cam_h:
        ld hl,(cam_x)           ; cam_h = (cam_x - XOFF) / 2, προσημασμένο
        ld de,-XOFF
        add hl,de
        sra h
        rr l
        ld (cam_h),hl
        ret

; Ένα βήμα κύλισης από τα sdx, sdy.
;
; ΚΑΘΕΤΑ: ΣΕ ΔΥΟ ΚΑΡΕ. Η σειρά 8 γραμμών που θα αποκαλυφθεί είναι στη
; μνήμη πέρα από τις 18 ορατές (κάθε οκτάδα έχει 2 KB, φαίνονται 1.440
; bytes): ζωγραφίζεται πριν φανεί. Στο πρώτο καρέ το έδαφος και οι 4 πρώτες
; (πίσω) σειρές ρόμβων των πόρων, στο δεύτερο οι 3 υπόλοιπες, ο καθρέφτης,
; και η κάμερα κινείται (v_pend). Πάνω από πυκνό δάσος η λωρίδα ήταν ~25 ms
; σε ένα καρέ. Η κάθετη κύλιση γίνεται 100 γραμμές/s, όσο η οριζόντια σε
; pixels.
;
; ΔΙΑΓΩΝΙΑ: ΕΝΑΛΛΑΞ. Μία λωρίδα ανά καρέ — στήλη στο ένα, σειρά (δύο καρέ)
; στο επόμενο (sdiag). Αν ο άξονας της σειράς του είναι ήδη στην άκρη,
; κυλάει ο άλλος στο ίδιο καρέ.
scroll_apply:
        ld a,(v_pend)           ; η κάθετη που άρχισε τελειώνει, μόνη της
        or a
        jp nz,scroll_v2
        ld a,(sdy)
        or a
        jr z,.h
        ld a,(sdx)
        or a
        jr z,.v
        ld a,(sdiag)
        xor 1
        ld (sdiag),a
        jr z,.hfirst
        ld a,(sdy)
        call scroll_v           ; NZ: άρχισε
        ret nz
.h:     ld a,(sdx)
        or a
        ret z
        jp scroll_h
.hfirst:
        ld hl,(scr_s)
        push hl
        ld a,(sdx)
        call scroll_h
        pop de
        ld hl,(scr_s)
        or a
        sbc hl,de
        ret nz
.v:     ld a,(sdy)
        jp scroll_v

; A = sdx (±1): μία στήλη.
scroll_h:
        ld hl,(cam_x)
        bit 7,a
        jr nz,.left
        ld de,MAX_CAM_X
        or a
        sbc hl,de
        ret nc                  ; ήδη στη δεξιά άκρη
        ld hl,(cam_x)
        inc hl
        inc hl
        ld (cam_x),hl
        ld hl,(scr_s)
        inc hl
        ld c,80 - 2             ; η νέα στήλη: δεξιά
        jr .h
.left:  ld a,h
        or l
        ret z                   ; ήδη στην αριστερή άκρη
        dec hl
        dec hl
        ld (cam_x),hl
        ld hl,(scr_s)
        dec hl
        ld c,0
.h:     ld a,h
        and 3
        ld h,a
        push hl                 ; η νέα μετατόπιση: δημοσιεύεται στο τέλος
        push bc
        call build_lines
        call calc_cam_h
        pop bc
        push bc
        ld a,RAM_RES            ; οι πόροι είναι στην C6
        call setram
        pop bc
        push bc
        ld a,c
        call draw_column        ; έδαφος ΚΑΙ πόροι
        pop bc
        ld a,c
        call mirror_column      ; (επιστρέφει με την C0)
        pop hl
        ld (scr_s),hl
        ret

; A = sdy (±1): το πρώτο καρέ μιας σειράς. NZ αν άρχισε, Z αν η κάμερα
; είναι ήδη στην άκρη.
scroll_v:
        ld hl,(cam_y)           ; cam_y + 1 ≥ 0 πάντα: συγκρίσεις χωρίς πρόσημο
        inc hl
        bit 7,a
        jr nz,.up
        ld de,MAX_CAM_Y - 8 + 2 ; κάτω: cam_y + 8 ≤ MAX
        or a
        sbc hl,de
        jr nc,.edge
        ld de,8
        ld bc,40
        ld a,VIEW_H - 8         ; η νέα σειρά: κάτω
        jr .v
.up:    ld de,MIN_CAM_Y + 8 + 1 ; πάνω: cam_y - 8 ≥ MIN
        or a
        sbc hl,de
        jr c,.edge
        ld de,-8
        ld bc,-40
        xor a
.v:     ld (v_y0),a
        ld hl,(cam_y)
        add hl,de
        ld (v_ny),hl
        ld hl,(scr_s)
        add hl,bc
        ld a,h
        and 3
        ld h,a
        ld (v_ns),hl
        call v_enter
        ld a,(v_y0)             ; το έδαφος
        call draw_rows
        ld a,RAM_RES            ; οι πόροι είναι στην C6
        call setram
        xor a                   ; τα κτίρια της λωρίδας (buildings.asm)
        ld (rg_x0),a
        ld a,80
        ld (rg_x1),a
        ld a,(v_y0)
        ld (rg_y0),a
        add a,8
        ld (rg_y1),a
        call bld_cands
        ld a,(v_y0)             ; οι πίσω σειρές των πόρων
        ld b,4
        call strip_resources
        ld a,RAM_BASE
        call setram
        ld hl,(var_r)
        ld (v_r),hl
        call v_leave
        ld a,1
        ld (v_pend),a
        or a                    ; NZ
        ret
.edge:  xor a                   ; Z
        ret

; Το δεύτερο καρέ: οι υπόλοιπες σειρές των πόρων, ο καθρέφτης, και η κάμερα.
scroll_v2:
        call v_enter
        ld hl,(v_r)
        ld (var_r),hl
        ld a,RAM_RES
        call setram
        ld a,3
        call strip_more
        ld a,255                ; τα κτίρια μπροστά από όλες
        call bld_flush
        ld a,RAM_BASE
        call setram
        ld a,(v_y0)
        call mirror_rows
        call v_leave
        xor a
        ld (v_pend),a
        ld hl,(v_ny)
        ld (cam_y),hl
        ld hl,(v_ns)
        push hl
        call build_lines
        pop hl
        ld (scr_s),hl
        ret

; Για τη λωρίδα που δεν φαίνεται ακόμα: η κάμερα της νέας θέσης (cam_y), οι
; 8 γραμμές της στον πίνακα γραμμών με τη νέα μετατόπιση (οι παλιές στο
; v_save), και το ψαλίδι των πόρων στις 8 γραμμές. Ο πίνακας μένει κατά τα
; άλλα της ορατής εικόνας: οι μονάδες ζωγραφίζονται σωστά στο ίδιο καρέ.
v_enter:
        ld hl,(cam_y)
        ld (v_oy),hl
        ld hl,(v_ny)
        ld (cam_y),hl
        ld a,(v_y0)
        ld (clip_y0),a
        add a,8
        ld (clip_y1),a
        call v_ent              ; HL = οι 8 θέσεις στο line_addr
        push hl
        ld de,v_save
        ld bc,16
        ldir
        pop de
        ld hl,(v_ns)            ; off = 2 v_ns + (17 x 80 κάτω, 0 πάνω)
        add hl,hl
        ld a,(v_y0)
        or a
        jr z,.r0
        ld bc,(VIEW_H / 8 - 1) * 80
        add hl,bc
.r0:    ld c,l
        ld a,h
        and 7
        or #C0
        ld b,8
.e:     ex de,hl
        ld (hl),c
        inc hl
        ld (hl),a
        inc hl
        ex de,hl
        add a,8
        djnz .e
        ret

v_leave:
        ld hl,(v_oy)
        ld (cam_y),hl
        call v_ent
        ex de,hl
        ld hl,v_save
        ld bc,16
        ldir
        jp clip_full

v_ent:  ld a,(v_y0)
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ret

clip_full:
        xor a
        ld (clip_x0),a
        ld (clip_y0),a
        ld a,80
        ld (clip_x1),a
        ld a,VIEW_H
        ld (clip_y1),a
        ret

; ------------------------------------------------------------ η στήλη

; A = c (ζυγό byte οθόνης). Το έδαφος στα bytes c, c+1, γραμμές 0-143.
;
; ΣΤΑΔΙΑΚΑ, ΧΩΡΙΣ ΠΟΛΛΑΠΛΑΣΙΑΣΜΟΥΣ. Με w = cam_h + c/2 και r η σειρά
; ρόμβων, η στήλη είναι 36 ομάδες των 4 γραμμών: ζώνη A (γραμμές 4k, 4k+1)
; και ζώνη B (4k+2, 4k+3), με r = r0 + k. Με s = r + w:
;
;   το πλακίδιο της A είναι T = (I, J) = (s >> 1, (r - w + 1) >> 1)
;   s ζυγό:  A = T[4,5 / 8,9]     B: byte c = T'[1 / 3], c+1 = T[12 / 14]
;            το επόμενο T' = (I, J+1)          (χάρτης + 96)
;   s μονό:  A = T[6,7 / 10,11]   B: byte c = T[13 / 15], c+1 = T'[0 / 2]
;            το επόμενο T' = (I+1, J)          (χάρτης + 1)
;
; Δηλαδή η B είναι πάντα κομμάτια του τρέχοντος και του ΕΠΟΜΕΝΟΥ πλακιδίου,
; και το επόμενο γίνεται τρέχον. Οι 4 γραμμές μιας ομάδας είναι στην ίδια
; σειρά χαρακτήρων: μία διεύθυνση από τον πίνακα, και D + 8 ανά γραμμή.
;
; ΚΑΙ ΟΙ ΠΟΡΟΙ ΣΤΟ ΙΔΙΟ ΠΕΡΑΣΜΑ. Τα πλακίδια μιας σειράς r απέχουν 4 bytes
; και η στήλη (2 bytes, ζυγή) πέφτει σε ΕΝΑ μόνο sprite ανά σειρά: αυτό του
; T, στα bytes 0-1 (s ζυγό) ή 2-3 (s μονό) του, γραμμές 4k-13 ... 4k+2.
; Μπαίνει αμέσως μετά το έδαφος της ομάδας k — όλες οι γραμμές του έχουν
; ήδη έδαφος, και τα sprites των επόμενων σειρών (πιο μπροστά) έρχονται
; μετά: η σειρά του ζωγράφου. Τέσσερις ομάδες ακόμα (36-39) μόνο για τα
; sprites που κρέμονται από κάτω προς τα πάνω στο παράθυρο.
draw_column:
        ld (col_c),a
        ld (rg_x0),a            ; τα κτίρια που την τέμνουν (buildings.asm)
        add a,2
        ld (rg_x1),a
        ld a,(col_y0)
        ld (rg_y0),a
        ld a,(col_y1)
        ld (rg_y1),a
        call bld_cands
        ld a,(col_c)
        ld hl,(cam_h)           ; w = h + c/2
        srl a
        ld e,a
        ld d,0
        add hl,de
        ld (col_w),hl
        ld hl,(cam_y)           ; r0 = ((cam_y + 1) >> 2) - 1
        inc hl
        sra h
        rr l
        sra h
        rr l
        dec hl
        ld (col_rr),hl          ; η σειρά ρόμβων της ομάδας (για τα κτίρια)
        push hl
        ld de,(col_w)
        add hl,de               ; s
        ld a,l
        and 1
        ld (col_par),a
        sra h
        rr l
        ld (col_i),hl           ; I = s >> 1
        pop hl
        or a
        sbc hl,de
        inc hl
        sra h
        rr l
        ld (col_j),hl           ; J = (r - w + 1) >> 1
        add hl,hl               ; ptr = MAP + J*96 + I
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(col_i)
        add hl,de
        ld de,MAP
        add hl,de
        ld (col_ptr),hl
        call col_tile
        ld (col_t0),hl
        ld (col_r0),a
        ld hl,line_addr
        ld (col_lp),hl
        ld a,16 - 13            ; η πρώτη γραμμή του sprite της ομάδας 0, +16
        ld (col_sy),a
        ld a,VIEW_H / 4 + 4
.grp:   ld (col_n),a
        ld a,(col_par)          ; το επόμενο πλακίδιο
        or a
        jr nz,.odd
        ld hl,(col_j)
        inc hl
        ld (col_j),hl
        ld hl,(col_ptr)
        ld de,MAPW
        add hl,de
        jr .look
.odd:   ld hl,(col_i)
        inc hl
        ld (col_i),hl
        ld hl,(col_ptr)
        inc hl
.look:  ld (col_ptr),hl
        call col_tile
        ld (col_t1),hl
        ld (col_r1),a
.j1:    jr .in                   ; όλο το ύψος: χωρίς ελέγχους (το col_redraw
                                ; το κάνει «cp n», #FE, για ένα κομμάτι)
        ld a,(col_sy)           ; τα sprites από εδώ και κάτω αρχίζουν
        sub 16                  ; κάτω από το παράθυρο: τέλος
        jr c,.in
        ld hl,col_y1
        cp (hl)
        jp nc,.fin
.in:    ld a,(col_n)
        cp 5
        jp c,.res               ; οι 4 τελευταίες: μόνο το sprite
        ld hl,(col_lp)          ; DE = γραμμή 4k, byte c
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld bc,7
        add hl,bc
        ld (col_lp),hl
.j2:    jr .gw                   ; όπως το cw_j1
        ld a,(col_sy)           ; 4k = col_sy - 3: έξω από το col_y0..col_y1
        sub 3                   ; μόνο το sprite (ψαλιδισμένο)
        ld hl,col_y0
        cp (hl)
        jp c,.res
        ld hl,col_y1
        cp (hl)
        jp nc,.res
.gw:
        ld a,(col_c)
        add a,e
        ld e,a
        call c,de_carry
        ld a,(col_par)          ; A: T + 4 ή T + 6
        add a,a
        add a,4
        ld hl,(col_t0)
        add a,l
        ld l,a
        ld a,(hl)
        ld (de),a
        inc l
        inc e
        ld a,(hl)
        ld (de),a
        inc l                   ; γραμμή 4k+1: το byte c+1 = T[off+5]
        inc l
        inc l
        inc l
        ld a,d
        add a,8
        ld d,a
        ld a,(hl)
        ld (de),a
        dec l
        dec e
        ld a,(hl)
        ld (de),a
        ld a,d                  ; B: γραμμές 4k+2, 4k+3
        add a,8
        ld d,a
        ld a,(col_par)
        or a
        jr nz,.bodd
        ld hl,(col_t1)          ; ζυγό: c = T'+1, c+1 = T+12
        inc l
        ld bc,(col_t0)
        ld a,c
        add a,12
        ld c,a
        jr .bput
.bodd:  ld hl,(col_t0)          ; μονό: c = T+13, c+1 = T'
        ld a,l
        add a,13
        ld l,a
        ld bc,(col_t1)
.bput:  ld a,(hl)
        ld (de),a
        inc e
        ld a,(bc)
        ld (de),a
        inc l
        inc l
        inc c
        inc c
        ld a,d
        add a,8
        ld d,a
        ld a,(bc)
        ld (de),a
        dec e
        ld a,(hl)
        ld (de),a
.res:   ld a,(cand_n)           ; τα κτίρια πίσω από αυτή τη σειρά:
        or a                    ; r = r0 + (VIEW_H / 4 + 4 - col_n)
        call nz,col_bflush
        ld a,(col_r0)
        or a
        call nz,col_sprite
        ld hl,(col_t1)          ; το επόμενο γίνεται τρέχον
        ld (col_t0),hl
        ld a,(col_r1)
        ld (col_r0),a
        ld a,(col_sy)
        add a,4
        ld (col_sy),a
        ld a,(col_par)
        xor 1
        ld (col_par),a
        ld a,(col_n)
        dec a
        jp nz,.grp
.fin:   ld a,255                ; και τα κτίρια μπροστά από όλες
        jp bld_flush

col_bflush:
        ld a,(col_n)
        neg
        add a,VIEW_H / 4 + 4
        ld e,a
        ld d,0
        ld hl,(col_rr)
        add hl,de
        jp row_flush

cw_j1       equ draw_column.j1  ; τα δύο «jr» που αλλάζει το col_redraw
cw_j2       equ draw_column.j2

; A = πόρος (1-15): το sprite του στη στήλη col_c, από τη γραμμή col_sy - 16
; (3..159: χωρίς πρόσημο), τα bytes 0-1 ή 2-3 του (col_par), ψαλιδισμένο στο
; col_y0..col_y1 (0..144 για την κύλιση· ένα κομμάτι για το gather.asm).
col_sprite:
        cp BLD_RES              ; πλακίδιο κτιρίου (M7): κανένα sprite
        ret z
        dec a                   ; HL = res_gfx + (A-1)*128
        rrca
        ld l,a
        and #7F
        ld h,a
        ld a,l
        and #80
        ld l,a
        ld de,res_gfx
        add hl,de
        ld a,(col_par)          ; + 4 για τα bytes 2-3
        add a,a
        add a,a
        add a,l
        ld l,a
        ld a,(col_y0)           ; B = y0 + 16 (το col_sy έχει +16)
        add a,16
        ld b,a
        ld a,(col_sy)
        ld c,16                 ; C = πόσες γραμμές
        sub b                   ; y - y0
        jr nc,.top
        neg                     ; πάνω από το παράθυρο: πετάγονται y0 - y
        cp c
        ret nc
        ld b,a
        add a,a
        add a,a
        add a,a
        add a,l
        ld l,a
        ld a,c
        sub b
        ld c,a
        ld a,(col_y1)           ; και ως το col_y1 (παράθυρο < 16 γραμμές)
        ld b,a
        ld a,(col_y0)
        neg
        add a,b
        cp c
        jr nc,.lim
        ld c,a
.lim:   ld a,(col_y0)
        jr .y0
.top:   ld b,a                  ; η πρώτη γραμμή: y0 + (y - y0)
        ld a,(col_y0)
        add a,b
        ld b,a
        ld a,(col_y1)           ; κάτω: ως το col_y1
        sub b
        ret c
        ret z
        cp c
        jr nc,.full
        ld c,a
.full:  ld a,b
.y0:    push hl                 ; DE = η γραμμή A, byte col_c
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,(col_c)
        add a,e
        ld e,a
        call c,de_carry
        pop hl
        ld b,c
.l:     ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        ld (de),a
        dec e
        ld a,l
        add a,5
        ld l,a
        ld a,d
        add a,8
        ld d,a
        and #38
        call z,col_wrap
        djnz .l
        ret

; Η επόμενη σειρά χαρακτήρων: +80, τυλιγμένο στα 2 KB, στη γραμμή 0.
col_wrap:
        ld a,e
        add a,80
        ld e,a
        ld a,d
        adc a,0
        and 7
        or #C0
        ld d,a
        ret

; (col_i, col_j, col_ptr) -> HL = τα 16 bytes του πλακιδίου, ή VOID16, και
; A = ο πόρος του (0 = κανένας).
col_tile:
        ld a,(col_i + 1)
        ld hl,col_j + 1
        or (hl)
        jr nz,.void
        ld a,(col_i)
        cp MAPW
        jr nc,.void
        ld a,(col_j)
        cp MAPW
        jr nc,.void
        ld hl,(col_ptr)
        ld a,(hl)
        ld l,a
        and #F0
        ld h,l
        ld l,a
        ld a,h
        and #0F                 ; A = ο πόρος
        ld h,TILE_PAGE
        ret
.void:  ld hl,VOID16
        xor a
        ret

; HL = I, DE = J (16-bit, με πρόσημο) -> HL = τα 16 bytes του πλακιδίου,
; ή VOID16 έξω από τον χάρτη.
tile_lookup:
        ld a,h
        or d
        jr nz,.void
        ld a,l
        cp MAPW
        jr nc,.void
        ld a,e
        cp MAPW
        jr nc,.void
        push hl
        ex de,hl                ; J * 96
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        pop de
        add hl,de
        ld de,MAP
        add hl,de
        ld a,(hl)
        and #F0
        ld l,a
        ld h,TILE_PAGE
        ret
.void:  ld hl,VOID16
        ret

; DE = n, στοιχείο ζώνης B της σειράς var_r -> HL = τα bytes της γραμμής a του.
; Είδος t = (n + r) AND 1: 0 κάτω μισό του (i, r-i) με i = (n + r)/2, 1 πάνω
; μισό του (i+1, r-i) με i = (n - 1 + r)/2.
elem_lookup:
        ld hl,(var_r)
        ld a,l
        xor e
        and 1
        ld (el_t),a
        add hl,de               ; n + r
        ld c,a
        ld b,0
        or a
        sbc hl,bc               ; n + r - t
        sra h
        rr l                    ; i
        push hl
        ld de,(var_r)
        ex de,hl
        or a
        sbc hl,de               ; J = r - i
        ex de,hl
        pop hl
        ld a,(el_t)
        ld c,a
        ld b,0
        add hl,bc               ; I = i + t
        call tile_lookup
        ld a,(el_t)
        or a
        ld a,12                 ; κάτω μισό: γραμμές 5-6
        jr z,.k
        xor a                   ; πάνω μισό: γραμμές 1-2
.k:     add a,l
        ld l,a
        ret

; ------------------------------------------------------------ η σειρά

; A = y (ζυγό). 8 γραμμές = 4 ζώνες, ολόκληρες.
draw_rows:
        ld b,4
.p:     push bc
        push af
        call draw_pair_safe
        pop af
        add a,2
        pop bc
        djnz .p
        ret

; Όπως το draw_pair, αλλά και για γραμμή που σπάει στα 2 KB: τότε στο
; buffer, και από εκεί στην οθόνη σε δύο κομμάτια.
draw_pair_safe:
        ld (col_y),a
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld (row_ent),hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld a,d                  ; σπάει αν η μετατόπιση είναι > #7B0
        and 7
        cp 7
        jr nz,.ok
        ld a,e
        cp #B1
        jr nc,.split
.ok:    ld a,(col_y)
        jp draw_pair
.split: ld (row_dst),de
        ld hl,(row_ent)         ; προσωρινά: η γραμμή είναι το buffer
        ld (hl),BUF_A & 255
        inc hl
        ld (hl),BUF_A >> 8
        ld a,(col_y)
        call draw_pair
        ld hl,(row_ent)
        ld de,(row_dst)
        ld (hl),e
        inc hl
        ld (hl),d
        ld hl,BUF_A
        ld de,(row_dst)
        call copy_split
        ld hl,BUF_A + #800
        ld de,(row_dst)
        set 3,d
        jp copy_split

; 80 bytes από HL (συνεχόμενα) σε DE (γραμμή οθόνης που σπάει στα 2 KB).
copy_split:
        xor a
        sub e                   ; ως το όριο: #100 - E (το D AND 7 είναι 7)
        ld c,a
        ld b,0
        push bc
        ldir
        ld a,d                  ; στην αρχή της οκτάδας
        sub 8
        ld d,a
        ld e,0
        pop bc
        ld a,80
        sub c
        ld c,a
        ldir
        ret

; A = y0 (πολλαπλάσιο του 8), B = πόσες σειρές ρόμβων (από τις 7, πίσω
; πρώτα): οι πόροι στη σειρά 8 γραμμών y0..y0+7. Το strip_more συνεχίζει.
;
; Όπως το draw_resources, αλλά το ψαλίδι είναι ΙΔΙΟ για όλα τα πλακίδια μιας
; σειράς ρόμβων r: οι γραμμές l0..l0+n-1 του sprite, η γραμμή οθόνης, η
; πηγή. Υπολογίζονται μία φορά ανά σειρά· ανά δέντρο μένουν τα n x 4 bytes,
; με D + 8 ανά γραμμή (όλες στην ίδια σειρά χαρακτήρων). Οι άκρες (X < 0 ή
; > 76) και τα 4 bytes που περνάνε όριο σελίδας πάνε από το blit_res.
strip_resources:
        ld (sr_y0),a
        ld e,a                  ; r = ((cam_y + y0 - 6) >> 2) + 1
        ld d,0
        ld hl,(cam_y)
        add hl,de
        ld de,-6
        add hl,de
        sra h
        rr l
        sra h
        rr l
        inc hl
        ld (var_r),hl
        ld a,b                  ; ως (8 + 16) / 4 + 1 = 7 σειρές
strip_more:                     ; A σειρές ακόμα, από το var_r
        ld (rows_left),a
.row:   ld hl,(var_r)           ; τα κτίρια πίσω από αυτή τη σειρά
        call row_flush
        ld hl,(var_r)           ; ry = 4r - cam_y + 6 = y_top + 16
        add hl,hl
        add hl,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld de,16 - 10
        add hl,de
        ld a,h
        or a
        jp nz,.next
        ld a,l
        cp VIEW_H + 16
        jp nc,.next
        ld (ry),a
        ld c,a                  ; l0 = max(0, y0 + 16 - ry)
        ld a,(sr_y0)
        add a,16
        sub c
        jr nc,.l0
        xor a
.l0:    cp RES_H
        jp nc,.next
        ld b,a                  ; B = l0
        ld a,(sr_y0)            ; l1 = min(16, y0 + 24 - ry)
        add a,24
        sub c
        jp c,.next
        jp z,.next
        cp RES_H
        jr c,.l1
        ld a,RES_H
.l1:    sub b
        jp c,.next
        jp z,.next
        ld (sr_n),a
        ld a,b
        add a,a
        add a,a
        add a,a
        ld (sr_src),a           ; l0 * 8
        ld a,c                  ; η γραμμή: ry - 16 + l0
        sub 16
        add a,b
        ld l,a
        ld h,0
        add hl,hl
        ld de,line_addr
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (sr_line),de
        ld hl,(var_r)           ; k = r + h· i0 = k >> 1, X0 = -2 (k AND 1)
        ld de,(cam_h)
        add hl,de
        ld a,l
        and 1
        ld c,a
        add a,20                ; 20 πλακίδια ως το X = 76, ή 21 ως το 78
        ld ixh,a
        ld a,c
        add a,a
        neg
        ld ixl,a
        sra h
        rr l
        ld (var_i),hl
        ld a,l
        ld b,a                  ; B = I
        ld a,(var_r)
        sub b
        ld c,a                  ; C = J
        ld (rj),a
        ld l,a                  ; HL = MAP + J*96 + I (J με πρόσημο)
        rlca
        sbc a,a
        ld h,a
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l
        add hl,hl
        add hl,de
        ld de,(var_i)
        add hl,de
        ld de,MAP
        add hl,de
        ; Τα πλακίδια μέσα στον χάρτη είναι ΣΥΝΕΧΟΜΕΝΑ (το I ανεβαίνει, το J
        ; κατεβαίνει): με ελέγχους ως το πρώτο, μετά χωρίς, για
        ; min(όσα μένουν, 96 - I, J + 1).
.tile:  ld a,b
        cp MAPW
        jr nc,.skip
        ld a,c
        cp MAPW
        jr c,.in
.skip:  inc b
        dec c
        ld de,1 - MAPW
        add hl,de
        ld a,ixl
        add a,4
        ld ixl,a
        dec ixh
        jr nz,.tile
        jr .next
.in:    ld a,MAPW
        sub b
        ld e,a
        ld a,c
        inc a
        cp e
        jr nc,.m1
        ld e,a
.m1:    ld a,ixh
        cp e
        jr nc,.m2
        ld e,a
.m2:    ld b,e                  ; B = πόσα, C = X
        ld a,ixl
        ld c,a
        ld de,1 - MAPW
.fast:  ld a,(hl)
        and #0F
        call nz,sr_blit
        add hl,de
        ld a,c
        add a,4
        ld c,a
        djnz .fast
.next:  ld hl,(var_r)
        inc hl
        ld (var_r),hl
        ld a,(rows_left)
        dec a
        ld (rows_left),a
        jp nz,.row
        ret

; A = πόρος, C = X. Κρατάει BC, DE, HL.
sr_blit:
        cp BLD_RES              ; πλακίδιο κτιρίου (M7): κανένα sprite
        ret z
        ld (sr_res),a
        ld a,c
        cp 77
        jr nc,.edge             ; X < 0 (254) ή X > 76: ψαλίδι οριζόντια
        push bc
        push de
        push hl
        ld a,(sr_res)           ; HL = res_gfx + (A-1)*128 + l0*8
        dec a
        rrca
        ld l,a
        and #7F
        ld h,a
        ld a,l
        and #80
        ld l,a
        ld de,res_gfx
        add hl,de
        ld a,(sr_src)
        add a,l
        ld l,a
        ld de,(sr_line)         ; DE = η γραμμή + X
        ld a,c
        add a,e
        ld e,a
        call c,de_carry
        ld a,e
        cp #FD
        jr nc,.slow
        ld c,e
        ld a,(sr_n)
        ld b,a
.l:     ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        inc e
        ld a,(de)
        and (hl)
        inc l
        or (hl)
        inc l
        ld (de),a
        ld e,c
        ld a,d
        add a,8
        ld d,a
        djnz .l
        pop hl
        pop de
        pop bc
        ret
.slow:  pop hl
        pop de
        pop bc
.edge:  ld a,c
        ld ixl,a
        ld a,(sr_res)
        jp res_here

; ------------------------------------------------------------ καθρέφτης

; A = c: τα bytes c, c+1 των γραμμών 0-143 στον καθρέφτη (C4). Οι 8
; γραμμές μιας σειράς έχουν το ίδιο low byte και τύλιγμα: μία διεύθυνση από
; τον πίνακα ανά σειρά, και D + 8 για τις υπόλοιπες.
mirror_column:
        ld c,a
        ld a,RAM_BG
        call setram
        ld hl,line_addr
        ld b,VIEW_H / 8
.row:   ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld a,c
        add a,e
        ld e,a
        call c,de_carry
        repeat 8
        ld h,d
        ld l,e
        res 7,h
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        dec e
        ld a,d
        add a,8
        ld d,a
        rend
        pop hl
        ld de,15
        add hl,de
        dec b
        jp nz,.row
        ld a,RAM_BASE
        jp setram

; A = y: 8 ολόκληρες γραμμές στον καθρέφτη.
mirror_rows:
        ld (col_y),a
        ld a,RAM_BG
        call setram
        ld b,8
.l:     push bc
        ld a,(col_y)
        ld b,0
        call line_x
        ld h,d
        ld l,e
        ld a,d                  ; σπάει;
        and 7
        cp 7
        jr nz,.one
        ld a,e
        cp #B1
        jr c,.one
        xor a                   ; δύο κομμάτια
        sub e
        ld c,a
        ld b,0
        push bc
        res 7,d
        ldir
        ld a,h
        sub 8
        ld h,a
        ld d,a
        res 7,d
        ld l,0
        ld e,0
        pop bc
        ld a,80
        sub c
        ld c,a
        ldir
        jp .n
.one:   res 7,d                 ; η συνηθισμένη: 80 LDI, ~25% πιο γρήγορα
        repeat 80               ; από το LDIR
        ldi
        rend
.n:     ld hl,col_y
        inc (hl)
        pop bc
        dec b
        jp nz,.l
        ld a,RAM_BASE
        jp setram
