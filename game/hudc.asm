; hudc.asm — ρουτίνες στις κρυφές σειρές της σελίδας του HUD (HI_C, main.asm):
; η ουρά της επανασχεδίασης του φόντου, οι στήλες της ομίχλης, το πλαίσιο
; του μίνι χάρτη. Ως το M14 ζούσαν στην C7 (καλούνταν με το far7), που
; γέμισε· όπως το BOOT, τρέχουν ΜΟΝΟ με την C0 στο #4000 και δεν αλλάζουν
; οι ίδιες τράπεζα εκεί (το col_redraw, που αλλάζει, είναι στον κύριο κώδικα).

; ------------------------------------------------------------ επανασχεδίαση
; (από το buildings.asm και μετά την C7, M14.) ΜΙΑ επανασχεδίαση φόντου τη φορά (rq_*), σε
; κομμάτια των RQ_ROWS γραμμών, ένα ανά καρέ (bld_tick). Ως τώρα, μια νέα
; (π.χ. ένας θάμνος που άδειασε) ενώ η προηγούμενη ήταν στη μέση (το θεμέλιο
; ενός σπιτιού) την τελείωνε ΟΛΗ στο ίδιο καρέ: 146 ms. Τώρα η τρέχουσα
; περιμένει στο rqp (με το κομμάτι της), η νέα γίνεται, και μετά συνεχίζει
; η παλιά. Μόνο αν περιμένει ήδη μία, όπως πριν.
rqp_x:      dw 0                ; = rq_x, rq_yb, rq_h, rq_n, rq_half
            dw 0
            db 0
rqp_n:      db 255
            db 0
rq_free:
        ld a,(rq_n)
        inc a
        ret z
        ld a,(rqp_n)
        inc a
        jr nz,.sync
        ld hl,rq_x
        ld de,rqp_x
        ld bc,RQ_LEN
        ldir
        xor a
        ld (rq_half),a
        ret
.sync:  call rq_step
        jr rq_free

rq_step:
        ld a,(rq_n)
        inc a
        ret z                   ; καμία
        ld b,1
.c:     push bc
        ld hl,(rq_x)            ; η στήλη στην οθόνη
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.skip
        ld a,l
        cp 80 - 1
        jr nc,.skip
        push af
        ld hl,(rq_yb)           ; κάτω, πάνω (στο 0..VIEW_H, πολλαπλάσια του 4)
        ld de,(cam_y)
        or a
        sbc hl,de
        push hl
        ld c,VIEW_H
        call clamp_c
        add a,3
        and #FC
        ld (col_y1),a
        pop hl
        ld a,(rq_h)
        ld e,a
        ld d,0
        or a
        sbc hl,de
        call clamp_c
        and #FC
        ld (col_y0),a
        ld hl,col_y1
        cp (hl)
        pop bc                  ; B = η στήλη
        jr nc,.skip
        ld a,(rq_half)          ; ΣΕ ΚΟΜΜΑΤΙΑ ΤΩΝ RQ_ROWS ΓΡΑΜΜΩΝ (M9), ένα
        ld c,a                  ; ανά καρέ: μία στήλη ψηλού κτιρίου με τις
        add a,a                 ; μονάδες γύρω ξεπερνούσε τα 40 ms.
        add a,c                 ; y0 += RQ_ROWS x κομμάτι
        add a,a
        add a,a
        ld c,a
        ld a,(col_y0)
        add a,c
        ld (col_y0),a
        cp (hl)
        jr nc,.skip             ; (τίποτα άλλο σε αυτή τη στήλη)
        add a,RQ_ROWS
        cp (hl)
        jr nc,.last
        ld (hl),a               ; όχι το τελευταίο: ως εκεί, και η ίδια
        ld a,b                  ; στήλη στο επόμενο καρέ
        call col_redraw
        ld hl,rq_half
        inc (hl)
        pop bc
        ret
.last:  ld a,b
        call col_redraw
.skip:  xor a
        ld (rq_half),a
        ld hl,(rq_x)
        inc hl
        inc hl
        ld (rq_x),hl
        ld hl,rq_n
        dec (hl)
        pop bc
        jr z,.done
        dec b
        jp nz,.c
        ret
.done:  ld (hl),255
        ld a,(rqp_n)            ; η επανασχεδίαση που περίμενε: συνεχίζει
        inc a                   ; από εκεί που έμεινε
        ret z
        ld hl,rqp_x
        ld de,rq_x
        ld bc,RQ_LEN
        ldir
        ld a,255
        ld (rqp_n),a
        ret

