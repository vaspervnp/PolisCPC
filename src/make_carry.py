"""Ο χωρικός που κουβαλάει -> data/villager_carry.bin (M6).

    python3 src/make_carry.py

Τα ίδια 21 καρέ με τον villager_m, με ένα δέμα πάνω στο κεφάλι: στις 2
γραμμές πάνω από το κάλυμμα, που είναι πάντα άδειες. Ένα σχέδιο για όλα τα
είδη πόρων (τέσσερα σετ δεν χωράνε στην τράπεζα C5) — αρκεί να φαίνεται ότι
πηγαίνει να αδειάσει. Το παιχνίδι αλλάζει σετ όταν το φορτίο γίνει > 0 και
πίσω όταν αδειάσει (gather.asm).
"""
import os

import gfx
import preview

DATA = os.path.join(gfx.OUT, 'data')
PREVIEW = os.path.join(gfx.OUT, 'preview')

BUNDLE = ['-yyyy-',
          '-DDDD-']


def carry(img):
    """Το δέμα 2 γραμμές πάνω από την πρώτη γεμάτη γραμμή, στο κέντρο."""
    top = next(y for y, r in enumerate(img) if any(p is not None for p in r))
    out = [list(r) for r in img]
    y0 = max(0, top - len(BUNDLE))
    for j, row in enumerate(BUNDLE):
        for i, ch in enumerate(row):
            if ch != '-':
                out[y0 + j][1 + i] = gfx.PEN[ch]
    return out


def main():
    blob = open(os.path.join(DATA, 'villager_m.bin'), 'rb').read()
    frames = [gfx.decode_masked(blob[k:k + 128], 8, 16)
              for k in range(0, len(blob), 128)]
    out = [carry(f) for f in frames]
    data = b''.join(gfx.encode_masked(f) for f in out)
    assert len(data) == len(blob)
    with open(os.path.join(DATA, 'villager_carry.bin'), 'wb') as f:
        f.write(data)
    path = os.path.join(PREVIEW, 'villager_carry.png')
    preview.contact_sheet(path, [(str(k), f) for k, f in enumerate(out)],
                          title='villager_carry: ο χωρικός με φορτίο')
    print('data/villager_carry.bin  %d καρέ, %d bytes' % (len(out), len(data)))
    print(path)


if __name__ == '__main__':
    main()
