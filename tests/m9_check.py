"""M9: εποχές και τεχνολογίες — σε headless CPC 6128, με τη δισκέτα μέσα.

    python3 tests/m9_check.py [--shots]

1. ΔΕΝΤΡΟ. Στην Εποχή Εργαλείων ο ναός (N), το κυβερνείο (K) και η ακαδημία
   (D) δεν τοποθετούνται.
2. ΚΤΙΡΙΑ. Οι χωρικοί χτίζουν χωράφι και σπίτι δίπλα στο Κέντρο Πόλης (η
   αγορά, που θέλει το χωράφι, και ο στάβλος της ακαδημίας: εγγραφές έξω
   από τον χάρτη, όπως στο M7).
3. ΕΡΕΥΝΑ. Κλικ στο Κέντρο Πόλης, U: 800 τροφή, και η μπάρα της κάρτας
   γεμίζει. Ξανά U: τίποτα (ερευνά ήδη).
4. ΕΠΟΧΗ. Στο τέλος: το AGE3.BIN από τη δισκέτα (game/disk.asm) στην C6, η
   εποχή 3 στη μπάρα, ύψος και εικόνα της Χαλκού στο bld_types και στα
   κτίρια. Ξαναζωγραφίζονται ΜΟΝΟ όσα άλλαξαν (Κέντρο Πόλης, σπίτι), ένα-ένα
   — όχι το χωράφι (ίδια εικόνα). Η οθόνη μετά = ο κόσμος με τις εικόνες
   της Χαλκού, pixel προς pixel.
5. ΞΕΚΛΕΙΔΩΜΑ. N, K, D ανοίγουν τοποθέτηση.
6. ΤΕΧΝΟΛΟΓΙΕΣ. U στη σιταποθήκη (Εξημέρωση: ο χωρικός κουβαλάει 15
   τροφή) και στην αποθήκη (Εργαλειοποιία: ζημιά σπαθοφόρου 8 -> 10, μόνο
   της ομάδας 0) — ο πίνακας stats διαβάζεται από την C7 στο τέλος.
7. ΧΡΟΝΟΣ. Τυπώνεται ως μέτρηση (όπως στο M3 και στο M8): τα καρέ χωρίς
   κύλιση, το καρέ του φορτώματος (~0,7 s) και τα ~17 της επανασχεδίασης της
   εποχής.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import make_bank6 as MB                         # noqa: E402
import m3_check as M3                           # noqa: E402
import m8_check as M8                           # noqa: E402

M3.wait_uphase.__defaults__ = (10000,)          # το καρέ του φορτώματος: ~1-2 s

FARM = (37, 61)                 # το κέντρο της κάτοψης 3 x 3 (όπως ο στρατώνας του M7)
HOUSE = (31, 72)                # 2 x 2 (όπως η αποθήκη του M7)
DUMP = 0xA8C0                   # 64 bytes ελεύθερα (μετά το MOVERS)
B_H, B_IMG = 11, 12


def word(c, a):
    return c.peek(a) | c.peek(a + 1) << 8


def set_res(c, sym, v):
    for k in range(4):
        c.poke(sym['HUD_VAL'] + 2 * k, v & 255)
        c.poke(sym['HUD_VAL'] + 2 * k + 1, v >> 8)
    c.poke(sym['HUD_DIRTY'], c.peek(sym['HUD_DIRTY']) | 15)


def try_key(g, key):
    """Το πλήκτρο ενός τύπου: ο τύπος που ανοίγει τοποθέτηση (ή 255), και ESC."""
    M7.press(g, key)
    m = g.c.peek(g.sym['BMODE'])
    M7.press(g, CPCMOD.KEY_ESC)
    return m


def build(g, key, tile, typ):
    """Τοποθέτηση με τους επιλεγμένους χωρικούς, και αναμονή ως το τέλος."""
    c, sym = g.c, g.sym
    M7.press(g, key)
    g.move_cursor(*M6.tile_cursor(g, *tile))
    M7.press(g, CPCMOD.KEY_RETURN, 1)
    b = [b for b in M7.blds(c) if b['type'] == typ]
    assert b, 'δεν τοποθετήθηκε %s' % typ
    for k in range(2000):
        g.tick(1)
        if M7.blds(c)[[x['slot'] for x in M7.blds(c)].index(b[0]['slot'])][
                'st'] == 1 and c.peek(sym['RQ_N']) == 255:
            break
    return b[0], k


def click_bld(g, tile):
    g.move_cursor(*M6.tile_cursor(g, *tile))
    g.c.key_down(' ')
    g.tick(2)
    g.c.key_up(' ')
    g.tick(2)
    return g.c.peek(g.sym['SEL_BLD'])


def c7_read(c, sym, addr, n):
    """n bytes της C7 (στο τέλος του ελέγχου: ο Z80 μένει σε βρόχο)."""
    code = bytes([0xF3, 0x01, 0xC7, 0x7F, 0xED, 0x49,
                  0x21, addr & 255, addr >> 8, 0x11, (DUMP + 32) & 255,
                  (DUMP + 32) >> 8, 0x01, n, 0, 0xED, 0xB0, 0x18, 0xFE])
    c.run_code(DUMP, code, 2)
    return c.read_ram(DUMP + 32, n)


def main():
    g = M4.Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    c.insert_disc(os.path.join(M4.M.BUILD, 'polis.dsk'))
    g.tick(3)
    grd, res = M4.M.mockup.make_map()
    set_res(c, sym, 3000)
    for slot, typ in ((1, 'market'), (2, 'stable'), (3, 'granary'),
                      (4, 'storage_pit')):         # (χαμηλές θέσεις: bld_top)
        M7.fake_bld(c, sym, slot, typ)
    c.poke(sym['BQ_TOT'], 0)

    # ------------------------------------------------- 1. δέντρο
    g.move_cursor(8, 40)                    # κουτί γύρω από τους 12 της πόλης
    c.key_down(' ')
    g.tick(2)
    g.move_cursor(60, 106)
    c.key_up(' ')
    g.tick(2)
    locked = [try_key(g, k) for k in 'nkd']
    g.report('δέντρο', locked == [255] * 3, 'στην Εποχή Εργαλείων: N K D -> %s'
             % locked)

    # ------------------------------------------------- 2. χωράφι, σπίτι
    farm, kf = build(g, 'f', FARM, 'farm')
    house, kh = build(g, 'h', HOUSE, 'house')
    g.tick(20)
    g.report('κτίρια', True, 'χωράφι στο (%d, %d) σε %d καρέ, σπίτι στο '
             '(%d, %d) σε %d' % (farm['i0'], farm['j0'], kf, house['i0'],
                                 house['j0'], kh))

    # ------------------------------------------------- 3. έρευνα
    tc = click_bld(g, (32, 60))
    v0 = M6.hud_vals(c, sym)
    M7.press(g, 'u')
    v1 = M6.hud_vals(c, sym)
    M7.press(g, 'u')
    v2 = M6.hud_vals(c, sym)
    bars = []
    t0 = len(g.times)
    loaded = None
    redrawn = []
    busy = False
    redraw = []                             # τα καρέ της επανασχεδίασης
    for k in range(1600):
        g.tick(1)
        if loaded is not None:
            redraw.append(len(g.times) - 1)
        if k % 100 == 50:
            bars.append(M7.card(c)[1])
        if loaded is None and word(c, sym['HUD_VAL'] + 10) == 3:
            loaded = k
        if loaded is not None:              # κάθε νέα τιμή του age_q: το
            q = c.peek(sym['AGE_Q'])        # κτίριο q - 1 μόλις ξεκίνησε
            if q != busy and q not in (0, 255):
                redrawn.append(q - 1)
            busy = q
            if c.peek(sym['AGE_Q']) == 255 and c.peek(sym['RQ_N']) == 255:
                break
    g.report('έρευνα', tc == 0 and v1[0] == v0[0] - 800 and v2 == v1 and
             bars[:3] == sorted(bars[:3]) and bars[0] is not None,
             'κλικ στο Κέντρο Πόλης (θέση %s), U: τροφή %d -> %d· ξανά U: %s· '
             'η μπάρα %s' % (tc, v0[0], v1[0], 'τίποτα' if v2 == v1 else v2,
                            bars))

    # ------------------------------------------------- 4. εποχή
    bs = {b['type']: b for b in M7.blds(c)}
    a3 = MB.age_images(3)
    a2 = MB.age_images(2)
    tab_ok = True
    rec_ok = True
    off = 0
    addr = {}
    for key, *_ in MB.TYPES:
        addr[key] = MB.IMG0 + off
        off += len(MB.encode(a3[key]))
    for k, (key, *_) in enumerate(MB.TYPES):
        row = sym['BLD_TYPES'] + k * 18
        tab_ok &= c.peek(row + 9) == len(a3[key]) and \
            word(c, row + 16) == addr[key]
    for b in M7.blds(c):
        r = M7.BLD_SLOTS[b['slot']]
        rec_ok &= c.peek(r + B_H) == len(a3[b['type']]) and \
            word(c, r + B_IMG) == addr[b['type']]
    slots = {k: bs[k]['slot'] for k in ('town_center', 'house', 'farm')}
    changed = sorted(k for k in slots if a3[k] != a2[k])
    who = sorted(k for k in slots if slots[k] in redrawn)
    g.report('εποχή', loaded is not None and tab_ok and rec_ok and
             M6.hud_vals(c, sym)[5] == 3,
             'σε %s καρέ από το U: το AGE3.BIN φορτώθηκε, εποχή %d, ύψος και '
             'εικόνα της Χαλκού στους %d τύπους και σε όλα τα κτίρια: %s'
             % (loaded, M6.hud_vals(c, sym)[5], len(MB.TYPES),
                tab_ok and rec_ok))
    g.report('μόνο όσα', who == changed and 'farm' not in who,
             'άλλαξαν εικόνα %s· ξαναζωγραφίστηκαν %s, ένα-ένα (όχι το '
             'χωράφι)' % (changed, who))
    g.tick(2)
    blist = M4.M.GAME_BLDS + [('farm', farm['i0'], farm['j0']),
                              ('house', house['i0'], house['j0'])]
    g.world = M4.M.game_world(grd, res, blds=blist, age=3, found=[
        ('farm', farm['i0'], farm['j0']), ('house', house['i0'], house['j0'])])
    g.report('σύνθεση', g.compose('bronze'), 'η οθόνη με τις εικόνες της '
             'Χαλκού (Κέντρο Πόλης, σπίτι) και το ίδιο χωράφι')

    # ------------------------------------------------- 5. ξεκλείδωμα
    M8.click(g, S.unit(c, 0))               # ένας χωρικός ξανά (το κλικ στο
    open3 = [try_key(g, k) for k in 'nkd']
    want = [MB.KEYS.index(k) for k in ('temple', 'gov_center', 'academy')]
    g.report('ξεκλείδωμα', open3 == want, 'στη Χαλκού: N K D -> %s (ναός, '
             'κυβερνείο, ακαδημία)' % open3)

    # ------------------------------------------------- 6. τεχνολογίες
    v0 = M6.hud_vals(c, sym)
    for slot in (3, 4):                     # σιταποθήκη, αποθήκη
        c.poke(sym['SEL_BLD'], slot)
        M7.press(g, 'u')
    v1 = M6.hud_vals(c, sym)
    for k in range(800):
        g.tick(1)
        if c.peek(sym['RES_N']) == 0:
            break
    cm = list(c.read_ram(sym['CARRY_MAX'], 4))
    il = t0 + loaded if loaded is not None else -1
    skip = set(redraw) | {il}
    times = [t for i, (t, m) in enumerate(zip(g.times, g.scrolled))
             if not m and i not in skip]
    rd = [g.times[i] for i in redraw]
    load_t = g.times[il] if il >= 0 else 0
    st = c7_read(c, sym, sym['STATS'], 32)
    g.report('τεχνολογίες', v1[0] == v0[0] - 300 and v1[1] == v0[1] - 50 and
             cm == [15, 10, 10, 10] and st[5] == 10 and st[16 + 5] == 8,
             'U στη σιταποθήκη και στην αποθήκη: τροφή %d -> %d, ξύλο %d -> %d· '
             'σε %d καρέ: φορτίο %s, ζημιά σπαθοφόρου %d (εχθρού %d)'
             % (v0[0], v1[0], v0[1], v1[1], k + 1, cm, st[5], st[16 + 5]))
    over = [t for t in times if t >= 40]
    slow = [(i - il, round(t, 1)) for i, (t, m) in
            enumerate(zip(g.times, g.scrolled)) if not m and i not in skip
            and t >= 40]
    print('%-8s %-9s καρέ χωρίς κύλιση: μέσος %.1f ms, μέγιστος %.1f ms, %d '
          'από τα %d πάνω από 40%s' % ('χρόνος', '<40' if not over else
                                       'ΠΑΝΩ', sum(times) / len(times),
                                       max(times), len(over), len(times),
                                       '' if not slow else ' (καρέ από το '
                                       'φόρτωμα, ms: %s — η τοποθέτηση του '
                                       'χωραφιού και το κλικ στο Κέντρο '
                                       'Πόλης)' % slow))
    print('%-8s %-9s το καρέ του φορτώματος %.0f ms· η επανασχεδίαση της '
          'εποχής: %d καρέ, μέσος %.1f, μέγιστος %.1f ms, %d πάνω από 40'
          % ('εποχή', 'μέτρηση', load_t, len(rd), sum(rd) / max(1, len(rd)),
             max(rd or [0]), len([t for t in rd if t >= 40])))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
