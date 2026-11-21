"""Οι εικόνες των εγχειριδίων (docs/img/) από τον emulator (M20).

    python3 tests/doc_shots.py

town.png      η πόλη στην αρχή
build.png     το μενού BUILD (RETURN σε επιλεγμένο χωρικό)
hud.png       ο κέρσορας στα κουμπιά του HUD: το RESEARCH φωτισμένο, η
              ετικέτα του στην κορυφή
squad.png, battle.png
              μόνο η λωρίδα των κουμπιών του HUD ξανά (από το town.png): είναι
              ίδια σε κάθε στιγμή του παιχνιδιού, και ως το M19 είχε 16
              κουμπιά
tutorial.png  το build/m14_step3.png (python3 tests/m14_check.py --shots)
"""
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, '..', 'src'))
import m4_check as M4                           # noqa: E402
import m6_check as M6                           # noqa: E402
import m7_check as M7                           # noqa: E402
import ui_menu as UM                            # noqa: E402
import cpc as CPCMOD                            # noqa: E402

IMG = os.path.join(HERE, '..', 'docs', 'img')
BUTTONS_BOX = (225, 392, 700, 474)      # στην εικόνα 768 x 544 (aspect)


def shot(c, name):
    path = os.path.join(IMG, name)
    c.screenshot(path, aspect=True)
    print('   ', os.path.normpath(path))


def main():
    from PIL import Image
    g = M4.Game(False)
    c = g.c
    g.tick(3)
    g.move_cursor(56, 100)
    g.tick(4)
    shot(c, 'town.png')

    M6.click_unit(g, 0)
    M7.press(g, CPCMOD.KEY_RETURN, 1)
    UM.wait_open(c)
    UM.tap(c, 'a')
    shot(c, 'build.png')
    UM.close(c)

    UM.hud_enter(c)
    UM.tap(c, 'p')
    UM.tap(c, 'p')
    g.tick(4)
    shot(c, 'hud.png')

    new = Image.open(os.path.join(IMG, 'town.png')).convert('RGB')
    strip = new.crop(BUTTONS_BOX)
    for name in ('squad.png', 'battle.png'):
        path = os.path.join(IMG, name)
        im = Image.open(path).convert('RGB')
        im.paste(strip, BUTTONS_BOX[:2])
        im.save(path)
        print('   ', os.path.normpath(path), '(τα κουμπιά)')

    src = os.path.join(M4.M.BUILD, 'm14_step3.png')
    if os.path.exists(src):
        shutil.copy(src, os.path.join(IMG, 'tutorial.png'))
        print('   ', os.path.normpath(os.path.join(IMG, 'tutorial.png')))
    else:
        print('    (λείπει το %s: python3 tests/m14_check.py --shots)' % src)


if __name__ == '__main__':
    main()
