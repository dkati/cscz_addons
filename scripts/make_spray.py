"""
Build the mod's spray logo from a picture, the same way the game's options menu does it.

    python -I scripts/make_spray.py

Input : art/spray_julmaya.png   64x64; bright = logo, black = transparent (any colors; brightness counts)
Output: mod_pack/czero_addon/logos/julmaya.bmp      grayscale logo: shows in Options > Multiplayer
        mod_pack/czero_addon/logos/remapped.bmp     the logo in the chosen color (the menu writes this too)
        mod_pack/COPY TO ROOT CZERO/tempdecal.wad   the spray itself (lump "LOGO", type 0x40)

How the menu works (measured on the game's own files): a logo in logos/ is an 8-bit BMP whose palette
is a gray ramp (entry i = gray i). The color picked in Options scales that ramp:
entry i = int(color * i / 256). The result is written to logos/remapped.bmp and tempdecal.wad. In the
game, brighter = more visible, black = transparent. userconfig.cfg preselects this logo and color, so
pressing OK in Options rebuilds exactly the same spray.
"""
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SRC = os.path.join(REPO, 'art', 'spray_julmaya.png')
LOGO_NAME = 'julmaya'
COLOR = (0, 167, 255)   # "#Valve_Ltblue" (closest of the menu's colors to the logo's cyan)
OUT_LOGO = os.path.join(REPO, 'mod_pack', 'czero_addon', 'logos', LOGO_NAME + '.bmp')
OUT_REMAP = os.path.join(REPO, 'mod_pack', 'czero_addon', 'logos', 'remapped.bmp')
OUT_WAD = os.path.join(REPO, 'mod_pack', 'COPY TO ROOT CZERO', 'tempdecal.wad')


def read_png(path):
    d = open(path, 'rb').read()
    assert d[:8] == b'\x89PNG\r\n\x1a\n', 'not a PNG'
    i, chunks, idat = 8, {}, b''
    while i < len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]; t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]; i += 12 + n
        if t == b'IDAT': idat += c
        else: chunks[t] = c
    w, h, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', chunks[b'IHDR'])
    assert depth == 8 and interlace == 0, 'need an 8-bit, non-interlaced PNG'
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(idat); rows = []; prev = bytes(w * bpp); k = 0
    for _ in range(h):
        f = raw[k]; line = bytearray(raw[k + 1:k + 1 + w * bpp]); k += 1 + w * bpp
        for x in range(len(line)):
            a = line[x - bpp] if x >= bpp else 0; b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c; pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(bytes(line)); prev = bytes(line)
    pal = [tuple(chunks[b'PLTE'][j:j + 3]) for j in range(0, len(chunks.get(b'PLTE', b'')), 3)]
    trns = chunks.get(b'tRNS', b'')
    out = []
    for r in rows:
        for x in range(w):
            if ctype == 3:
                p = r[x]; rgb = pal[p]; alpha = trns[p] if p < len(trns) else 255
            elif ctype in (2, 6):
                rgb = tuple(r[x * bpp:x * bpp + 3]); alpha = r[x * bpp + 3] if ctype == 6 else 255
            else:
                rgb = (r[x * bpp],) * 3; alpha = r[x * bpp + 1] if ctype == 4 else 255
            out.append((rgb, alpha))
    return w, h, out


def to_gray(pixels):
    """Brightness of each pixel (0..255), stretched so the brightest logo pixel becomes 255."""
    vals = [max(rgb) * alpha // 255 for rgb, alpha in pixels]
    top = max(vals) or 1
    return [min(255, round(v * 255 / top)) for v in vals]


def write_bmp8(path, w, h, pix, pal):
    stride = (w + 3) & ~3
    body = b''.join(bytes(pix[(h - 1 - y) * w:(h - y) * w]) + bytes(stride - w) for y in range(h))
    paldata = b''.join(bytes((b, g, r, 0)) for r, g, b in pal)
    off = 14 + 40 + len(paldata)
    hdr = b'BM' + struct.pack('<IHHI', off + len(body), 0, 0, off)
    info = struct.pack('<IiiHHIIiiII', 40, w, h, 1, 8, 0, len(body), 2835, 2835, 256, 0)
    open(path, 'wb').write(hdr + info + paldata + body)


def write_tempdecal(path, w, h, pix, pal):
    """WAD3 with one lump "LOGO", type 0x40, laid out like the file the game writes."""
    mips = [bytes(pix)]
    for s in (2, 4, 8):
        mips.append(bytes(pix[(y * s) * w + x * s] for y in range(h // s) for x in range(w // s)))
    head = b'LOGO'.ljust(16, b'\0') + struct.pack('<II', w, h)
    offs, pos = [], 40
    for m in mips:
        offs.append(pos); pos += len(m)
    lump = head + struct.pack('<4I', *offs) + b''.join(mips)
    lump += struct.pack('<H', 256) + b''.join(bytes(c) for c in pal) + b'\0\0'
    dirofs = 12 + len(lump)
    entry = struct.pack('<iiibbbb16s', 12, len(lump), len(lump), 0x40, 0, 0, 0, b'LOGO')
    if os.path.exists(path):
        os.chmod(path, 0o666)
    open(path, 'wb').write(b'WAD3' + struct.pack('<ii', 1, dirofs) + lump + entry)


def main():
    w, h, pixels = read_png(SRC)
    assert w % 16 == 0 and h % 16 == 0 and w * h <= 64 * 96, 'logo must be e.g. 64x64 (multiple of 16)'
    gray = to_gray(pixels)
    ramp = [(i, i, i) for i in range(256)]
    remap = [tuple(int(c * i / 256) for c in COLOR) for i in range(256)]
    write_bmp8(OUT_LOGO, w, h, gray, ramp)
    write_bmp8(OUT_REMAP, w, h, gray, remap)
    write_tempdecal(OUT_WAD, w, h, gray, remap)
    used = sorted(set(gray))
    print('logo %dx%d, %d brightness levels, %d%% visible' % (w, h, len(used), 100 * sum(1 for g in gray if g) // len(gray)))
    for p in (OUT_LOGO, OUT_REMAP, OUT_WAD):
        print('wrote', os.path.relpath(p, REPO), os.path.getsize(p), 'bytes')


if __name__ == '__main__':
    main()
