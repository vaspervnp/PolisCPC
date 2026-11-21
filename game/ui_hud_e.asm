; ui_hud_e.asm — (M20) τα κουμπιά του HUD: η κάμερα πάνω στον αδρανή
; χωρικό (μετά το ui.asm, στο UI_AT).

hb_got:
   ld a,c
        ld (hb_iv),a
        push ix
        call sel_none
        pop ix
        call unit_select
        ld l,(ix+U_WX)          ; cam_x = WX - 38, ζυγό, στο 0..MAX_CAM_X
        ld h,(ix+U_WX+1)
        ld de,-38
        add hl,de
        res 0,l
        bit 7,h
        jr z,.x0
        ld hl,0
.x0:    ld de,MAX_CAM_X
        call .min
        ld (cam_x),hl
        ld l,(ix+U_WY)          ; cam_y = (WY - 64) OR 7, στο -1..MAX_CAM_Y
        ld h,(ix+U_WY+1)
        ld de,-64
        add hl,de
        ld a,l
        or 7
        ld l,a
        ld de,MAX_CAM_Y
        call .min
        ld (cam_y),hl
        ld a,1
        ld (redraw),a
        ret
.min:   push hl                 ; HL = min(HL, DE) (προσημασμένα: HL ≥ -1)
        or a
        sbc hl,de
        pop hl
        ret c
        ex de,hl
        ret


hb_res: ld a,(sel_bld)          ; RESEARCH: το μενού του κτιρίου
        cp 255
        ret z
        call brec_iy
        ld a,(iy+B_OWN)
        or a
        ret nz
        ld a,MK_BLD
        jp um_open
hb_save:
        ld a,1                  ; SAVE GAME (ως το M19: V)
        ld (save_req),a
        ret
