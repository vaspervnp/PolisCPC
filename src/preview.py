"""Μεγεθυμένη προεπισκόπηση με ΣΩΣΤΗ αναλογία pixel (2:1 στο Mode 0).

    python3 src/preview.py            # όλο το σετ
    python3 src/preview.py knight     # μία μονάδα

Γράφει PNG στο /tmp. Κάθε pixel βγαίνει διπλάσια φαρδύ από ψηλό — αλλιώς οι
φιγούρες φαίνονται στενόμακρες και κρίνονται λάθος.
"""
import os

from PIL import Image, ImageDraw

import gfx

TMP = os.environ.get('TMPDIR', '/tmp')
BG = (24, 26, 34)
GRID = (44, 48, 60)


def draw(d, img, ox, oy, zoom, grid=False):
    for y, row in enumerate(img):
        for x, pen in enumerate(row):
            if pen is None:
                if grid and (x + y) % 2 == 0:
                    d.rectangle([ox + x * 2 * zoom, oy + y * zoom,
                                 ox + x * 2 * zoom + 2 * zoom - 1,
                                 oy + y * zoom + zoom - 1], fill=GRID)
                continue
            d.rectangle([ox + x * 2 * zoom, oy + y * zoom,
                         ox + x * 2 * zoom + 2 * zoom - 1,
                         oy + y * zoom + zoom - 1], fill=gfx.RGB[pen])


def contact_sheet(path, items, zoom=5, cols=None, title='', grid=True):
    """items: [(ετικέτα, εικόνα)] — όλες ίδιου μεγέθους."""
    w, h = len(items[0][1][0]), len(items[0][1])
    cols = cols or min(len(items), 12)
    rows = (len(items) + cols - 1) // cols
    cw, ch = w * 2 * zoom + 10, h * zoom + 16
    im = Image.new('RGB', (cols * cw + 12, rows * ch + (26 if title else 12)), BG)
    d = ImageDraw.Draw(im)
    top = 6
    if title:
        d.text((8, 8), title, fill=(255, 206, 92))
        top = 26
    for i, (label, img) in enumerate(items):
        ox = 6 + (i % cols) * cw
        oy = top + (i // cols) * ch
        draw(d, img, ox, oy, zoom, grid)
        d.text((ox, oy + h * zoom + 3), label[:14], fill=(190, 192, 205))
    im.save(path)
    return path


if __name__ == '__main__':
    import figures
    items = []
    for f in figures.FACINGS:
        for ph in range(4):
            items.append(('%s%d' % (f, ph), figures.walking(f, ph)))
    items.append(('w0 (καθρ.)', gfx.mirror(figures.walking('e', 0))))
    items.append(('w2 (καθρ.)', gfx.mirror(figures.walking('e', 2))))
    print(contact_sheet(os.path.join(TMP, 'polis_base.png'), items, zoom=7,
                        cols=4, title='βασική φιγούρα — βάδισμα, 3 όψεις + καθρέφτισμα'))