; ============================================================ ΟΜΙΧΛΗ (M11)
;
; Τα νέα πλακίδια του fog_reveal (fog.asm) -> στήλες προς επανασχεδίαση
; (FD_TAB), και η επανασχεδίασή τους σε κάθε καρέ (fog_step, από το
; bld_tick).

; D = i, E = j: ένα πλακίδιο μόλις εξερευνήθηκε. Αν το κουτί του (και ο
; πόρος του, 12 γραμμές από πάνω) πέφτει στο παράθυρο: οι 2 στήλες του στο
; FD_TAB, σε συντεταγμένες κόσμου (ώστε να μένουν σωστές αν κυλήσει η
; κάμερα).
fog_new:
        ld l,d                  ; Y = 4 (i + j)
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        push hl
        ld a,d                  ; X = 2 (i - j) + XOFF
        sub e
        ld l,a
        rla
        sbc a,a
        ld h,a
        add hl,hl
        ld bc,XOFF
        add hl,bc
        ex (sp),hl              ; (sp) = X, HL = Y
        ld bc,(cam_y)           ; Y - cam_y + 8 στο 1..VIEW_H + 19
        or a
        sbc hl,bc
        ld bc,8
        add hl,bc
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        cp VIEW_H + 20
        jr nc,.no
        pop hl                  ; X - cam_x + 4 στο 1..83
        push hl
        ld bc,(cam_x)
        or a
        sbc hl,bc
        ld bc,4
        add hl,bc
        ld a,h
        or a
        jr nz,.no
        ld a,l
        or a
        jr z,.no
        cp 84
        jr nc,.no
        ld l,d                  ; y0 = Y - 12 (ως 0)
        ld h,0
        ld c,e
        ld b,h
        add hl,bc
        add hl,hl
        add hl,hl
        ld bc,-12
        add hl,bc
        jr c,.y
        ld hl,0
.y:     ex de,hl
        pop hl
        push hl
        push de
        call fd_add
        pop de
        pop hl
        inc hl
        inc hl
        jr fd_add
.no:    pop hl
        ret

; HL = wx, DE = y0 (κόσμος· y1 = y0 + 20): στο FD_TAB — με την ίδια στήλη
; ενώνεται. Γεμάτο: όλο το παράθυρο ξανά (redraw).
fd_add: ld (fd_x),hl
        ld (fd_y0),de
        ld hl,20
        add hl,de
        ld (fd_y1),hl
        ld hl,FD_TAB
        ld de,0                 ; η πρώτη ελεύθερη
        ld b,FD_N
.l:     push hl
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        inc a                   ; #FFFF: ελεύθερη
        jr nz,.u
        ld a,h
        inc a
        jr nz,.u
        ld a,d
        or e
        jr nz,.n
        pop de
        push de
        jr .n
.u:     push de
        ld de,(fd_x)
        or a
        sbc hl,de
        pop de
        jr z,.same
.n:     pop hl
        ld a,6
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc:    djnz .l
        ld a,d                  ; νέα
        or e
        jr z,.full
        ex de,hl
        ld de,fd_x
        ex de,hl
        ld bc,6
        ldir
        ret
.full:  ld a,1
        ld (redraw),a
        ret
.same:  pop hl                  ; ένωση: y0 = min, y1 = max
        inc hl
        inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld hl,(fd_y0)
        or a
        sbc hl,de
        pop hl
        jr nc,.y1
        ld de,(fd_y0)
        ld (hl),d
        dec hl
        ld (hl),e
        inc hl
.y1:    inc hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        push hl
        ld hl,(fd_y1)
        or a
        sbc hl,de
        pop hl
        ret c
        ret z
        ld de,(fd_y1)
        ld (hl),d
        dec hl
        ld (hl),e
        ret

; Σε κάθε καρέ μονάδων (bld_tick): οι στήλες του FD_TAB, σε κομμάτια των
; FD_ROWS γραμμών με το col_redraw, όσο το καρέ είναι κάτω από FOG_T (το
; πρώτο κομμάτι πάντα). Όσες βγήκαν από το παράθυρο ξεχνιούνται: όταν
; ξαναφανούν θα ζωγραφιστούν από την κύλιση.
FD_ROWS     equ 12
fog_step:
        ld hl,FD_TAB
        ld b,FD_N
.l:     ld a,(hl)
        inc hl
        and (hl)
        inc a
        jr nz,.go
        ld de,5
        add hl,de
        djnz .l
        ret
.go:    dec hl
        push hl
        call fd_one
        pop hl
        ld a,(t0)
        ld c,a
        ld a,(int_t)
        sub c
        cp FOG_T
        jr c,fog_step
        ret

