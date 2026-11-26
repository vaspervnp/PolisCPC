"""Η δουλειά του χωρικού στην κορυφή του χάρτη (2026-11-26, game/jobmsg.asm)
— σε headless CPC 6128.

    python3 tests/m6_jobmsg_check.py

Με τα πλήκτρα του παίκτη (SPACE, RETURN, τα μενού):

1. ΞΥΛΟ. Ένας χωρικός, RETURN σε δέντρο: στις 8 πρώτες γραμμές του χάρτη
   το «CHOP WOOD», κεντραρισμένο, γράμμα προς γράμμα με τη γραμματοσειρά
   (src/make_ui.py), σε κουτί· πουθενά αλλού το μελάνι του. Γράφεται σαν
   γραφομηχανή: το κουτί, και ένα γράμμα σε κάθε καρέ μονάδων.
2. ΤΕΛΟΣ. Μετά από JM_T (50) καρέ μονάδων, 2 s, η λωρίδα ξαναγίνεται ο
   χάρτης: ίδια με πριν από την εντολή (η κάμερα δεν κουνήθηκε).
3. ΤΡΟΦΗ, ΧΡΥΣΟΣ. «GATHER FOOD» στους θάμνους, «MINE GOLD» στον χρυσό.
4. ΚΟΥΜΠΙΑ. Με τη δουλειά στη λωρίδα, ο κέρσορας στα κουμπιά: η ετικέτα του
   κουμπιού (όπως πάντα)· και πίσω στον χάρτη η δουλειά, όσο μένει χρόνος.
5. ΧΤΙΣΙΜΟ. BUILD, HOUSE, RETURN: «BUILD».
6. ΚΥΛΙΣΗ. Με τη δουλειά στη λωρίδα η κάμερα κάτω και πάλι πάνω (η κύλιση
   του CRTC παίρνει τη λωρίδα μαζί της): η δουλειά σβήνει αμέσως, μία
   γραμμή ανά καρέ εκεί που βρίσκεται, και στο τέλος η οθόνη = ο κόσμος
   του mockup με τις μονάδες από πάνω.
7. ΧΡΟΝΟΣ. Κανένα καρέ χωρίς κύλιση πάνω από 40 ms, ούτε όσο φαίνεται η
   δουλειά ούτε όταν σβήνει.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import ui_menu as UM                            # noqa: E402
import cpc as CPCMOD                            # noqa: E402
import make_ui as MU                            # noqa: E402

JM_T = 50
JM_N = 11                       # το κουτί: τα γράμματα του μεγαλύτερου
HOUSE = (27, 63)


def strip(c, sym):
    return M4.M2.decode_scrolled(c, sym)[:8]


def text_ok(c, sym, text):
    """Η λωρίδα: το κείμενο στη μέση, γράμμα προς γράμμα (6 pixels ανά
    γράμμα, 1 bit ανά pixel, ui_glyph), σε κουτί (JM_N γράμματα) που έξω από
    τα κελιά του είναι μόνο φόντο."""
    rows = strip(c, sym)
    n = len(text)
    x0 = (80 - 3 * n) // 2 * 2
    x1 = x0 + 6 * n
    bg = rows[7][x0]
    ink = {rows[y][x] for y in range(7) for x in range(x0, x1)} - {bg}
    if len(ink) != 1:
        return False
    ink = ink.pop()
    for k, ch in enumerate(text):
        for y, row in enumerate(MU.GLYPHS[ch]):
            bits = row + '.'
            for i in range(6):
                want = ink if bits[i] == '#' else bg
                if rows[y][x0 + 6 * k + i] != want:
                    return False
    if any(rows[7][x] != bg for x in range(x0, x1)):
        return False
    b0 = 2 * ((80 - 3 * JM_N) // 2)             # το κουτί (jobmsg.asm): έξω
    b1 = b0 + 2 * (3 * JM_N + 1)                # του ο χάρτης
    return all(rows[y][x] == bg for y in range(8) for x in range(b0, b1)
               if not x0 <= x < x1)


def typed(g):
    """Ως να γραφτεί όλη (το κουτί, και ένα γράμμα ανά καρέ μονάδων):
    -> πόσα καρέ."""
    c, sym = g.c, g.sym
    for n in range(30):
        if c.peek(sym['JM_T']) < JM_T - 2 and c.peek(sym['JM_S']) == 0:
            return n
        g.tick(1)
    return None


def main():
    g = M4.Game(False)
    c, sym = g.c, g.sym
    jm_t, jm_k = sym['JM_T'], sym['JM_K']
    g.tick(3)
    before = strip(c, sym)

    # 1. ξύλο
    sel = M6.click_unit(g, 6)
    M6.command(g, M6.TREE)
    nt = typed(g)
    t0, k0 = c.peek(jm_t), c.peek(jm_k)
    g.report('ξύλο', sel == {6} and k0 == 0x11 and nt is not None and nt <= 14
             and text_ok(c, sym, 'CHOP WOOD'),
             'χωρικός 6 στο δέντρο: δουλειά #%02X, γραμμένη σε %s καρέ (%d '
             'ακόμα), «CHOP WOOD» στη λωρίδα' % (k0, nt, t0))

    # 2. τέλος
    n = nt
    while c.peek(jm_t) and n < 80:
        g.tick(1)
        n += 1
    g.tick(2)
    g.report('τέλος', JM_T - 8 <= n + 4 <= JM_T + 2 and strip(c, sym) == before,
             'σβήνει μετά από %d καρέ: η λωρίδα ξανά ο χάρτης' % (n + 4))

    # 3. τροφή, χρυσός
    M6.click_unit(g, 0)
    M6.command(g, M6.BERRIES)
    typed(g)
    food = c.peek(jm_k) == 0x10 and text_ok(c, sym, 'GATHER FOOD')
    c.key_down(CPCMOD.KEY_RIGHT)            # ο χρυσός είναι δεξιά της οθόνης
    while M4.M2.cam(c, sym)[0] < 114:
        g.tick(1)
    c.key_up(CPCMOD.KEY_RIGHT)
    g.tick(2)
    M6.click_unit(g, 9)
    M6.command(g, M6.GOLD)
    typed(g)
    gold = c.peek(jm_k) == 0x12 and text_ok(c, sym, 'MINE GOLD')
    g.report('τροφή', food and gold, '«GATHER FOOD» στους θάμνους %s, '
             '«MINE GOLD» στον χρυσό %s' % (food, gold))

    # 4. κουμπιά: η ετικέτα τους έχει προτεραιότητα, και μετά πάλι η δουλειά
    UM.hud_enter(c)
    g.tick(2)
    import m20_check as M20
    lab = M20.label_ok(c, sym, UM.slots(c)[UM.rb(c, UM.U['HB_I'])])
    UM.hud_leave(c)
    typed(g)
    left = c.peek(jm_t)
    back = text_ok(c, sym, 'MINE GOLD') if left else None
    g.report('κουμπιά', lab and back is not False,
             'στα κουμπιά η ετικέτα τους %s· πίσω στον χάρτη (%d καρέ ακόμα) '
             'η δουλειά %s' % (lab, left, back))
    while c.peek(jm_t):
        g.tick(1)
    g.tick(2)

    # 5. χτίσιμο
    c.key_down(CPCMOD.KEY_LEFT)
    while M4.M2.cam(c, sym)[0] > 98:
        g.tick(1)
    c.key_up(CPCMOD.KEY_LEFT)
    g.tick(2)
    M6.click_unit(g, 3)
    UM.build(c, 'house')
    g.move_cursor(*M6.tile_cursor(g, *HOUSE))
    c.key_down(CPCMOD.KEY_RETURN)
    g.tick(1)
    c.key_up(CPCMOD.KEY_RETURN)
    typed(g)
    g.report('χτίσιμο', c.peek(jm_k) == 0x14 and text_ok(c, sym, 'BUILD'),
             'BUILD, HOUSE: δουλειά #%02X, «BUILD» στη λωρίδα'
             % c.peek(jm_k))

    # 6. κύλιση
    g2 = M4.Game(False)
    c2, s2 = g2.c, g2.sym
    g2.tick(3)
    M6.click_unit(g2, 6)
    M6.command(g2, M6.TREE)
    g2.tick(3)
    shown = c2.peek(s2['JM_T'])
    for key in (CPCMOD.KEY_DOWN, CPCMOD.KEY_UP):
        c2.key_down(key)
        g2.tick(4)
        c2.key_up(key)
        g2.tick(2)
    left = c2.peek(s2['JM_T'])
    g2.tick(10)
    grd, res = M4.M.mockup.make_map()
    g2.world = M4.M.game_world(grd, res)
    g.report('κύλιση', shown > 40 and left == 0 and g2.compose('jobmsg_scroll'),
             'κάτω και πάνω με τη δουλειά (%d καρέ): σβήστηκε (%d) και η οθόνη '
             '= ο κόσμος με τις μονάδες' % (shown, left))

    # 7. χρόνος (τα καρέ με κύλιση: μέτρηση, βλ. M2)
    t = [ms for ms, sc in zip(g.times, g.scrolled) if not sc]
    g.report('χρόνος', max(t) < 40, 'καρέ χωρίς κύλιση: μέσος %.1f ms, '
             'μέγιστος %.1f ms (όριο 40), %d καρέ' % (sum(t) / len(t), max(t), len(t)))

    print('\nΔΟΥΛΕΙΑ: %s' % ('OK' if g.ok else 'ΑΠΟΤΥΧΙΑ'))
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
