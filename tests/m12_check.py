"""M12: ήχος, μενού, αποθήκευση — σε headless CPC 6128.

    python3 tests/m12_check.py [--shots]

ΗΧΟΣ (από το snapshot, όπως οι άλλοι έλεγχοι):
1. ΚΛΙΚ. SPACE: το εφέ του κλικ στους καταχωρητές του AY (τόνος στο A, η
   περιβάλλουσα).
2. ΚΤΙΡΙΟ. Ένα ακόμα έτοιμο κτίριο του παίκτη (ο μετρητής του snd_tick
   μηδενίζεται): το εφέ του κτιρίου (τόνος στο C).
3. ΜΑΧΗ. Η σκηνή του M8 (6 εναντίον 6): χτυπήματα (θόρυβος στο B) και
   ειδοποίηση επίθεσης στον παίκτη, το πολύ μία στα 10 s.

ΑΠΟ ΤΗ ΔΙΣΚΕΤΑ (RUN"POLIS):
4. ΜΕΝΟΥ. Η οθόνη του μενού pixel προς pixel = η εικόνα του
   src/make_title.py με τις επιλογές του src/make_menu.py από πάνω.
5. ΠΟΛΙΤΙΣΜΟΣ. PLAY AS, δεξιά x3, RETURN: οι Ρωμαίοι — τα ονόματα AGE3R / AGE4R.
6. ΕΠΟΧΗ. Η Εποχή του Χαλκού (age_req, όπως στο τέλος της έρευνας): οι
   εικόνες των Ρωμαίων από τη δισκέτα, η οθόνη = ο κόσμος των Ρωμαίων pixel
   προς pixel, και η ομίχλη ΙΔΙΑ (το φόρτωμα σβήνει την αρχή της· το
   age_load τη φυλάει).
7. ΑΠΟΘΗΚΕΥΣΗ. Μια μονάδα σε κίνηση, V: το SAVE.BIN της δισκέτας έχει την
   υπογραφή και, κομμάτι προς κομμάτι, τη μνήμη (κύρια RAM από τα ονόματα,
   σελίδα του HUD, #8000-#BEFF, C7, ομίχλη).
8. ΦΟΡΤΩΣΗ. Reset: νέος CPC με τη γραμμένη δισκέτα, RUN"POLIS, ΦΟΡΤΩΣΗ. Η
   μνήμη = το αρχείο (εκτός από τα phase, int_t, int_n, dk_res), οι εικόνες
   των Ρωμαίων ξανά στο bld_types, και η οθόνη = αυτή μετά την αποθήκευση.
9. ΣΥΝΕΧΕΙΑ. Και οι δύο παρτίδες για 100 καρέ μονάδων: οι μονάδες στις ίδιες
   θέσεις.
10. ΚΑΜΙΑ ΠΑΡΤΙΔΑ. Σε καθαρή δισκέτα, ΦΟΡΤΩΣΗ: νέο παιχνίδι.
11. ΧΡΟΝΟΣ — μέτρηση: πόσο κρατάνε η αποθήκευση και το φόρτωμα.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m3_check as M3                           # noqa: E402
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m8_check as M8                           # noqa: E402
import scene as S                               # noqa: E402
import dsk as DK                                # noqa: E402
import make_menu as MN                          # noqa: E402
import make_title as MT                         # noqa: E402
import make_bank6 as MB                         # noqa: E402
import cpc as CP                                # noqa: E402
from cpc import CPC                             # noqa: E402

D = M.BUILD
SIG = b'POLIS-M12'
STACK_LOW = 0xBF00
FOG, FOG_LEN = 0x5F80, 1152
ALERT_GAP = 250                 # καρέ μονάδων (bank7.asm, SND_ALERT)
ok = True


def report(name, good, what):
    global ok
    print('%-10s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
    ok &= bool(good)


def fx(c):
    """Ποιο εφέ γράφτηκε τελευταίο στο AY (από το R7 του)."""
    r = c.psg_regs()
    return {0x3E: 'κλικ', 0x2F: 'χτύπημα', 0x3B: 'κτίριο',
            0x36: 'επίθεση'}.get(r[7], '?'), r


# ---------------------------------------------------------------- ήχος

def sound():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.tick(3)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(1)
    name, r = fx(c)
    report('ΚΛΙΚ', name == 'κλικ' and r[0] == 0x28 and r[8] == 16 and
           r[9] == 0 and r[10] == 0 and r[11] == 6,
           'SPACE: %s, R0 #%02X, έντασεις %s, περιβάλλουσα %d'
           % (name, r[0], r[8:11], r[11]))
    g.tick(5)
    S.c7_write(c, sym['SND_NB'], [0])
    g.tick(2)
    name, r = fx(c)
    report('ΚΤΙΡΙΟ', name == 'κτίριο' and r[4] == 0xA0 and r[10] == 16 and
           r[8] == 0 and r[9] == 0,
           'ένα ακόμα έτοιμο κτίριο του παίκτη: %s, R4 #%02X, έντασεις %s'
           % (name, r[4], r[8:11]))
    M8.setup(c, sym)
    hits, alerts, prev_al = 0, [], 0
    for f in range(1500):
        g.tick(1)
        name, r = fx(c)
        if name == 'χτύπημα' and r[9] == 16:
            hits += 1
        al = S.c7_read(c, sym['SND_AL'])[0]
        if al > prev_al:
            alerts.append(f)
        prev_al = al
    gaps = [b - a for a, b in zip(alerts, alerts[1:])]
    report('ΜΑΧΗ', hits and alerts and all(x >= ALERT_GAP for x in gaps),
           '%d καρέ με χτύπημα στο AY· ειδοποιήσεις στα καρέ %s (ανά >= %d)'
           % (hits, alerts, ALERT_GAP))


# ---------------------------------------------------------------- δισκέτα

def boot(disc, keys):
    """RUN"POLIS, και στο μενού τα πλήκτρα (λίστα), RETURN."""
    c = CPC()
    c.run_frames(150)
    c.insert_disc(disc)
    c.type_text('RUN"POLIS\n')
    M.wait_menu(c)
    for k in keys:
        c.key_down(k)
        c.run_frames(4)
        c.key_up(k)
        c.run_frames(4)
    return c


