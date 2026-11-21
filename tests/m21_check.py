"""M21: ο ήχος — η μουσική στη διακοπή και τα εφέ μόνο για ό,τι φαίνεται
(2026-11-21) — σε headless CPC 6128.

    python3 tests/m21_check.py

Η διακοπή (game/sound.asm, snd_isr) γράφει το AY 50 φορές το δευτερόλεπτο:
μελωδία στο A, μπάσο στο B (game/player.asm), εφέ στο C (sound_fx.asm).
Ελέγχει, από τους καταχωρητές του AY:

1. ΜΟΥΣΙΚΗ. Στο παιχνίδι: οι τόνοι των A και B είναι ΑΚΡΙΒΩΣ οι νότες του
   mus_game (src/make_music.py: οι περίοδοι, το A μία οκτάβα ψηλότερα),
   απαλά (ένταση ως 10), και μετά από ένα ολόκληρο τραγούδι οι ίδιες νότες
   με την ίδια σειρά, ανά βήμα (16 καρέ).
2. ΚΛΙΚ. SPACE: το κλικ στο C (R4 #28, τόνος).
3. ΜΑΧΗ ΣΤΗΝ ΟΘΟΝΗ. Η σκηνή του M8 (6 εναντίον 6) μπροστά στην κάμερα:
   χτυπήματα στο C (θόρυβος).
4. ΜΑΧΗ ΕΚΤΟΣ. Η ίδια σκηνή με την κάμερα μακριά: τα χτυπήματα γίνονται,
   αλλά στο C τίποτα.
5. ΑΠΟΣΤΑΣΗ. Η μάχη στην άκρη της οθόνης: πιο σιγά από ό,τι στη μέση.
   Το M τη σιωπά, και ξανά M την ξανανοίγει (στο παιχνίδι και στο μενού).
6. ΜΕΝΟΥ. Από τη δισκέτα: στο μενού έναρξης παίζει το mus_menu (οι νότες
   του), και με το PLAY το mus_game.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m1_check as M                            # noqa: E402
import m4_check as M4                           # noqa: E402
import m8_check as M8                           # noqa: E402
import scene as S                               # noqa: E402
import make_music as MU                         # noqa: E402
import cpc as CP                                # noqa: E402
from cpc import CPC                             # noqa: E402

PER = [758, 716, 676, 638, 602, 568, 536, 506, 478, 451, 426, 402]
ok = True


def report(name, good, what):
    global ok
    print('%-10s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    ok &= bool(good)


def periods(song, voice):
    """Οι περίοδοι που πρέπει να ακουστούν (το player.asm, .note)."""
    step, a, b = MU.SONGS[song]
    out = set()
    for byte in MU.voice(a if voice == 0 else b, 1 - voice):
        p = byte & 31
        if p in (0, 31):
            continue
        n, octv = (p - 1) % 12, (p - 1) // 12 + (1 - voice)
        out.add(PER[n] >> octv)
    return out


def song_frames(song):
    step, a, b = MU.SONGS[song]
    return step * sum(MU.DUR[x >> 5] for x in MU.voice(a, 1)[:-1])


def listen(c, frames, tick=None):
    """Οι καταχωρητές του AY σε κάθε καρέ."""
    out = []
    for _ in range(frames):
        if tick:
            tick(1)
        else:
            c.run_frames(1)
        out.append(c.psg_regs())
    return out


def tone(r, ch):
    return r[2 * ch] | r[2 * ch + 1] << 8


def fx_max(regs, r7):
    """Η μεγαλύτερη ένταση του C με αυτό το R7 (το εφέ)."""
    return max([r[10] for r in regs if r[7] == r7] + [0])


def music(g):
    c = g.c
    n = song_frames('mus_game')
    regs = listen(c, 2 * n + 50)
    got = [{tone(r, ch) for r in regs if r[8 + ch]} for ch in (0, 1)]
    want = [periods('mus_game', ch) for ch in (0, 1)]
    vols = {r[8] for r in regs} | {r[9] for r in regs}
    seq = [(tone(r, 0), tone(r, 1)) for r in regs]
    # ένα τραγούδι μετά: οι ίδιες νότες με την ίδια σειρά (όχι στο ίδιο
    # ακριβώς καρέ: μια διακοπή που πέφτει σε μακρύ di χάνεται, ~1 στα 700
    # καρέ — και για τον μετρητή του χρόνου, int_t)
    ch = [i for i in range(51, len(seq)) if seq[i] != seq[i - 1]]
    m = sum(1 for i in ch if i < 50 + n)
    st = [seq[i] for i in ch]
    gaps = [b - a for a, b in zip(ch, ch[1:])]
    loop = st[:m] == st[m:2 * m] and all(g % 16 in (0, 15) for g in gaps)
    report('ΜΟΥΣΙΚΗ', got[0] <= want[0] and got[1] <= want[1] and
           len(got[0]) >= len(want[0]) - 1 and len(got[1]) >= 4 and
           max(vols) <= 10 and loop,
           'A: %d από %d νότες, B: %d από %d· εντάσεις %d-%d· ξανά μετά από ~%d '
           'καρέ (%d νότες): %s' % (len(got[0]), len(want[0]), len(got[1]),
                                    len(want[1]), min(vols), max(vols), n, m,
                                    loop))


def press_m(c):
    c.key_down('m')
    c.run_frames(6)
    c.key_up('m')
    c.run_frames(6)


def mute(c, name):
    """M: η μουσική σιωπά (οι εντάσεις των A, B 0, το τραγούδι προχωράει)·
    ξανά M: ακούγεται."""
    press_m(c)
    off = listen(c, 200)
    press_m(c)
    on = listen(c, 200)
    silent = all(r[8] == 0 and r[9] == 0 for r in off)
    moving = len({tone(r, 0) for r in off}) > 1
    back = any(r[8] for r in on)
    report(name, silent and moving and back,
           'M: A, B σιωπηλά για 200 καρέ %s (οι νότες προχωράνε %s)· ξανά M: '
           'ακούγεται %s' % (silent, moving, back))


def click(g):
    c = g.c
    c.key_down(' ')
    regs = listen(c, 12)
    c.key_up(' ')
    g.tick(4)
    hit = [r for r in regs if r[10] and r[7] == 0x38 and r[4] == 0x28]
    report('ΚΛΙΚ', hit, 'SPACE: R4 #28, R7 #38, ένταση ως %d'
           % max([r[10] for r in hit] + [0]))


def set_cam(g, x, y):
    c, sym = g.c, g.sym
    for k, v in ((sym['CAM_X'], x), (sym['CAM_Y'], y)):
        c.write_ram(k, (v & 0xFFFF).to_bytes(2, 'little'))
    c.poke(sym['REDRAW'], 1)
    M.wait_phase(c, sym, 1, limit_ms=4000)
    M.wait_phase(c, sym, 6, limit_ms=4000)
    c.run_frames(60)                    # (και η σχεδίαση της κύλισης)


def battle(cam_dx, cam_dy, frames=500):
    """Η σκηνή του M8 με την κάμερα μετατοπισμένη από εκεί που τη βάζει:
    -> (η δυνατότερη ένταση του θορύβου στο C, πόσες ζημιές έγιναν)."""
    g = M4.Game(False)
    c, sym = g.c, g.sym
    g.tick(3)
    M8.setup(c, sym)
    foes = [S.unit(c, k) for k in M8.ENEMY]
    cx = sum(u['wx'] for u in foes) // len(foes) - 40 + cam_dx
    cy = sum(u['wy'] for u in foes) // len(foes) - 72 + cam_dy
    set_cam(g, cx & ~1, cy | 3)
    hp0 = bytes(S.c7_read(c, 0x7E00, S.UNITS))
    regs = listen(c, frames, g.tick)
    hp1 = bytes(S.c7_read(c, 0x7E00, S.UNITS))
    hurt = sum(1 for a, b in zip(hp0, hp1) if a != b)
    return fx_max(regs, 0x1C), hurt, (cx, cy)


def menu():
    c = CPC()
    c.run_frames(150)
    c.insert_disc(os.path.join(M.BUILD, 'polis.dsk'))
    c.type_text('RUN"POLIS\n')
    M.wait_menu(c)
    n = song_frames('mus_menu')
    regs = listen(c, n + 20)
    got = {tone(r, 0) for r in regs if r[8]}
    want = periods('mus_menu', 0)
    mute(c, 'M ΜΕΝΟΥ')
    c.key_down(CP.KEY_RETURN)                   # PLAY
    c.run_frames(4)
    c.key_up(CP.KEY_RETURN)
    sym = M.symbols()
    for _ in range(600):
        c.run_frames(5)
        if c.peek(sym['PHASE']) == 6:
            break
    regs2 = listen(c, 400)
    got2 = {tone(r, 0) for r in regs2 if r[8]}
    want2 = periods('mus_game', 0)
    report('ΜΕΝΟΥ', got <= want and len(got) >= len(want) - 1 and
           got2 and got2 <= want2,
           'στο μενού %d από τις %d νότες του mus_menu· στο παιχνίδι %d του '
           'mus_game (καμία άλλη: %s)' % (len(got), len(want), len(got2),
                                          got2 <= want2))


def main():
    g = M4.Game(False)
    g.tick(3)
    music(g)
    mute(g.c, 'M')
    click(g)
    v_mid, hurt_mid, cam = battle(0, 0)
    report('ΣΤΗΝ ΟΘΟΝΗ', v_mid and hurt_mid,
           'η μάχη στη μέση (κάμερα %s): %d ζημιές, θόρυβος στο C ως %d'
           % (cam, hurt_mid, v_mid))
    v_off, hurt_off, cam = battle(160, 0)
    report('ΕΚΤΟΣ', hurt_off and not v_off,
           'η κάμερα μακριά (%s): %d ζημιές, στο C %d' % (cam, hurt_off, v_off))
    v_edge, hurt_edge, cam = battle(30, 56)
    report('ΑΠΟΣΤΑΣΗ', hurt_edge and 0 < v_edge < v_mid,
           'η μάχη στην άκρη (%s): ως %d, στη μέση ως %d' % (cam, v_edge, v_mid))
    menu()
    print('M21 (ο ήχος): %s' % ('OK' if ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