; HL = μια εγγραφή του FD_TAB: ένα κομμάτι της στήλης της (ή ελεύθερη).
fd_one: ld e,(hl)               ; στήλη = wx - cam_x στο 0..78
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,(cam_x)
        or a
        sbc hl,de
        ld a,h
        or a
        jr nz,.free
        ld a,l
        cp 79
        jr nc,.free
        ld (fd_c),a
        pop hl
        push hl
        ld e,(hl)               ; y0, y1 - cam_y, στο 0..VIEW_H
        inc hl
        ld d,(hl)
        inc hl
        push hl
        ex de,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        ld c,VIEW_H
        call clamp_c
        and #FC
        ld (col_y0),a
        pop hl
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ld de,(cam_y)
        or a
        sbc hl,de
        call clamp_c
        add a,3
        and #FC
        ld (col_y1),a
        ld hl,col_y0
        sub (hl)
        jr z,.free
        jr c,.free
        cp FD_ROWS + 1          ; ως FD_ROWS: όλο, και ελεύθερη
        jr c,.last
        ld a,(hl)               ; αλλιώς ως y0 + FD_ROWS, και το y0 της
        add a,FD_ROWS           ; εγγραφής προχωράει
        ld (col_y1),a
        ld e,a
        ld d,0
        ld hl,(cam_y)
        add hl,de
        ex de,hl
        pop hl
        ld (hl),e
        inc hl
        ld (hl),d
        jr .draw
.last:  pop hl
        dec hl
        dec hl
        ld (hl),255
        inc hl
        ld (hl),255
.draw:  jp fd_draw
.free:  pop hl
        dec hl
        dec hl
        ld (hl),255
        inc hl
        ld (hl),255
        ret

; ------------------------------------------------------------ μίνι χάρτης

; Το πλαίσιο της κάμερας στη γραμμή mm_my του μίνι χάρτη (minimap.asm): στο
; mm_buf, pen MM_FRAME. Ο κόσμος -> μίνι χάρτης, όπως το mockup.minimap:
;   x0 = MM_X + (5 (cam_x - 192) + 48) / 96, x1 το ίδιο με cam_x + 80
;   y0 = MM_Y + (5 cam_y + 96) / 192,       y1 το ίδιο με cam_y + 144
; (διαίρεση με στρογγύλεμα προς τα κάτω).
mm_rect:
        ld hl,(cam_y)
        ld de,0
        call .ky
        ld (mr_y0),a
        ld hl,(cam_y)
        ld de,VIEW_H
        call .ky
        ld (mr_y1),a
        ld a,(mm_my)            ; η γραμμή: έξω από το πλαίσιο;
        add a,MM_Y
        ld c,a
        ld a,(mr_y0)
        cp c
        jr z,.edge              ; Z: πάνω πλευρά
        ret nc
        ld a,(mr_y1)
        cp c
        ret c
.edge:  push af                 ; Z: πάνω ή κάτω πλευρά
        ld hl,(cam_x)
        ld de,0
        call .kx
        ld (mr_x0),a
        ld hl,(cam_x)
        ld de,80
        call .kx
        ld (mr_x1),a
        pop af
        jr z,.hor
        ld a,(mr_x0)            ; ανάμεσα: οι δύο άκρες
        call .px
        ld a,(mr_x1)
        jr .px
.hor:   ld a,(mr_x0)            ; πάνω ή κάτω: x0..x1
.h:     push af
        call .px
        pop af
        ld hl,mr_x1
        cp (hl)
        inc a
        jr c,.h
        ret
.px:    sub MM_X - MM_N / 2     ; x -> k στο 0..19
        cp MM_N
        ret nc
        ld hl,mm_buf
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld (hl),MM_FRAME
        ret
.ky:    add hl,de               ; (5 y + 96) / 192 + MM_Y
        call .x5
        ld de,96
        add hl,de
        ld de,192
        ld a,MM_Y - 1
        jr .div
.kx:    add hl,de               ; (5 (x - 192) + 48 + 20 x 96) / 96 + MM_X - 20
        ld de,-192
        add hl,de
        call .x5
        ld de,48 + 20 * 96
        add hl,de
        ld de,96
        ld a,MM_X - 20 - 1
.div:   inc a                   ; HL ≥ 0 / DE
        or a
        sbc hl,de
        jr nc,.div
        ret
.x5:    ld d,h
        ld e,l
        add hl,hl
        add hl,hl
        add hl,de
        ret

mr_x0:      db 0
mr_x1:      db 0
mr_y0:      db 0
mr_y1:      db 0