def menu_image(cult=None):
    """Το μενού όπως το ζωγραφίζει το menu.asm: η εικόνα του TITLE.BIN
    (src/make_title.py) και από πάνω οι επιλογές, [y][x] pens."""
    img = MT.image()
    for y, xb, pen, text in MN.lines(MN.DEFAULT if cult is None else cult):
        for k, ch in enumerate(text):
            x0 = 2 * (xb + MN.CELL * k)
            for r, row in enumerate(MN.GLYPHS[ch]):
                bits = row + '.'                # 6 pixels: 3 bytes
                for dy in (0, 1):
                    for i, b in enumerate(bits):
                        img[y + 2 * r + dy][x0 + i] = pen if b == '#' else 0
    y = MN.ITEM_Y0 + MN.SEL0 * MN.ITEM_DY
    for r, row in enumerate(MN.GLYPHS['>']):
        for dy in (0, 1):
            for i, b in enumerate(row + '.'):
                img[y + 2 * r + dy][2 * (MN.ITEM_X - 2 * MN.CELL) + i] = \
                    MN.PEN_HI if b == '#' else 0
    return img


def screen_pens(c):
    out = []
    for y in range(200):
        a = 0xC000 + (y & 7) * 0x800 + (y >> 3) * 80
        row = []
        for b in c.read_ram(a, 80):
            row += [((b >> 7) & 1) | ((b >> 3) & 1) << 1 | ((b >> 5) & 1) << 2
                    | ((b >> 1) & 1) << 3,
                    ((b >> 6) & 1) | ((b >> 2) & 1) << 1 | ((b >> 4) & 1) << 2
                    | (b & 1) << 3]
        out.append(row)
    return out


def segments(sym):
    m0 = sym['AGE3_NAME']
    return [('κύρια', 0, m0, 0x4000 - m0), ('HUD', 0, 0x4000, 0x4000),
            ('#8000', 0, 0x8000, STACK_LOW - 0x8000),
            ('C7', 7, 0x6800, 0x1800), ('ομίχλη', 6, FOG, FOG_LEN)]


def memory(c, bank, addr, n):
    if bank == 0:
        return c.read_ram(addr, n)
    p = S.bank_ram(c, bank)
    return bytes(p[addr - 0x4000 + k] for k in range(n))


def compare(c, sym, data):
    """(διαφορές ανά κομμάτι, ονόματα των bytes της κύριας RAM)."""
    # ό,τι γράφει η ίδια η επανασχεδίαση / ο χρόνος / ο οδηγός: όχι παρτίδα
    allowed = {sym[k] + i for k, n in (('PHASE', 1), ('UPHASE', 1),
                                       ('INT_T', 1), ('INT_N', 1),
                                       ('DK_RES', 7), ('HUD_DIRTY', 1))
               for i in range(n)}
    allowed |= {v for k, v in sym.items() if k.startswith(('RG_', 'BB_'))
                and '.' not in k}
    off, out = len(SIG), {}
    for name, bank, addr, n in segments(sym):
        saved, cur = data[off:off + n], memory(c, bank, addr, n)
        off += n
        out[name] = [addr + k for k in range(n) if saved[k] != cur[k] and
                     not (bank == 0 and addr + k in allowed)]
    return out


