; ui_hud.asm — τα κουμπιά του HUD (M20, 2026-11-21): BUILD, TRAIN, RESEARCH,
; SPLIT SQUAD, NEXT AGE, IDLE VILLAGER, SAVE GAME, CANCEL (src/mockup.py,
; BUTTONS: 2 σειρές x 4).
;
; Ο κέρσορας που κατεβαίνει κάτω από τον χάρτη μπαίνει στα κουμπιά (hb_on):
; Q A O P πάνε από κουμπί σε κουμπί, και το τρέχον φωτίζεται (το φόντο του
; αλλάζει pen: hb_swap). Η ετικέτα του γράφεται στην κορυφή του χάρτη σε
; κάθε καρέ (hb_label, μετά τις μονάδες). SPACE / RETURN το πατάνε. Πάνω από
; την πρώτη σειρά: πίσω στον χάρτη (η λωρίδα της ετικέτας από τον
; καθρέφτη). (Ως το M21 το A κρατημένο στην κάτω σειρά κυλούσε και τον
; χάρτη: ένα πάτημα για την κάτω σειρά που κρατούσε δύο καρέ τον κυλούσε.)
;
; Στις κρυφές σειρές της σελίδας του HUD, όπως το ui.asm: μόνο με την C0.

hb_on:  db 0
hb_i:   db 0
hb_iv:  db 0                    ; ο τελευταίος αδρανής χωρικός (IDLE)

; Από το cursor_input όταν ο κέρσορας περνάει την κάτω άκρη του χάρτη.
hb_enter:
        ld a,1
        ld (hb_on),a
        ld a,(hb_i)
        jp hb_lit

; Από το cursor_input όσο hb_on, με D = τα πλήκτρα (cin).
hb_keys:
        ld a,(cin_prev)
        ld e,a
        ld a,d
        ld (cin_prev),a
        ld a,e
        cpl
        and d
        ld b,a                  ; B = μόλις πατήθηκαν
        ld a,(hb_i)
        ld c,a
        bit IN_LEFT,b           ; (M22: μόνο στα φανερά — hudvis.asm)
        jr z,.l
        ld d,-1
        call hb_step
.l:     bit IN_RIGHT,b
        jr z,.r
        ld d,1
        call hb_step
.r:     bit IN_UP,b
        jr z,.u
        ld a,c
        sub 4
        jr c,hb_off             ; πάνω από την πρώτη σειρά: ο χάρτης —
        call hb_vrow            ; και όταν η πρώτη δεν έχει κανένα φανερό
        jr nc,hb_off
.u:     ld a,c
        cp 4                    ; (κάτω από τη δεύτερη: τίποτα — ο χάρτης
        jr nc,.d                ; κυλάει με τα βελάκια)
        bit IN_DOWN,b
        jr z,.d
        add a,4
        call hb_vrow            ; (το πιο κοντινό φανερό από κάτω)
.d:     ld a,(hb_i)
        cp c
        call nz,hb_move
        ld a,b
        and 1 << IN_FIRE | 1 << IN_CMD
        ret z
        ld a,(hb_i)
        jp hb_do

; C = το νέο κουμπί.
hb_move:
        push bc
        ld a,(hb_i)
        call hb_dim
        pop bc
        ld a,c
        ld (hb_i),a
        push bc
        call hb_lit
        pop bc
        ret

; Πίσω στον χάρτη: το κουμπί σβήνει, η λωρίδα της ετικέτας από τον
; καθρέφτη, οι μονάδες ξανά.
hb_off: ld a,(hb_i)
        call hb_dim
        xor a
        ld (hb_on),a
        ld b,a
        ld c,a
        ld de,80 * 256 + 8
        call mirror_rect
        jp units_forget

; A = κουμπί: η πράξη του.
hb_do:  or a
        jr z,.build
        dec a
        jp z,bld_train          ; TRAIN: μία μονάδα στην ουρά του κτιρίου
        dec a
        jp z,hb_res
        dec a
        jp z,sq_split           ; SPLIT SQUAD
        dec a
        jp z,age_open
        dec a
        jp z,hb_idle
        dec a
        jp z,hb_save
        ld a,255                ; CANCEL: η τοποθέτηση
        ld (bmode),a
        jp cur_look
.build: call sel_villager       ; BUILD: με χωρικούς επιλεγμένους
        ret nc
        ld a,MK_BUILD
        jp um_open
hb_end:
