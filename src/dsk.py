"""Αρχεία ΧΩΡΙΣ κεφαλίδα AMSDOS σε δισκέτα DATA (EXTENDED DSK), M12.

    python3 src/dsk.py build/polis.dsk ΟΝΟΜΑ.ΕΧΤ αρχείο [ΟΝΟΜΑ.ΕΧΤ αρχείο ...]
    python3 src/dsk.py build/polis.dsk --empty SAVE.BIN 41984
    python3 src/dsk.py build/polis.dsk --zx0 ΟΝΟΜΑ.ΕΧΤ αρχείο   (συμπιεσμένο ZX0)

Ο rasm γράφει τα αρχεία του με κεφαλίδα AMSDOS (128 bytes). Ο δικός μας
οδηγός (game/disk.asm) διαβάζει blocks κατευθείαν, άρα η κεφαλίδα θα έπεφτε
στη μνήμη πριν από τα δεδομένα. Εδώ: τα bytes ως έχουν, σε όσα blocks του 1
KB χρειάζονται, με τις εγγραφές του καταλόγου (extents των 16 KB).

Η διάταξη DATA, όπως στο game/disk.asm: 9 τομείς #C1-#C9 των 512 bytes ανά
τροχιά· ο λογικός τομέας L είναι η τροχιά L / 9, ο τομέας #C1 + L mod 9· το
block b οι λογικοί 2b, 2b + 1· ο κατάλογος τα blocks 0-1 (64 εγγραφές των 32
bytes, #E5 = ελεύθερη).
"""
import os
import sys

DIR_N = 64
BLOCKS = 180


class Dsk:
    def __init__(self, path):
        self.path = path
        self.d = bytearray(open(path, 'rb').read())
        assert self.d.startswith(b'EXTENDED CPC DSK File'), path
        self.ntracks = self.d[0x30]

    def _sector(self, track, sid):
        """(offset, μήκος) των δεδομένων του τομέα στο αρχείο."""
        o = 256
        for t in range(track):
            o += self.d[0x34 + t] * 256
        th = self.d[o:o + 256]
        assert th.startswith(b'Track-Info'), track
        p = o + 256
        for k in range(th[0x15]):
            si = th[0x18 + 8 * k:0x20 + 8 * k]
            n = si[6] | si[7] << 8
            if si[2] == sid:
                return p, n
            p += n
        raise KeyError((track, hex(sid)))

    def logical(self, L):
        p, n = self._sector(L // 9, 0xC1 + L % 9)
        assert n == 512
        return p

    def read_block(self, b):
        return bytes(self.d[self.logical(2 * b):self.logical(2 * b) + 512] +
                     self.d[self.logical(2 * b + 1):
                            self.logical(2 * b + 1) + 512])

    def write_block(self, b, data):
        data = bytes(data) + bytes(1024 - len(data))
        for k in range(2):
            p = self.logical(2 * b + k)
            self.d[p:p + 512] = data[512 * k:512 * (k + 1)]

    def directory(self):
        raw = self.read_block(0) + self.read_block(1)
        return [bytearray(raw[32 * k:32 * k + 32]) for k in range(DIR_N)]

    def put_directory(self, ents):
        raw = b''.join(bytes(e) for e in ents)
        self.write_block(0, raw[:1024])
        self.write_block(1, raw[1024:])

    def used_blocks(self):
        used = {0, 1}
        for e in self.directory():
            if e[0] != 0xE5:
                used |= {b for b in e[16:32] if b}
        return used

    def files(self):
        out = {}
        for e in self.directory():
            if e[0] != 0xE5:
                name = bytes(c & 0x7F for c in e[1:12]).decode()
                out.setdefault(name, []).append((e[12], e[15],
                                                 [b for b in e[16:32] if b]))
        return out

    def add(self, name, data):
        """Ένα αρχείο χωρίς κεφαλίδα. Το όνομα «ΟΝΟΜΑ.ΕΧΤ» (8.3)."""
        base, ext = name.upper().split('.')
        amsname = (base.ljust(8) + ext.ljust(3)).encode()
        assert len(amsname) == 11, name
        ents = self.directory()
        for e in ents:
            assert e[0] == 0xE5 or bytes(e[1:12]) != amsname, \
                'υπάρχει ήδη: ' + name
        free = [b for b in range(2, BLOCKS) if b not in self.used_blocks()]
        nblk = max(1, (len(data) + 1023) // 1024)
        assert nblk <= len(free), '%s: %d blocks, ελεύθερα %d' % (
            name, nblk, len(free))
        blocks = free[:nblk]
        for k, b in enumerate(blocks):
            self.write_block(b, data[1024 * k:1024 * (k + 1)])
        recs = (len(data) + 127) // 128
        slots = [k for k, e in enumerate(ents) if e[0] == 0xE5]
        for x in range((nblk + 15) // 16):
            assert slots, 'ο κατάλογος γέμισε'
            e = bytearray(32)
            e[1:12] = amsname
            e[12] = x
            r = min(128, recs - 128 * x)
            e[15] = r
            for k, b in enumerate(blocks[16 * x:16 * (x + 1)]):
                e[16 + k] = b
            ents[slots.pop(0)] = e
        self.put_directory(ents)
        return blocks

    def get(self, name):
        """Τα bytes ενός αρχείου (όλα τα blocks του, με τη σειρά)."""
        base, ext = name.upper().split('.')
        exts = sorted(self.files()[base.ljust(8) + ext.ljust(3)])
        return b''.join(self.read_block(b) for _, _, bl in exts for b in bl)

    def free_blocks(self):
        return BLOCKS - len(self.used_blocks())

    def save(self):
        open(self.path, 'wb').write(self.d)


def zx0(data):
    """Τα bytes συμπιεσμένα ZX0 από τον ίδιο τον rasm (όπως τα μπλοκ LZX0 του
    POLIS.BIN): για το dzx0 του game/zx0.asm."""
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as d:
        raw = os.path.join(d, 'raw.bin')
        open(raw, 'wb').write(data)
        open(os.path.join(d, 'z.asm'), 'w').write(
            '        org 0\n        lzx0\n        incbin "%s"\n'
            '        lzclose\n' % raw)
        r = subprocess.run(['rasm', 'z.asm', '-o', 'z'], cwd=d,
                           capture_output=True)
        assert r.returncode == 0, r.stdout + r.stderr
        return open(os.path.join(d, 'z.bin'), 'rb').read()


def main():
    args = sys.argv[1:]
    dsk = Dsk(args.pop(0))
    while args:
        if args[0] == '--empty':
            name, size = args[1], int(args[2])
            args = args[3:]
            dsk.add(name, bytes(size))
        elif args[0] == '--zx0':
            name, path = args[1], args[2]
            args = args[3:]
            dsk.add(name, zx0(open(path, 'rb').read()))
        else:
            name, path = args[0], args[1]
            args = args[2:]
            dsk.add(name, open(path, 'rb').read())
    dsk.save()
    print('%s: %d αρχεία, %d blocks ελεύθερα' % (
        dsk.path, len(dsk.files()), dsk.free_blocks()))


if __name__ == '__main__':
    main()