def names(sym, addrs):
    """Οι διευθύνσεις ως σύμβολο + απόσταση (για τις αναφορές)."""
    pairs = sorted((v, k) for k, v in sym.items() if v < 0x4000)
    out = []
    for a in addrs:
        v, k = max(p for p in pairs if p[0] <= a)
        out.append('%s+%d' % (k, a - v))
    return out


def advance(c, sym, t):
    """Ως ΜΕΤΑ το καρέ μονάδων του ticks = t: το ticks γίνεται t + 1 (περιττό:
    χωρίς μονάδες, ένα ολόκληρο VSYNC — το «uphase 4» κρατάει όσο περισσεύει
    από τα 40 ms, και ένα καρέ κοντά στα 40 το κάνει σχεδόν μηδέν)."""
    for _ in range(4000):
        if c.peek(sym['TICKS']) == (t + 1) & 255:
            return
        c.run_us(1000)
    raise RuntimeError('ticks %d δεν ήρθε (%d)' % (t + 1, c.peek(sym['TICKS'])))


def units_pos(c):
    return [(u['wx'], u['wy'], u['team']) for u in S.units(c)]


def wait_save(c, sym):
    """V ως την επανασχεδίαση μετά την αποθήκευση -> καρέ (50 Hz)."""
    c.key_down('v')
    c.run_frames(4)
    c.key_up('v')
    for f in range(3000):
        c.run_frames(1)
        if c.peek(sym['PHASE']) != 6:
            break
    M.wait_phase(c, sym, 2, limit_ms=4000)
    return f + 4


