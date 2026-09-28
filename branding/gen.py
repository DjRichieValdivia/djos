#!/usr/bin/python3
# Genera los gráficos de DJOS (fondos de pantalla, logo con nombre, vistas previas) a partir de djos-mark.svg.
# Se corre a mano cuando cambia el diseño (necesita python3-pillow, python3-numpy, librsvg2-tools y la fuente Inter);
# los resultados quedan en system/ y se guardan en el repositorio.
import glob, io, math, os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SYS = os.path.join(HERE, "..", "system")
ORANGE_A = np.array([255, 162, 74], dtype=np.float32)   # #FFA24A
ORANGE_B = np.array([255, 90, 10], dtype=np.float32)    # #FF5A0A


def svg_png(svg, width, bg=None):
    cmd = ["rsvg-convert", "-w", str(width)]
    if bg:
        cmd += ["-b", bg]
    return Image.open(io.BytesIO(subprocess.check_output(cmd + [svg]))).convert("RGBA")


def font(weight, size):
    pats = {"black": "*Inter*Black.*", "xbold": "*Inter*ExtraBold.*", "bold": "*Inter*-Bold.*", "medium": "*Inter*Medium.*"}
    files = [f for f in glob.glob("/usr/share/fonts/**/" + pats[weight], recursive=True) if "Display" not in f and "Italic" not in f]
    return ImageFont.truetype(sorted(files)[0], size)


