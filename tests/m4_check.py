"""M4: 128 μονάδες, κέρσορας, επιλογή, εντολή κίνησης — σε headless CPC 6128.

    python3 tests/m4_check.py [--shots]

Με τα πλήκτρα του παίκτη (Q A O P, SPACE, RETURN):

1. ΚΟΥΤΙ. Ο κέρσορας πάει πάνω-αριστερά από 6 μονάδες της πόλης, το SPACE
   κρατιέται όσο σέρνεται ως κάτω-δεξιά τους, και αφήνεται: επιλεγμένες
   πρέπει να είναι ΑΚΡΙΒΩΣ αυτές οι 6.
2. ΕΝΤΟΛΗ. Ο κέρσορας αλλού, RETURN: οι 6 περπατάνε, φτάνουν και
   ΣΤΑΜΑΤΑΝΕ ακριβώς στις θέσεις του σχηματισμού, με την όψη του τελευταίου
   τους βήματος (όπως το παρατηρεί ο έλεγχος καρέ προς καρέ).
3. ΟΙ ΑΛΛΕΣ. Στο ίδιο διάστημα, ≥ 85% όσων περιπλανιούνται (56 από το M10· οι 12
   τελευταίες θέσεις είναι ελεύθερες από το M7) έχουν κινηθεί εκτός οθόνης.
4. ΧΡΟΝΟΣ. Κάθε καρέ μονάδων όσο γίνονται όλα αυτά < 40 ms.
5. ΣΥΝΘΕΣΗ. Ανάμεσα σε καρέ, η οθόνη είναι pixel προς pixel το φόντο με
   τις μονάδες του ORDER, τις αγκύλες των επιλεγμένων και τον κέρσορα· και
   μετά το σβήσιμο, ξανά ακριβώς το φόντο.
6. ΚΛΙΚ. Πάτημα και άφημα πάνω σε μια μονάδα: επιλεγμένη μόνο αυτή.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import m1_check as M                            # noqa: E402
import m2_check as M2                           # noqa: E402
import m3_check as M3                           # noqa: E402
import scene as S                               # noqa: E402
import cpc as CPCMOD                            # noqa: E402
from cpc import CPC                             # noqa: E402

CUR_DX, CUR_DY = 2, 6


class Game:
    def __init__(self, shots, ai=False, fog=False):
        self.shots = shots
        self.sym = M.symbols()
        grd, res = M.mockup.make_map()
        self.world = M.game_world(grd, res)
        self.c = CPC()
        self.c.run_frames(5)
        assert self.c.quickload(os.path.join(M.BUILD, 'polis.sna'))
        if not ai:                      # ο αντίπαλος (M10) δεν σκέφτεται: οι
            self.c.poke(self.sym['AI_ON'], 0)   # έλεγχοι M4-M9 μόνοι τους
        if not fog:                     # και χωρίς ομίχλη (M11): όλα
            self.c.poke(self.sym['FOG_ON'], 0)  # εξερευνημένα
        M.wait_phase(self.c, self.sym, 6)
        self.times = []
        self.scrolled = []              # κύλησε η κάμερα σε εκείνο το καρέ;
        self.ok = True

    def tick(self, n=1):
        for _ in range(n):
            cam = M2.cam(self.c, self.sym)
            self.times.append(M3.tick_time(self.c, self.sym))
            self.scrolled.append(M2.cam(self.c, self.sym) != cam)

    def hold(self, keys, n):
        for k in keys:
            self.c.key_down(k)
        self.tick(n)
        for k in keys:
            self.c.key_up(k)
        self.tick(1)

    def cursor(self):
        return self.c.peek(self.sym['CUR_X']), self.c.peek(self.sym['CUR_Y'])

    def move_cursor(self, x, y):
        """Κρατάει το πλήκτρο ώσπου ο κέρσορας να φτάσει (το καρέ που διαβάζει
        τα πλήκτρα δεν είναι συγχρονισμένο με το πάτημα: μετράμε τη θέση)."""
        for axis, want, keys in ((0, x, 'op'), (1, y, 'qa')):
            while self.cursor()[axis] != want:
                k = keys[1] if want > self.cursor()[axis] else keys[0]
                self.c.key_down(k)
                n = 0
                while (self.cursor()[axis] < want) == (k == keys[1]) \
                        and self.cursor()[axis] != want:
                    self.tick(1)
                    n += 1
                    assert n < 200, 'ο κέρσορας δεν φτάνει στο %d' % want
                self.c.key_up(k)
                self.tick(1)
        assert self.cursor() == (x, y), (self.cursor(), (x, y))

    def report(self, name, good, what):
        print('%-8s %-9s %s' % (name, 'OK' if good else 'ΑΠΟΤΥΧΙΑ', what))
        self.ok &= bool(good)

    def compose(self, name):
        cx, cy = M2.cam(self.c, self.sym)
        exp = S.expected(self.c, self.sym, M.reference(self.world, cx, cy))
        return M2.diff(M2.decode_scrolled(self.c, self.sym), exp, name,
                       self.c, self.shots)


def face_of(gx, gy):
    """Ο κανόνας της όψης του Z80 (set_face) για ένα βήμα (gx, gy)."""
    sx = (gx > 0) - (gx < 0)
    if gy > 0:
        return 1 if sx == 1 else 0
    if gy < 0:
        return 3 if sx == -1 else 2
    return 1 if sx == 1 else 3


def main():
    g = Game('--shots' in sys.argv)
    c, sym = g.c, g.sym
    g.report('αρχή', g.compose('start'), 'οι 12 της πόλης και ο κέρσορας')

    # ------------------------------------------------------ 1. κουτί
    # Οι στήλες της πόλης στο SX 8, 24, 40, 56, οι σειρές στο SY 27, 59, 91·
    # τα πόδια στο (SX + 2, SY + 14). Το κουτί (8,40)-(44,76) πιάνει τις 3
    # πρώτες στήλες των 2 πρώτων σειρών.
    g.move_cursor(8, 40)
    c.key_down(' ')
    g.tick(2)
    g.move_cursor(44, 76)
    g.report('γωνία', g.compose('box'), 'το κουτί σέρνεται: η γωνία φαίνεται')
    c.key_up(' ')
    g.tick(2)
    want = {0, 1, 2, 4, 5, 6}
    sel = {u['idx'] for u in S.units(c) if u['fl'] & S.F_SEL}
    g.report('κουτί', sel == want, 'επιλεγμένες %s' % sorted(sel))
    g.report('αγκύλες', g.compose('selected'), 'οι 6 με αγκύλες')

    # ------------------------------------------------------ 2. εντολή
    before = S.units(c)
    g.move_cursor(60, 112)
    c.key_down(CPCMOD.KEY_RETURN)
    g.tick(1)
    c.key_up(CPCMOD.KEY_RETURN)
    g.tick(1)
    us = S.units(c)
    targets = {i: (us[i]['tx'], us[i]['ty']) for i in want}
    moving = [i for i in want if us[i]['fl'] & S.F_MOVE]
    g.report('εντολή', len(moving) == 6,
             '%d περπατάνε προς %s' % (len(moving), sorted(targets.values())))
    # Από M5 ο δρόμος περνάει από τα περάσματα των κελιών: η όψη που
    # περιμένουμε είναι αυτή του ΤΕΛΕΥΤΑΙΟΥ βήματος που παρατηρήθηκε.
    pos = {i: (us[i]['wx'], us[i]['wy']) for i in want}
    faces = {i: us[i]['face'] for i in want}
    for k in range(300):
        g.tick(1)
        for i in want:
            u = S.unit(c, i)
            p = (u['wx'], u['wy'])
            if p != pos[i]:
                faces[i] = face_of(p[0] - pos[i][0], p[1] - pos[i][1])
                pos[i] = p
        if k == 10:
            g.report('σύνθεση', g.compose('walking'), 'ενώ περπατάνε')
        if not any(S.unit(c, i)['fl'] & S.F_MOVE for i in want):
            break
    us = S.units(c)
    arrived = all((us[i]['wx'], us[i]['wy']) == targets[i] for i in want)
    g.report('έφτασαν', arrived and not any(us[i]['fl'] & S.F_MOVE
                                            for i in want),
             'σε %d καρέ, στις θέσεις του σχηματισμού' % (k + 1))
    got = {i: S.FACES[us[i]['face']] for i in want}
    exp = {i: S.FACES[faces[i]] for i in want}
    g.report('όψη', got == exp, 'στάθηκαν με όψη %s, του τελευταίου βήματος'
             % ''.join(got[i] for i in sorted(want)))
    g.report('στάση', all(us[i]['step'] == 0 for i in want),
             'καρέ στάσης (βήμα 0)')
    others = [i for i in range(12, S.UNITS)
              if (us[i]['wx'], us[i]['wy']) != (before[i]['wx'],
                                                before[i]['wy'])]
    offscreen = [i for i in others if us[i]['sy'] == 255]
    wander = [i for i in range(12, S.UNITS) if us[i]['fl'] & S.F_WANDER]
    g.report('οι άλλες', len(offscreen) >= 0.85 * len(wander),
             '%d από τις %d που περιπλανιούνται κινήθηκαν εκτός οθόνης στο '
             'ίδιο διάστημα' % (len(offscreen), len(wander)))
    g.report('σύνθεση', g.compose('arrived'), 'μετά την άφιξη')

    # ------------------------------------------------------ 6. κλικ
    u3 = S.unit(c, 3)                   # δεν ήταν στο κουτί: SX 56, SY 27
    g.move_cursor(u3['sx'] + 2, u3['sy'] + 2 - (u3['sy'] + 2 - 112) % 6)
    c.key_down(' ')
    g.tick(2)
    c.key_up(' ')
    g.tick(2)
    sel = {u['idx'] for u in S.units(c) if u['fl'] & S.F_SEL}
    g.report('κλικ', sel == {3}, 'επιλεγμένη %s' % sorted(sel))

    # ------------------------------------------------ 4./5. χρόνος, σβήσιμο
    tmax = max(g.times)
    g.report('χρόνος', tmax < 40, 'καρέ μονάδων: μέσος %.1f ms, μέγιστος '
             '%.1f ms (όριο 40), %d καρέ'
             % (sum(g.times) / len(g.times), tmax, len(g.times)))
    c.poke(sym['ERASE_REQ'], 1)
    M3.wait_uphase(c, sym, 3)
    M3.wait_uphase(c, sym, 4)
    cx, cy = M2.cam(c, sym)
    g.report('σβήσιμο', M2.diff(M2.decode_scrolled(c, sym),
                                M.reference(g.world, cx, cy), 'erased', c,
                                g.shots),
             'η οθόνη είναι ξανά ακριβώς το φόντο')
    sys.exit(0 if g.ok else 1)


if __name__ == '__main__':
    main()
