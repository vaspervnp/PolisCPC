"""Τα μενού του παιχνιδιού (M20, game/ui.asm) για τους ελέγχους.

Ως το M19 οι έλεγχοι πατούσαν τα γράμματα (H, B, T, U, X, ESC...). Από το
M20 τα ίδια γίνονται από τα μενού: εδώ ανοίγει το μενού (όπως η επιλογή του
παίκτη: um_kind, um_on = 2), βρίσκεται η γραμμή της πράξης, ο δείκτης πάει
εκεί με το A και διαλέγεται με RETURN — τα πλήκτρα, όπως ο παίκτης.

Οι διευθύνσεις: build/ui_sym.asm (το build.sh τις βγάζει από το πέρασμα
του POLIS.BIN· το snapshot δεν συναρμολογεί το ui.asm).
"""
import os

import m1_check as M
import cpc as CPCMOD

RECTS = 0xA780                  # game/units.asm
UI_T = RECTS                    # οι τεχνολογίες του μενού (res_list)
UM_ACT = UI_T + 80              # game/ui.asm: um_act, um_arg, um_ok
UM_ARG = UM_ACT + 16
UM_OK = UM_ARG + 16

MK_BUILD, MK_BLD, MK_SQUAD = 0, 1, 2
MA_CLOSE, MA_BUILD, MA_TRAIN, MA_TECH, MA_SPLIT, MA_BUSY = range(6)


def syms():
    out = {}
    with open(os.path.join(M.BUILD, 'ui_sym.asm')) as f:
        for line in f:
            name, _, val = line.split()
            out[name.upper()] = int(val[1:], 16)
    return out


U = syms()


def rb(c, a):
    """Η σελίδα του HUD (#4000-#7FFF) από τη ΒΑΣΙΚΗ RAM: το peek / poke είναι
    ό,τι βλέπει ο Z80, και εκεί ίσως είναι μια άλλη τράπεζα (C4-C7)."""
    return c.read_ram(a, 1)[0]


def wb(c, a, v):
    c.write_ram(a, bytes([v]))


def is_open(c):
    return rb(c, U['UM_ON']) != 0


def frames(c, n):
    c.run_frames(n)


def wait_open(c, limit=200):
    """Ώσπου το μενού να ζωγραφιστεί (um_on = 1)."""
    for _ in range(limit):
        if rb(c, U['UM_ON']) == 1:
            frames(c, 4)        # (το πρώτο του καρέ: ό,τι είναι πατημένο
            return True         # αγνοείται ώσπου να αφεθεί)
        if rb(c, U['UM_ON']) == 0:
            return False
        frames(c, 2)
    return False


def rows(c):
    """Οι γραμμές του ανοιχτού μενού: (πράξη, όρισμα, διαλέγεται)."""
    n = rb(c, U['UM_N'])
    a = c.read_ram(UM_ACT, n)
    g = c.read_ram(UM_ARG, n)
    k = c.read_ram(UM_OK, n)
    return [(a[i], g[i], k[i]) for i in range(n)]


def tap(c, key, n=4):
    c.key_down(key)
    frames(c, n)
    c.key_up(key)
    frames(c, n)


def choose(c, act, arg=None):
    """Στο ανοιχτό μενού: η πρώτη γραμμή της πράξης (και του ορίσματος), με
    A ως εκεί και RETURN. -> True αν βρέθηκε και διαλέγεται."""
    if not wait_open(c):
        return False
    rs = rows(c)
    want = [i for i, (a, g, ok) in enumerate(rs)
            if a == act and (arg is None or g == arg)]
    if not want or not rs[want[0]][2]:
        close(c)
        return False
    for _ in range(40):
        i = rb(c, U['UM_I'])
        if i == want[0]:
            break
        tap(c, 'a')
    tap(c, CPCMOD.KEY_RETURN)
    settle(c)
    return True