def wallpaper(W, H, seed=7):
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    # fondo: gris azulado muy oscuro, más claro arriba a la izquierda
    d = np.sqrt(((x - 0.28 * W) / W) ** 2 + ((y - 0.30 * H) / H) ** 2 * 1.6)
    t = np.clip(d / 1.05, 0, 1) ** 0.9
    c0 = np.array([27, 31, 39], np.float32); c1 = np.array([6, 7, 9], np.float32)
    img = c0[None, None, :] * (1 - t[..., None]) + c1[None, None, :] * t[..., None]
    # resplandor cálido debajo de la forma de onda
    cy = 0.64 * H
    g = np.exp(-(((x - 0.5 * W) / (0.42 * W)) ** 2 + ((y - cy) / (0.20 * H)) ** 2))
    img += g[..., None] * np.array([46, 16, 0], np.float32)

    # forma de onda de un tema (como la vista general de un deck): barras finas con envolvente de "tema"
    n = 300
    x0, x1 = 0.055 * W, 0.945 * W
    step = (x1 - x0) / n
    u = np.linspace(0, 1, n)
    env = (0.35 + 0.65 * np.clip(np.sin(u * math.pi) ** 0.6, 0, 1))
    sections = np.interp(u, [0, .08, .12, .30, .34, .46, .50, .72, .76, .90, .94, 1],
                         [.25, .35, .85, .9, .45, .5, 1.0, 1.0, .55, .6, .3, .2])
    noise = np.convolve(rng.random(n + 6), np.ones(7) / 7, mode="valid")[:n]
    kick = 0.75 + 0.25 * (np.arange(n) % 4 == 0)
    amp = np.clip(env * sections * (0.55 + 0.45 * noise) * kick, 0.04, 1)
    half = 0.155 * H
    play = 0.40
    bars = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(bars)
    bw = max(2, int(step * 0.52))
    for i in range(n):
        f = i / (n - 1)
        col = ORANGE_A * (1 - f) + ORANGE_B * f
        a = 235 if f < play else 95
        h = amp[i] * half
        bx = x0 + i * step
        dr.rounded_rectangle([bx, cy - h, bx + bw, cy + h], radius=bw // 2, fill=(int(col[0]), int(col[1]), int(col[2]), a))
    glow = bars.filter(ImageFilter.GaussianBlur(radius=max(6, W // 130)))
    base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, bars)
    # cabezal de reproducción
    ph = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(ph)
    px = x0 + play * (x1 - x0)
    lw = max(2, W // 900)
    pd.rectangle([px - lw, cy - half * 1.28, px + lw, cy + half * 1.28], fill=(255, 244, 232, 230))
    base = Image.alpha_composite(base, ph.filter(ImageFilter.GaussianBlur(radius=max(3, W // 500))))
    base = Image.alpha_composite(base, ph)
    # viñeta + un poco de grano para que el degradé no haga escalones
    arr = np.asarray(base.convert("RGB")).astype(np.float32)
    v = np.clip(1.0 - 0.38 * (((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2) ** 1.4, 0.45, 1)
    arr = arr * v[..., None] + rng.normal(0, 1.1, arr.shape)
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def lockscreen(W, H):
    im = wallpaper(W, H, seed=11)
    return im.filter(ImageFilter.GaussianBlur(radius=W // 220))


def wordmark(height, color=(255, 255, 255, 255)):
    """Logo horizontal: marca + "DJOS" (transparente)."""
    mark = svg_png(os.path.join(HERE, "djos-mark.svg"), height)
    f = font("xbold", int(height * 0.62))
    tmp = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    spacing = int(height * 0.035)
    widths = [tmp.textlength(ch, font=f) for ch in "DJOS"]
    tw = int(sum(widths) + spacing * 3)
    gap = int(height * 0.30)
    out = Image.new("RGBA", (height + gap + tw + 4, height), (0, 0, 0, 0))
    out.alpha_composite(mark, (0, 0))
    d = ImageDraw.Draw(out)
    asc, desc = f.getmetrics()
    bbox = f.getbbox("DJOS")
    ty = (height - (bbox[3] - bbox[1])) // 2 - bbox[1]
    xx = height + gap
    for ch, w in zip("DJOS", widths):
        d.text((xx, ty), ch, font=f, fill=color)
        xx += w + spacing
    return out


def main():
    wp = os.path.join(SYS, "usr/share/wallpapers/DJOS/contents/images")
    lk = os.path.join(SYS, "usr/share/wallpapers/DJOS-Lock/contents/images")
    os.makedirs(wp, exist_ok=True); os.makedirs(lk, exist_ok=True)
    for (W, H) in [(3840, 2160), (2560, 1440), (1920, 1080), (1920, 1200), (3440, 1440)]:
        wallpaper(W, H).save(os.path.join(wp, f"{W}x{H}.jpg"), quality=93, subsampling=0, optimize=True)
        lockscreen(W, H).save(os.path.join(lk, f"{W}x{H}.jpg"), quality=90, subsampling=0, optimize=True)
    wallpaper(640, 360).save(os.path.join(SYS, "usr/share/wallpapers/DJOS/contents/screenshot.jpg"), quality=88)
    lockscreen(640, 360).save(os.path.join(SYS, "usr/share/wallpapers/DJOS-Lock/contents/screenshot.jpg"), quality=88)

    share = os.path.join(SYS, "usr/share/djos"); os.makedirs(share, exist_ok=True)
    wordmark(256).save(os.path.join(share, "logo.png"), optimize=True)
    wordmark(128).save(os.path.join(share, "logo-small.png"), optimize=True)
    for s in (256, 512):
        svg_png(os.path.join(HERE, "djos-mark.svg"), s).save(os.path.join(share, f"mark-{s}.png"), optimize=True)
    # pantalla de arranque (Plymouth): el logo con el nombre, al centro
    ply = os.path.join(SYS, "usr/share/plymouth/themes/djos"); os.makedirs(ply, exist_ok=True)
    wordmark(88).save(os.path.join(ply, "watermark.png"), optimize=True)

    # vistas previas del tema (las muestra Configuración > Tema global)
    prev = os.path.join(SYS, "usr/share/plasma/look-and-feel/org.djos.desktop/contents/previews")
    os.makedirs(prev, exist_ok=True)
    pv = wallpaper(1280, 720)
    d = ImageDraw.Draw(pv)
    d.rounded_rectangle([12, 672, 1268, 708], radius=10, fill=(17, 20, 24))
    pv.save(os.path.join(prev, "fullscreenpreview.jpg"), quality=88)
    pv.resize((320, 180)).save(os.path.join(prev, "preview.png"))
    sp = Image.new("RGB", (1280, 720), (8, 9, 11))
    wm = wordmark(96)
    sp.paste(wm, ((1280 - wm.width) // 2, 300), wm)
    sp.save(os.path.join(prev, "splash.png"))
    lockscreen(1280, 720).save(os.path.join(prev, "lockscreen.png"))
    print("listo")


if __name__ == "__main__":
    main()
