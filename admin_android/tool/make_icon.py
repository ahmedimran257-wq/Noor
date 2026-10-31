"""Builds the Silarah Admin launcher foreground and monochrome layers.

Adaptive-icon layers are drawn at many sizes, so layer-list insets (fixed
dp) do not scale with the icon. This composes each layer as one image per
density instead: the Silarah script in champagne, about 50dp wide, and a
staff shield beneath, all inside the 66dp safe circle of the 108dp canvas.

usage (from admin_android/):  python tool/make_icon.py
Pure Python (zlib only), so it runs without image libraries.
"""
import struct
import zlib
from pathlib import Path

RES = Path("app/src/main/res")
SOURCE = RES / "drawable-xxxhdpi" / "ic_launcher_foreground.png"
MARK = (0xE8, 0xD3, 0xA2)  # champagne, matches @color/admin_icon_mark
MASTER = 864               # 108dp at 8 px/dp
DENSITIES = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def read_png_rgba(path):
    data = path.read_bytes()
    width, height, depth, ctype = struct.unpack(">IIBB", data[16:26])
    assert depth == 8 and ctype == 6, "expects 8-bit RGBA"
    pos, idat = 8, b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        if data[pos + 4:pos + 8] == b"IDAT":
            idat += data[pos + 8:pos + 8 + length]
        pos += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 4
    rows, prev, offset = [], bytearray(stride), 0
    for _ in range(height):
        kind = raw[offset]
        line = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    return width, height, rows


def write_png_rgba(path, size, pixels):
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        raw += pixels[y * size * 4:(y + 1) * size * 4]

    def chunk(kind, body):
        return (struct.pack(">I", len(body)) + kind + body
                + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def logo_alpha():
    """Alpha of the script, cropped to its ink bounds."""
    width, height, rows = read_png_rgba(SOURCE)
    xs, ys = [], []
    for y in range(height):
        for x in range(width):
            if rows[y][x * 4 + 3] > 8:
                xs.append(x)
                ys.append(y)
    x0, x1, y0, y1 = min(xs), max(xs) + 1, min(ys), max(ys) + 1
    alpha = [[rows[y][x * 4 + 3] for x in range(x0, x1)] for y in range(y0, y1)]
    return alpha, x1 - x0, y1 - y0


def sample(alpha, w, h, fx, fy):
    """Bilinear sample of the alpha grid at fractional coordinates."""
    if fx < 0 or fy < 0 or fx > w - 1 or fy > h - 1:
        return 0.0
    x0, y0 = int(fx), int(fy)
    x1, y1 = min(x0 + 1, w - 1), min(y0 + 1, h - 1)
    tx, ty = fx - x0, fy - y0
    top = alpha[y0][x0] * (1 - tx) + alpha[y0][x1] * tx
    bottom = alpha[y1][x0] * (1 - tx) + alpha[y1][x1] * tx
    return (top * (1 - ty) + bottom * ty) / 255.0


def inside_shield(u, v):
    """Shield in a unit box (u, v in 0..1): flat top, curved sides to a point."""
    if v < 0.06 or v > 0.98:
        return False
    if v < 0.22:
        # Top edge slopes down from the centre to the shoulders.
        half = 0.42
        top = 0.06 + 0.16 * (abs(u - 0.5) / half)
        return abs(u - 0.5) <= half and v >= top
    # Sides curve in to the bottom point.
    t = (v - 0.22) / (0.98 - 0.22)
    half = 0.42 * (1 - t ** 1.6)
    return abs(u - 0.5) <= half


def inside_check(u, v):
    """Check mark stroke, as distance to two line segments."""
    def dist(px, py, ax, ay, bx, by):
        dx, dy = bx - ax, by - ay
        t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        cx, cy = ax + t * dx, ay + t * dy
        return ((px - cx) ** 2 + (py - cy) ** 2) ** 0.5
    width = 0.075
    return (dist(u, v, 0.30, 0.52, 0.45, 0.66) < width
            or dist(u, v, 0.45, 0.66, 0.72, 0.36) < width)


def compose(with_check_cutout, colour):
    alpha, lw, lh = logo_alpha()
    px_per_dp = MASTER / 108
    logo_w = 52 * px_per_dp
    scale = logo_w / lw
    logo_h = lh * scale
    logo_x = (MASTER - logo_w) / 2
    logo_cy = 47 * px_per_dp
    logo_y = logo_cy - logo_h / 2

    shield = 17 * px_per_dp
    shield_x = (MASTER - shield) / 2
    shield_y = 61 * px_per_dp

    sub = 3  # supersampling for the shield edges
    out = bytearray(MASTER * MASTER * 4)
    for y in range(MASTER):
        for x in range(MASTER):
            a = sample(alpha, lw, lh, (x - logo_x) / scale, (y - logo_y) / scale)
            if shield_x <= x < shield_x + shield and shield_y <= y < shield_y + shield:
                hits = 0
                for sy in range(sub):
                    for sx in range(sub):
                        u = (x - shield_x + (sx + 0.5) / sub) / shield
                        v = (y - shield_y + (sy + 0.5) / sub) / shield
                        if inside_shield(u, v) and not (with_check_cutout and inside_check(u, v)):
                            hits += 1
                a = max(a, hits / (sub * sub))
            i = (y * MASTER + x) * 4
            out[i:i + 4] = bytes((*colour, int(round(a * 255))))
    return out


def downsample(pixels, size):
    """Area-average the master down to one density (premultiplied)."""
    factor = MASTER / size
    out = bytearray(size * size * 4)
    for y in range(size):
        sy0, sy1 = int(y * factor), max(int((y + 1) * factor), int(y * factor) + 1)
        for x in range(size):
            sx0, sx1 = int(x * factor), max(int((x + 1) * factor), int(x * factor) + 1)
            total_a = r = g = b = 0
            count = 0
            for yy in range(sy0, sy1):
                for xx in range(sx0, sx1):
                    i = (yy * MASTER + xx) * 4
                    alpha = pixels[i + 3]
                    total_a += alpha
                    r += pixels[i] * alpha
                    g += pixels[i + 1] * alpha
                    b += pixels[i + 2] * alpha
                    count += 1
            i = (y * size + x) * 4
            if total_a:
                out[i:i + 4] = bytes((r // total_a, g // total_a, b // total_a, total_a // count))
    return out


def main():
    foreground = compose(with_check_cutout=True, colour=MARK)
    monochrome = compose(with_check_cutout=True, colour=(255, 255, 255))
    for density, size in DENSITIES.items():
        folder = RES / f"drawable-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        write_png_rgba(folder / "admin_icon_foreground.png", size, downsample(foreground, size))
        write_png_rgba(folder / "admin_icon_monochrome.png", size, downsample(monochrome, size))
    write_png_rgba(Path("tool") / "icon_preview_master.png", MASTER, foreground)
    print("icons written")


if __name__ == "__main__":
    main()
