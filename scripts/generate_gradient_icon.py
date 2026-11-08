"""Membuat ikon TPLive bergaya gradasi (mesh) dengan siluet bus.

Keluaran di assets/logo:
  icon_bg.png      latar gradasi persegi penuh (latar adaptif)
  app_icon_fg.png  siluet bus transparan di safe zone (lapisan depan adaptif)
  app_icon.png     squircle gradasi + bus (ikon non-adaptif / web / situs)

Jalankan: python scripts/generate_gradient_icon.py
Lalu:     dart run flutter_launcher_icons
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'logo')
S = 1024

NAVY = (31, 58, 107)
NAVY_DARK = (22, 40, 82)


def hexc(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def gradient(size=S):
    """Mesh gradient: biru kiri-atas -> krem diagonal -> oranye/koral kanan-bawah."""
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32) / (size - 1)
    # (x, y, warna, sigma)
    blobs = [
        (0.04, 0.04, hexc('#1F55C8'), 0.30),   # biru
        (0.50, 0.00, hexc('#7C8FD6'), 0.26),   # biru muda
        (0.98, 0.06, hexc('#FFA45C'), 0.30),   # oranye terang
        (0.22, 0.90, hexc('#FFF0C4'), 0.28),   # krem
        (0.50, 0.62, hexc('#FFF4D6'), 0.24),   # krem tengah (pita diagonal)
        (0.96, 0.84, hexc('#F23F6B'), 0.30),   # pink/koral
        (0.80, 0.50, hexc('#F47F38'), 0.20),   # oranye merek
    ]
    acc = np.zeros((size, size, 3), np.float32)
    wsum = np.zeros((size, size, 1), np.float32)
    for bx, by, col, sg in blobs:
        d2 = (xs - bx) ** 2 + (ys - by) ** 2
        w = np.exp(-d2 / (2 * sg * sg))[..., None]
        acc += w * np.array(col, np.float32)
        wsum += w
    img = np.clip(acc / wsum, 0, 255).astype(np.uint8)
    return Image.fromarray(img, 'RGB').convert('RGBA')


def bus_layer(scale_w, size=S, ss=2):
    """Siluet bus (transparan) lebar `scale_w` * size, di tengah kanvas."""
    n = size * ss
    # koordinat asli (kanvas 1024): badan 240..780 x 205..742
    ox, oy, bw, bh = 240, 205, 540, 615  # termasuk roda sampai y=820
    k = (scale_w * n) / bw
    cx, cy = n / 2, n / 2

    def P(x, y):
        return (cx + (x - (ox + bw / 2)) * k, cy + (y - (oy + bh / 2)) * k)

    def rr(d, box, r, fill):
        (x0, y0), (x1, y1) = P(box[0], box[1]), P(box[2], box[3])
        d.rounded_rectangle((x0, y0, x1, y1), radius=r * k, fill=fill)

    body = Image.new('L', (n, n), 0)
    d = ImageDraw.Draw(body)
    # atap melengkung: elips di atas + persegi di bawah
    (ex0, ey0), (ex1, ey1) = P(240, 205), P(780, 400)
    d.ellipse((ex0, ey0, ex1, ey1), fill=255)
    d.rectangle(P(240, 303) + P(780, 560), fill=255)
    rr(d, (240, 480, 780, 742), 36, 255)
    # lubang jendela & lampu (transparan -> gradasi terlihat)
    hole = Image.new('L', (n, n), 0)
    h = ImageDraw.Draw(hole)
    rr(h, (317, 318, 703, 550), 40, 255)
    for lx in (337, 683):
        (a, b), (c, e) = P(lx - 39, 646 - 39), P(lx + 39, 646 + 39)
        h.ellipse((a, b, c, e), fill=255)
    body_arr = np.array(body, np.int16) - np.array(hole, np.int16)
    body = Image.fromarray(np.clip(body_arr, 0, 255).astype(np.uint8), 'L')

    wheels = Image.new('L', (n, n), 0)
    w = ImageDraw.Draw(wheels)
    rr(w, (279, 735, 394, 820), 30, 255)
    rr(w, (626, 735, 741, 820), 30, 255)

    layer = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    layer.paste(Image.new('RGBA', (n, n), NAVY + (255,)), (0, 0), body)
    layer.paste(Image.new('RGBA', (n, n), NAVY_DARK + (255,)), (0, 0), wheels)

    # bayangan lembut di bawah bus
    shadow = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    sm = Image.eval(Image.composite(Image.new('L', (n, n), 255), Image.new('L', (n, n), 0),
                                    Image.fromarray(np.maximum(np.array(body), np.array(wheels)))), lambda v: v)
    shadow.paste(Image.new('RGBA', (n, n), (20, 30, 70, 90)), (0, int(10 * ss)), sm)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14 * ss))
    out = Image.alpha_composite(shadow, layer)
    return out.resize((size, size), Image.LANCZOS)


def squircle_mask(size=S, n=5.0, span=0.96):
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float32)
    c = (size - 1) / 2
    r = size * span / 2
    v = (np.abs(xs - c) / r) ** n + (np.abs(ys - c) / r) ** n
    # tepi halus (anti-alias) lewat jarak ternormalisasi
    a = np.clip((1.0 - v) * r * 0.5, 0, 1)
    return Image.fromarray((a * 255).astype(np.uint8), 'L')


def main():
    os.makedirs(OUT, exist_ok=True)
    bg = gradient()
    bg.convert('RGB').save(os.path.join(OUT, 'icon_bg.png'))

    # adaptif: bus ~ 46% lebar kanvas (aman di dalam safe zone 66%)
    fg = bus_layer(0.46)
    fg.save(os.path.join(OUT, 'app_icon_fg.png'))

    # non-adaptif: squircle gradasi + bus sedikit lebih besar
    full = Image.alpha_composite(bg, bus_layer(0.52))
    full.putalpha(squircle_mask())
    full.save(os.path.join(OUT, 'app_icon.png'))
    print('ok')


if __name__ == '__main__':
    main()