def disk():
    sym = M.symbols()
    shots = '--shots' in sys.argv
    dsk_path = os.path.join(D, 'polis.dsk')

    # ------------------------------------------------------------ 4. μενού
    c = boot(dsk_path, [])
    exp, got = menu_image(), screen_pens(c)
    bad = sum(1 for y in range(200) for x in range(160)
              if exp[y][x] != got[y][x])
    if shots:
        c.screenshot(os.path.join(D, 'm12_menu.png'), aspect=True)
    report('ΜΕΝΟΥ', bad == 0, 'η οθόνη του μενού: %d pixels διαφέρουν' % bad)

    # ------------------------------------------------------ 5. πολιτισμός
    for k in (CP.KEY_RIGHT,) * 3:
        c.key_down(k)
        c.run_frames(4)
        c.key_up(k)
        c.run_frames(4)
    c.tap_key(CP.KEY_RETURN)
    M.wait_phase(c, sym, 6, limit_ms=10000)
    nm = c.read_ram(sym['AGE3_NAME'], 33)
    report('ΠΟΛΙΤΙΣΜΟΣ', nm[:5] == b'AGE3R' and nm[22:27] == b'AGE4R',
           'PLAY AS, δεξιά x3, RETURN: %s, %s' % (nm[:11], nm[22:33]))

    # ---------------------------------------------------------- 6. εποχή
    seen0 = S.fog_seen(c)
    c.poke(sym['AGE_REQ'], 3)          # (το τέλος της έρευνας: bank7.asm)
    c.poke(sym['RES_N'], 1)
    for f in range(3000):               # (το φόρτωμα: ~1,6 s σε ένα καρέ)
        c.run_frames(2)
        if c.peek(S.HUD_AGE) == 3 and c.peek(sym['AGE_Q']) == 255 and \
                c.peek(sym['RQ_N']) == 255:
            break
    for _ in range(3):
        M3.tick_time(c, sym)
    seen1 = S.fog_seen(c)
    MB.CULTURE, S.CULTURE = 'rome', 'R'
    world = M.game_world(age=3, seen=seen1)
    cx, cy = M2.cam(c, sym)
    good = M2.diff(M2.decode_scrolled(c, sym),
                   S.expected(c, sym, M.reference(world, cx, cy)),
                   'm12_rome', c, shots)
    tab = open(os.path.join(M.ROOT, 'data', 'age3R.bin'), 'rb').read()
    tc_h = c.peek(sym['BLD_TYPES'] + 9)
    report('ΕΠΟΧΗ', good and seen1 == seen0 and tc_h == tab[0] and
           c.peek(S.HUD_AGE) == 3,
           'Χαλκού σε %d καρέ: Κέντρο Πόλης ύψους %d (των Ρωμαίων %d), η '
           'οθόνη = ο κόσμος των Ρωμαίων: %s, η ομίχλη ίδια: %s'
           % (f, tc_h, tab[0], good, seen1 == seen0))

    # ----------------------------------------------------- 7. αποθήκευση
    g = M4.Game.__new__(M4.Game)        # (τα βοηθητικά του M4 στο ίδιο CPC)
    g.c, g.sym, g.shots, g.times, g.scrolled, g.ok = c, sym, False, [], [], \
        True
    M6.click_unit(g, 3)                 # ένας από τους 3 χωρικούς
    M6.command(g, (36, 52))
    for _ in range(5):
        M3.tick_time(c, sym)
    t_save = wait_save(c, sym)
    data = DK.Dsk.__new__(DK.Dsk)
    data.d, data.ntracks = bytearray(c.disc_image()), 42
    saved_dsk = os.path.join(D, 'm12_saved.dsk')
    open(saved_dsk, 'wb').write(data.d)
    blob = DK.Dsk(saved_dsk).get('SAVE.BIN')
    diffs = compare(c, sym, blob)
    screen_a = M2.decode_scrolled(c, sym)
    report('ΑΠΟΘΗΚΕΥΣΗ', blob.startswith(SIG) and
           not any(diffs.values()),
           'V: το SAVE.BIN αρχίζει με %s· διαφορές με τη μνήμη: %s'
           % (blob[:len(SIG)], {k: len(v) if k != 'κύρια' else
                                names(sym, v) for k, v in diffs.items()}))

    # ------------------------------------------------------- 8. φόρτωμα
    b = boot(saved_dsk, [CP.KEY_UP])
    b.key_down(CP.KEY_RETURN)
    b.run_frames(4)
    b.key_up(CP.KEY_RETURN)
    for t_load in range(4, 3000):
        b.run_frames(1)
        if b.peek(sym['PHASE']) == 2:
            break
    diffs = compare(b, sym, blob)
    tc_hb = b.peek(sym['BLD_TYPES'] + 9)
    screen_b = M2.decode_scrolled(b, sym)
    same = screen_a == screen_b
    if shots:
        b.screenshot(os.path.join(D, 'm12_loaded.png'), aspect=True)
    report('ΦΟΡΤΩΣΗ', not any(diffs.values()) and tc_hb == tab[0] and same,
           'reset, RUN"POLIS, ΦΟΡΤΩΣΗ: διαφορές με το αρχείο %s· Κέντρο '
           'Πόλης ύψους %d· η οθόνη ίδια με μετά την αποθήκευση: %s'
           % ({k: names(sym, v[:4]) if k == 'κύρια' else len(v)
               for k, v in diffs.items() if v},
              tc_hb, same))

    # ------------------------------------------------------ 9. συνέχεια
    M.wait_phase(c, sym, 6, limit_ms=4000)
    M.wait_phase(b, sym, 6, limit_ms=4000)
    # στο ΙΔΙΟ καρέ του παιχνιδιού: το ticks (ένα ανά VSYNC του κύριου
    # βρόχου) ίδιο, και το καρέ μονάδων του τελειωμένο
    t = (max(c.peek(sym['TICKS']), b.peek(sym['TICKS'])) + 2) & 0xFE
    for _ in range(100):
        for e in (c, b):
            advance(e, sym, t)
        t = (t + 2) & 255
    pa, pb = units_pos(c), units_pos(b)
    same_n = sum(1 for x, y in zip(pa, pb) if x == y)
    report('ΣΥΝΕΧΕΙΑ', same_n == len(pa),
           'μετά από 100 καρέ μονάδων: %d από %d μονάδες στην ίδια θέση'
           % (same_n, len(pa)))

    # ------------------------------------------------ 10. καμία παρτίδα
    n = boot(dsk_path, [CP.KEY_UP, CP.KEY_RETURN])
    M.wait_phase(n, sym, 6, limit_ms=60000)
    vals = M6.hud_vals(n, sym)
    report('ΚΑΜΙΑ', vals[:4] == [200, 200, 100, 200] and
           n.read_ram(sym['AGE3_NAME'], 5) == b'AGE3G',
           'καθαρή δισκέτα, ΦΟΡΤΩΣΗ: νέο παιχνίδι, πόροι %s' % vals[:4])

    print('ΧΡΟΝΟΣ     μέτρηση   αποθήκευση %.1f s (το V ως την οθόνη)· '
          'φόρτωμα %.1f s (το RETURN ως την οθόνη, με τις εικόνες της '
          'Χαλκού)' % (t_save / 50.0, t_load / 50.0))


def main():
    sound()
    disk()
    print('M12', 'OK' if ok else 'ΑΠΟΤΥΧΙΑ')
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