def settle(c):
    """Ώσπου το μενού να κλείσει, και ένα καρέ μονάδων μετά: το um_close
    ξεχνάει τις μονάδες (units_forget: SX, SY = 255) ώσπου να ξανασχεδιαστούν."""
    for _ in range(50):
        if not is_open(c):
            break
        frames(c, 2)
    frames(c, 6)


def close(c):
    """Το ανοιχτό μενού κλείνει (CLOSE)."""
    if not wait_open(c):
        return
    rs = rows(c)
    while rb(c, U['UM_I']) != len(rs) - 1:
        tap(c, 'a')
    tap(c, CPCMOD.KEY_RETURN)
    settle(c)


def open_menu(c, kind):
    """Όπως η επιλογή του παίκτη (game/ui.asm, um_open)."""
    wb(c, U['UM_KIND'], kind)
    wb(c, U['UM_ON'], 2)


def build(c, typ):
    """Ό,τι ήταν το γράμμα του κτιρίου: με χωρικούς επιλεγμένους, το BUILD
    και ο τύπος (αριθμός, ή κλειδί του src/make_bank6.py). -> True αν
    διαλέχτηκε (τότε το bmode = ο τύπος)."""
    if isinstance(typ, str):
        import make_bank6 as MB
        typ = [t[0] for t in MB.TYPES].index(typ)
    open_menu(c, MK_BUILD)
    return choose(c, MA_BUILD, typ)


def train(c):
    """Ό,τι ήταν το T: το μενού του επιλεγμένου κτιρίου, TRAIN."""
    open_menu(c, MK_BLD)
    return choose(c, MA_TRAIN)


def research(c, nth=0):
    """Ό,τι ήταν το U: η τεχνολογία nth του μενού του κτιρίου."""
    open_menu(c, MK_BLD)
    if not wait_open(c):
        return False
    techs = [i for i, (a, g, ok) in enumerate(rows(c)) if a == MA_TECH]
    if nth >= len(techs):
        close(c)
        return False
    return choose(c, MA_TECH, rows(c)[techs[nth]][1])


def split(c):
    """Ό,τι ήταν το X: το μενού της ομάδας, SPLIT SQUAD."""
    open_menu(c, MK_SQUAD)
    return choose(c, MA_SPLIT)


def cancel(c):
    """Ό,τι ήταν το ESC στην τοποθέτηση: SPACE."""
    tap(c, ' ')


# Τα κουμπιά του HUD (game/ui_hud.asm): 2 σειρές x 4.
HB_BUILD, HB_TRAIN, HB_RESEARCH, HB_SPLIT, HB_AGE, HB_IDLE, HB_SAVE, \
    HB_CANCEL = range(8)


def hud_enter(c, limit=400):
    """Ο κέρσορας κάτω ως τα κουμπιά (κρατημένο A ώσπου hb_on)."""
    c.key_down('a')
    for _ in range(limit):
        if rb(c, U['HB_ON']):
            break
        frames(c, 1)
    c.key_up('a')
    frames(c, 4)
    return rb(c, U['HB_ON']) != 0


def hud_leave(c):
    """Q ώσπου ο κέρσορας να βγει πάνω, στον χάρτη."""
    for _ in range(4):
        if not rb(c, U['HB_ON']):
            return
        tap(c, 'q')


def hud_button(c, k, key=' ', leave=True):
    """Ο κέρσορας στο κουμπί k με Q A O P και SPACE πάνω του, όπως ο
    παίκτης· μετά (leave) πίσω στον χάρτη."""
    if not rb(c, U['HB_ON']) and not hud_enter(c):
        return False
    for _ in range(12):
        i = rb(c, U['HB_I'])
        if i == k:
            break
        if i // 4 != k // 4:
            tap(c, 'a' if k >= 4 else 'q')
        else:
            tap(c, 'p' if k > i else 'o')
    if rb(c, U['HB_I']) != k:
        return False
    tap(c, key)
    if leave:
        hud_leave(c)
    return True
