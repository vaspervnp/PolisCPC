"""Η μουσική του Polis (M21) -> data/music_menu.asm, data/music_game.asm.

Δύο τραγούδια, δύο φωνές το καθένα: μελωδία (κανάλι A, μία οκτάβα
ψηλότερα) και μπάσο (B). Η μορφή τους είναι του game/sound.asm (mus_tick):
ένα byte ανά νότα, διάρκεια στα bits 7-5 (1 2 3 4 6 8 12 16 όγδοα) και
τόνος στα 4-0 (0 παύση, 1-30 ημιτόνια από το E2, 31 = πάλι από την αρχή).

    mus_menu   το μενού έναρξης: ήρεμο, σε ρε ελάσσονα, σαν λύρα
    mus_game   το παιχνίδι: πιο αραιό, σε λα ελάσσονα με δωρικό χρώμα,
               16 μέτρα ώστε να μην κουράζει

Οι νότες γράφονται ως «όνομα+οκτάβα:διάρκεια» (D5:2 = ρε5, ένα τέταρτο).
Οι οκτάβες είναι οι πραγματικές: το A ακούγεται όπως είναι γραμμένο (ο
κώδικας το ανεβάζει μία οκτάβα, εδώ κατεβαίνει μία), το B επίσης.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'data', '%s.asm')     # music_menu, music_game

DUR = [1, 2, 3, 4, 6, 8, 12, 16]
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7,
         'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
BASE = 4 + 12 * 2                       # E2


def semis(note):
    name, octv = note[:-1], int(note[-1])
    return NAMES[name] + 12 * octv


def voice(text, octave_up):
    out = []
    for tok in text.split():
        n, d = tok.split(':')
        d = int(d)
        while d:                        # ό,τι δεν είναι στον πίνακα: σε κομμάτια
            step = max(x for x in DUR if x <= d)
            code = DUR.index(step)
            if n == 'r':
                p = 0
            else:
                p = semis(n) - 12 * octave_up - BASE + 1
                assert 1 <= p <= 30, (tok, p)
            out.append(code << 5 | p)
            d -= step
            if n != 'r' and d:          # η νότα δεν ξαναχτυπάει: παύση
                n = 'r'
    out.append(31)
    return out


SONGS = {
    'mus_menu': (14,                    # καρέ ανά όγδοο: ~107 bpm
        # 1 Dm        2 Bb          3 C            4 Dm
        'A4:2 D5:2 F5:2 E5:1 D5:1  F5:2 D5:2 A#4:4  C5:2 E5:2 G5:2 F5:1 E5:1  D5:8 '
        # 5 Gm          6 Bb            7 A            8 A
        'G4:2 A#4:2 D5:2 C5:1 A#4:1  A4:2 A#4:2 D5:4  C#5:2 E5:2 A5:2 G5:1 E5:1  E5:4 C#5:2 A4:2',
        'D3:4 A3:4  A#2:4 F3:4  C3:4 G3:4  D3:4 A3:4 '
        'G2:4 D3:4  A#2:4 F3:4  A2:4 E3:4  A2:4 C#3:4'),
    'mus_game': (16,                    # ~94 bpm, πιο αραιό
        'r:4 E5:2 D5:2  C5:6 B4:2  A4:2 B4:2 C5:2 D5:2  E5:8 '
        'r:4 F5:2 E5:2  D5:6 C5:2  B4:2 C5:2 D5:2 B4:2  A4:8 '
        'A4:2 C5:2 E5:4  D5:2 B4:2 G4:4  A4:2 C5:2 F5:4  E5:4 G#4:4 '
        'A4:4 B4:4  C5:2 D5:2 F5:4  E5:2 D5:2 C5:2 B4:2  A4:8',
        'A2:4 E3:4  A2:4 E3:4  G2:4 D3:4  C3:4 G3:4 '
        'F2:4 C3:4  D3:4 A3:4  G2:4 D3:4  A2:4 E3:4 '
        'A2:4 E3:4  G2:4 D3:4  F2:4 C3:4  E2:4 B2:4 '
        'A2:4 E3:4  D3:4 A3:4  E2:8  A2:8'),
}


def main():
    for name, (step, a, b) in SONGS.items():
        lines = ['; %s.asm — από το src/make_music.py (M21). Μην το αλλάζεις με το '
                 'χέρι.\n' % name.replace('mus_', 'music_')]
        va, vb = voice(a, 1), voice(b, 0)
        la = sum(DUR[x >> 5] for x in va[:-1])
        lb = sum(DUR[x >> 5] for x in vb[:-1])
        assert la == lb, (name, la, lb)
        lines.append('%s: db %d\n        dw %s_a, %s_b\n' % (name, step, name, name))
        for tag, v in (('a', va), ('b', vb)):
            lines.append('%s_%s:\n' % (name, tag))
            for k in range(0, len(v), 16):
                lines.append('        db %s\n' % ', '.join('#%02X' % x for x in v[k:k + 16]))
        lines.append('%s_end:\n' % name)
        path = OUT % name.replace('mus_', 'music_')
        open(path, 'w').write(''.join(lines))
        print(os.path.normpath(path))


if __name__ == '__main__':
    main()
