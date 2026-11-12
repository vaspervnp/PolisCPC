"""M13: σενάρια και εκστρατείες — σε headless CPC 6128, από τη δισκέτα.

    python3 tests/m13_check.py [--shots]

Οι δύο εκστρατείες (src/make_levels.py), με τη σειρά, στην ίδια δισκέτα:

1. ΕΚΣΤΡΑΤΕΙΑ. RUN"POLIS, GREEK CAMPAIGN: η οθόνη της πίστας pixel
   προς pixel (το κείμενο της κεφαλίδας με τη γραμματοσειρά του μενού).
2. ΠΙΣΤΑ (σε κάθε μία). Μετά το RETURN: ο χάρτης = το αρχείο της (εκτός από
   τις κατόψεις των δύο Κέντρων), ό,τι κρατάει η C7 από την κεφαλίδα (η
   διαδρομή, οι θέσεις του αντιπάλου, ο στόχος, η εκστρατεία, η πρόοδος),
   οι μονάδες και η κάμερα στις θέσεις της, οι πόροι, ο πολιτισμός — και η
   οθόνη = ο κόσμος του χάρτη της στον src/mockup.py, pixel προς pixel.
3. ΣΤΟΧΟΣ. Ο στόχος κάθε πίστας «σχεδόν» (τα δευτερόλεπτα, ο χρυσός, η
   εποχή — ή το τέλος του αντιπάλου): νίκη από το ai_end, και μετά από 3 s
   το παιχνίδι ξαναφορτώνεται από τη δισκέτα στην επόμενη πίστα· το
   PROG.BIN της δισκέτας έχει την πρόοδο.
4. ΗΤΤΑ. Στην 1η των Αιγυπτίων: ήττα -> η ίδια πίστα ξανά, η πρόοδος ίδια.
5. ΤΕΛΟΣ. Μετά την 4η: το μενού, και η πρόοδος της εκστρατείας στην 1.
6. ΣΥΝΕΧΕΙΑ. Στη μέση των Αιγυπτίων, νέος CPC με τη γραμμένη δισκέτα:
   η εκστρατεία συνεχίζει από την πίστα της προόδου.
7. ΧΡΟΝΟΣ — μέτρηση: από τη νίκη ως την οθόνη της επόμενης πίστας.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m3_check as M3                           # noqa: E402
import m12_check as M12                         # noqa: E402
import scene as S                               # noqa: E402
import dsk as DK                                # noqa: E402
import make_levels as ML                        # noqa: E402
import make_menu as MN                          # noqa: E402
import cpc as CP                                # noqa: E402
from cpc import CPC                             # noqa: E402

D = M.BUILD
LV_HDR = 0xA400
ok = True
times = []
LEVELS = {(lv[0], lv[1]): lv for lv in ML.LEVELS}
CAMP_IDX = {'G': 1, 'E': 2}
_built = {}


def report(name, good, what):
    global ok
    print('%-11s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    ok &= bool(good)


def build(camp, n):
    if (camp, n) not in _built:
        _built[camp, n] = ML.build(LEVELS[camp, n])
    return _built[camp, n]


def text_image(lines):
    """Οι γραμμές κειμένου (menu_lines) όπως τις ζωγραφίζει το mn_text."""
    img = [[0] * 160 for _ in range(200)]
    for y, xb, pen, text in lines:
        for k, ch in enumerate(text):
            for r, row in enumerate(MN.GLYPHS[ch]):
                for i, b in enumerate(row):
                    if b == '#':
                        for dy in (0, 1):
                            img[y + 2 * r + dy][2 * (xb + MN.CELL * k) + i] = \
                                pen
    return img


def brief_lines(camp, n):
    lv = LEVELS[camp, n]
    t1 = '%s %d/4' % (ML.CAMP_NAMES[camp], n)
    return [(60, (80 - MN.CELL * len(t1)) // 2, MN.PEN_HI, t1),
            (100, (80 - MN.CELL * len(lv[11])) // 2, MN.PEN_TEXT, lv[11])]


def wait_brief(c, camp, n, limit=6000):
    """Ως την οθόνη της πίστας: η κεφαλίδα της στο LV_HDR -> καρέ."""
    for f in range(0, limit, 5):
        h = c.read_ram(LV_HDR, ML.H_LEN)
        if h[:2] == bytes(ML.MAGIC) and h[ML.OFF['NUM']] == n and \
                h[ML.OFF['CAMP']] == CAMP_IDX[camp]:
            c.run_frames(25)
            return f + 25
        c.run_frames(5)
    raise RuntimeError('η πίστα %s%d δεν φορτώθηκε' % (camp, n))


def start_level(c, sym, camp, n, shots):
    """Στην οθόνη της πίστας: έλεγχος, RETURN, ως το πρώτο καρέ."""
    got = M12.screen_pens(c)
    exp = text_image(brief_lines(camp, n))
    bad = sum(1 for y in range(200) for x in range(160)
              if exp[y][x] != got[y][x])
    if shots:
        c.screenshot(os.path.join(D, 'm13_brief_%s%d.png' % (camp, n)),
                     aspect=True)
    c.tap_key(CP.KEY_RETURN)
    M.wait_phase(c, sym, 6, limit_ms=20000)
    return bad


def check_level(c, sym, camp, n, bad_brief, shots, tag=''):
    grd, res, hdr = build(camp, n)
    lv = LEVELS[camp, n]
    o = ML.OFF
    blob = open(os.path.join(M.ROOT, 'data', 'l%s%d.bin'
                             % (camp.lower(), n)), 'rb').read()
    tc, at = lv[3], lv[4]
    feet = set(ML.footprint(*tc, 4)) | set(ML.footprint(*at, 4))
    mp = c.read_ram(0x8000, 9216)
    map_bad = [(k % 96, k // 96) for k in range(9216)
               if mp[k] != blob[k] and (k % 96, k // 96) not in feet]
    c7 = S.c7_read(c, sym['LV_C7'], o['TEXT'] - o['ROUTE'])
    want = bytearray(hdr[o['ROUTE']:o['TEXT']])
    k_cool = o['COOL'] - o['ROUTE']
    cool = c7[k_cool] | c7[k_cool + 1] << 8
    c7 = bytearray(c7)
    c7[k_cool:k_cool + 2] = want[k_cool:k_cool + 2]
    want[o['CAMP'] - o['ROUTE']] = CAMP_IDX[camp]
    k_prog = o['PROG'] - o['ROUTE']
    prog = bytes(c7[k_prog:k_prog + 2])
    want[k_prog:k_prog + 2] = prog
    units = S.units(c)
    town = (hdr[o['TOWN']] | hdr[o['TOWN'] + 1] << 8,
            hdr[o['TOWN'] + 2] | hdr[o['TOWN'] + 3] << 8)
    aiu = (hdr[o['AIU']] | hdr[o['AIU'] + 1] << 8,
           hdr[o['AIU'] + 2] | hdr[o['AIU'] + 3] << 8)
    pos_ok = ((units[0]['wx'], units[0]['wy']) == town and
              (units[12]['wx'], units[12]['wy']) == aiu)
    cx, cy = M2.cam(c, sym)
    cam = ML.camera(tc)
    vals = [c.peek(sym['HUD_VAL'] + 2 * k) | c.peek(sym['HUD_VAL'] + 2 * k + 1)
            << 8 for k in range(4)]
    cult = c.read_ram(sym['AGE3_NAME'] + 4, 1).decode()
    for _ in range(3):
        M3.tick_time(c, sym)
    world = M.game_world(grd, res, blds=[('town_center',) + tuple(tc),
                                         ('town_center',) + tuple(at)],
                         seen=S.fog_seen(c))
    cx, cy = M2.cam(c, sym)
    screen = M2.diff(M2.decode_scrolled(c, sym),
                     S.expected(c, sym, M.reference(world, cx, cy)),
                     'm13_%s%d%s' % (camp, n, tag), c, shots)
    good = (bad_brief == 0 and not map_bad and bytes(c7) == bytes(want) and
            pos_ok and (cx, cy) == cam and list(vals) == list(lv[10]) and
            cult == camp and screen)
    report('ΠΙΣΤΑ %s%d%s' % (camp, n, tag), good,
           'οθόνη της πίστας: %d pixels διαφέρουν· χάρτης: %d πλακίδια '
           'διαφέρουν· C7 = κεφαλίδα: %s (κύμα σε %d s, πρόοδος %s)· μονάδες '
           '%s, κάμερα %s (%s), πόροι %s, πολιτισμός %s· η οθόνη = ο κόσμος: '
           '%s' % (bad_brief, len(map_bad), bytes(c7) == bytes(want), cool,
                   list(prog), pos_ok, (cx, cy), cam, vals, cult, screen))
    return list(prog)


def prog_file(c):
    path = os.path.join(D, 'm13_saved.dsk')
    open(path, 'wb').write(bytes(c.disc_image()))
    return list(DK.Dsk(path).get('PROG.BIN')[:2]), path


def finish(c, sym, camp, n, how):
    """Ο στόχος της πίστας (ή το τέλος της): νίκη / ήττα."""
    lv = LEVELS[camp, n]
    hv = sym['HUD_VAL']
    if how == 'loss':
        c.poke(sym['GAME_END'], 2)
        c.poke(sym['PAUSED'], 1)
        return 'ήττα'
    obj, arg = lv[7], lv[8]
    if obj == 'survive':
        S.c7_write(c, sym['LV_SEC'], [(arg - 3) & 255, (arg - 3) >> 8])
    elif obj == 'gold':
        c.poke(hv + 4, arg & 255)
        c.poke(hv + 5, arg >> 8)
    elif obj == 'age':
        c.poke(hv + 10, arg)
    else:                               # το τέλος του αντιπάλου (M10)
        c.poke(sym['GAME_END'], 1)
        c.poke(sym['PAUSED'], 1)
    for f in range(400):
        c.run_frames(5)
        if c.peek(sym['GAME_END']):
            break
    return '%s %d -> %s' % (obj, arg, {0: 'τίποτα', 1: 'νίκη', 2: 'ήττα'}[
        c.peek(sym['GAME_END'])])


def next_level(c, sym, camp, n, how, nxt, shots, tag=''):
    """Το τέλος της πίστας n, και η επόμενη nxt (0: το μενού)."""
    k_prog = sym['LV_C7'] + ML.OFF['PROG'] - ML.OFF['ROUTE']
    before = list(S.c7_read(c, k_prog, 2))
    what = finish(c, sym, camp, n, how)
    if nxt == 0:
        menu = M12.menu_image()
        for f in range(0, 8000, 10):
            c.run_frames(10)
            got = M12.screen_pens(c)
            if got == menu:
                break
        prog, _ = prog_file(c)
        report('ΤΕΛΟΣ %s' % camp, got == menu and
               prog[CAMP_IDX[camp] - 1] == 1,
               '%s: το μενού σε %.1f s, η πρόοδος στη δισκέτα %s'
               % (what, f / 50.0, prog))
        return
    f = wait_brief(c, camp, nxt)
    times.append(f / 50.0)
    prog, _ = prog_file(c)
    bad = start_level(c, sym, camp, nxt, shots)
    p = check_level(c, sym, camp, nxt, bad, shots, tag)
    k = CAMP_IDX[camp] - 1
    report('ΗΤΤΑ %s%d' % (camp, n) if how == 'loss' else
           'ΣΤΟΧΟΣ %s%d' % (camp, n),
           p == prog and (prog == before if how == 'loss' else
                          prog[k] == nxt),
           '%s· η πίστα %s%d σε %.1f s· PROG.BIN %s (πριν %s)' % (
               what, camp, nxt, f / 50.0, prog, before))


def campaign(c, sym, camp, shots, tag=''):
    """Από το μενού: η εκστρατεία camp -> η πίστα της προόδου."""
    idx = MN.items().index(dict(MN.CAMPAIGNS)[camp])
    for _ in range(idx - MN.SEL0):
        c.tap_key(CP.KEY_DOWN)
        c.run_frames(4)
    c.tap_key(CP.KEY_RETURN)


def main():
    shots = '--shots' in sys.argv
    sym = M.symbols()
    dsk_path = os.path.join(D, 'polis.dsk')

    c = M12.boot(dsk_path, [])
    campaign(c, sym, 'G', shots)
    wait_brief(c, 'G', 1)
    bad = start_level(c, sym, 'G', 1, shots)
    check_level(c, sym, 'G', 1, bad, shots)
    next_level(c, sym, 'G', 1, 'win', 2, shots)
    next_level(c, sym, 'G', 2, 'win', 3, shots)
    next_level(c, sym, 'G', 3, 'win', 4, shots)
    next_level(c, sym, 'G', 4, 'win', 0, shots)

    campaign(c, sym, 'E', shots)
    wait_brief(c, 'E', 1)
    bad = start_level(c, sym, 'E', 1, shots)
    check_level(c, sym, 'E', 1, bad, shots)
    next_level(c, sym, 'E', 1, 'loss', 1, shots, tag=' (ξανά)')
    next_level(c, sym, 'E', 1, 'win', 2, shots)
    next_level(c, sym, 'E', 2, 'win', 3, shots)

    prog, path = prog_file(c)
    b = M12.boot(path, [])
    campaign(b, sym, 'E', shots)
    f = wait_brief(b, 'E', 3)
    bad = start_level(b, sym, 'E', 3, shots)
    p = check_level(b, sym, 'E', 3, bad, shots, tag=' (νέος CPC)')
    report('ΣΥΝΕΧΕΙΑ', p == prog,
           'νέος CPC με τη δισκέτα (πρόοδος %s), EGYPTIAN CAMPAIGN: η 3η'
           % prog)
    next_level(b, sym, 'E', 3, 'win', 4, shots)
    next_level(b, sym, 'E', 4, 'win', 0, shots)

    print('ΧΡΟΝΟΣ      μέτρηση   από τη νίκη ως την οθόνη της επόμενης '
          'πίστας: %s s (με τα 3 s της νίκης)'
          % ', '.join('%.1f' % t for t in times))
    print('M13', 'OK' if ok else 'ΑΠΟΤΥΧΙΑ')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
