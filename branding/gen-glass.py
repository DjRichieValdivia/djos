#!/usr/bin/python3
# Genera los gráficos de DJOS Glass (el aspecto tipo macOS de DJOS, solo la interfaz: nada de Apple adentro):
#   - la decoración de ventanas Aurorae "DJOSGlass": barra de título con esquinas redondeadas y sombra suave
#     (decoration.svg, con las partes en PNG a 2x) y el semáforo (close/minimize/maximize/restore.svg)
#   - el fondo de pantalla DJOS-Glass (todas las resoluciones de DJOS) y su vista previa
#   - el ícono del Launchpad del dock (djos-launchpad.svg)
#   - las vistas previas del tema global org.djos.glass (las que muestra el selector de temas)
# Se corre a mano cuando cambia el diseño, en un Fedora con python3-pillow, python3-numpy, librsvg2-tools, la fuente
# Inter y Papirus (para los íconos de la vista previa); por ejemplo desde la raíz del repo:
#   podman run --rm -v "$PWD":/repo:z registry.fedoraproject.org/fedora:44 sh -c \
#     'dnf5 -y -q install python3-pillow python3-numpy librsvg2-tools rsms-inter-fonts papirus-icon-theme-dark \
#      && python3 /repo/branding/gen-glass.py'
# Los resultados quedan en system/ y se guardan en el repositorio.
import base64, glob, io, math, os, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SYS = os.path.join(HERE, "..", "system")
AUR = os.path.join(SYS, "usr/share/aurorae/themes/DJOSGlass")
LNF = os.path.join(SYS, "usr/share/plasma/look-and-feel/org.djos.glass/contents/previews")
WALL = os.path.join(SYS, "usr/share/wallpapers/DJOS-Glass")
APPS = os.path.join(SYS, "usr/share/icons/Papirus-Dark-DJOS/scalable/apps")

S = 2   # las partes en PNG van a 2x: nítidas también en pantallas HiDPI

# medidas de la decoración (en píxeles a 1x; tienen que coincidir con DJOSGlassrc)
PAD_T, PAD_B, PAD_L, PAD_R = 18, 38, 30, 30   # sombra alrededor (más abajo, como si la luz viniera de arriba)
RADIUS = 10                                   # esquinas de arriba
TITLE = 28                                    # alto de la barra de título

# colores (los de DJOSGlass.colors)
TITLE_ACTIVE = (54, 54, 56)
TITLE_INACTIVE = (44, 44, 46)


def png_b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return base64.b64encode(buf.getvalue()).decode()


def font(weight, size):
    pats = {"bold": "*Inter*-Bold.*", "semibold": "*Inter*-SemiBold.*", "medium": "*Inter*-Medium.*",
            "regular": "*Inter*-Regular.*"}
    files = [f for f in glob.glob("/usr/share/fonts/**/" + pats[weight], recursive=True)
             if "Display" not in f and "Italic" not in f]
    if not files:   # Inter variable (rsms-inter-vf-fonts)
        files = glob.glob("/usr/share/fonts/**/InterVariable.*", recursive=True)
    return ImageFont.truetype(sorted(files)[0], size)


def svg_png(path, width):
    return Image.open(io.BytesIO(subprocess.check_output(["rsvg-convert", "-w", str(width), path]))).convert("RGBA")


def window_shape(w, h, r, s):
    """máscara de una ventana: esquinas de arriba redondeadas, las de abajo rectas (el contenido de la app)"""
    m = Image.new("L", (w * s, h * s), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=r * s, fill=255)
    d.rectangle((0, (h - r) * s, w * s - 1, h * s - 1), fill=255)
    return m


# ---------------------------------------------------------------- decoración de ventanas (Aurorae)
def decoration_canvas(active):
    """una ventana entera de ejemplo (sombra + borde + barra de título) para cortar en 9 partes"""
    cw, ch = 240, 240   # el medio: grande, para que la sombra de las tiras del centro ya sea la de los costados
    W = PAD_L + cw + PAD_R
    H = PAD_T + ch + PAD_B
    img = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))

    # sombra: la forma de la ventana, corrida hacia abajo y desenfocada (más suave en las inactivas)
    alpha, blur, dy = (165, 9, 8) if active else (110, 7, 5)   # desenfoque < margen/3: la sombra no se corta
    sh = Image.new("L", (W * S, H * S), 0)
    shape = window_shape(cw, ch, RADIUS, S)
    sh.paste(shape, (PAD_L * S, (PAD_T + dy) * S))
    sh = sh.filter(ImageFilter.GaussianBlur(blur * S))
    sh = sh.point(lambda v: v * alpha // 255)
    img.paste(Image.new("RGBA", img.size, (0, 0, 0, 255)), (0, 0), sh)

    # la ventana: borde exterior casi negro de 1 px y la barra de título
    win = Image.new("RGBA", (cw * S, ch * S), (0, 0, 0, 0))
    outline = Image.new("RGBA", win.size, (0, 0, 0, 200 if active else 150))
    win.paste(outline, (0, 0), shape)
    inner = window_shape(cw - 2, ch - 2, RADIUS - 1, S)
    fill = TITLE_ACTIVE if active else TITLE_INACTIVE
    win.paste(Image.new("RGBA", inner.size, fill + (255,)), (S, S), inner)
    img.alpha_composite(win, (PAD_L * S, PAD_T * S))
    # brillo fino arriba (la luz que tienen las ventanas de macOS en modo oscuro)
    top_light = Image.new("RGBA", (cw * S, ch * S), (0, 0, 0, 0))
    tl = ImageDraw.Draw(top_light)
    tl.rounded_rectangle((S, S, cw * S - S - 1, RADIUS * 2 * S), radius=(RADIUS - 1) * S,
                         outline=(255, 255, 255, 34 if active else 18), width=S)
    # solo el borde de arriba: se tapa la parte de abajo del contorno
    tl.rectangle((0, RADIUS * S, cw * S, ch * S), fill=(0, 0, 0, 0))
    img.alpha_composite(top_light, (PAD_L * S, PAD_T * S))
    return img, W, H


def frame_svg(active_img, inactive_img, W, H):
    """decoration.svg: las 9 partes (activa e inactiva) y la versión maximizada (solo la barra, sin sombra)"""
    lw, rw = PAD_L + RADIUS, PAD_R + RADIUS        # anchos de los costados (cubren la esquina redondeada)
    th, bh = PAD_T + RADIUS, PAD_B + 1              # altos de arriba (con la esquina) y abajo (sombra + borde)
    cx, cy = W // 2, H // 2                         # la columna y la fila del medio, para estirar
    parts = {   # nombre: (x, y, ancho, alto) en el lienzo, a 1x
        "topleft": (0, 0, lw, th), "top": (cx, 0, 1, th), "topright": (W - rw, 0, rw, th),
        "left": (0, cy, lw, 1), "right": (W - rw, cy, rw, 1),
        "bottomleft": (0, H - bh, lw, bh), "bottom": (cx, H - bh, 1, bh), "bottomright": (W - rw, H - bh, rw, bh),
    }
    # ubicación de cada parte en el SVG (no importa dónde, pero sin encimarse)
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<!-- DJOS Glass: decoración de ventanas Aurorae (la genera branding/gen-glass.py: no editar a mano) -->',
           '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
           'width="400" height="400" viewBox="0 0 400 400">']
    ox = 0
    for prefix, img, fill in (("decoration", active_img, TITLE_ACTIVE),
                              ("decoration-inactive", inactive_img, TITLE_INACTIVE)):
        oy = 0
        for name, (x, y, w, h) in parts.items():
            piece = img.crop((x * S, y * S, (x + w) * S, (y + h) * S))
            out.append(f'<image id="{prefix}-{name}" x="{ox}" y="{oy}" width="{w}" height="{h}" '
                       f'preserveAspectRatio="none" xlink:href="data:image/png;base64,{png_b64(piece)}"/>')
            oy += h + 2
        out.append(f'<rect id="{prefix}-center" x="{ox}" y="{oy}" width="10" height="10" '
                   f'fill="rgb{fill}"/>')
        ox += 60
    # maximizada: la barra de título lisa, sin sombra ni esquinas
    for prefix, fill in (("decoration-maximized", TITLE_ACTIVE), ("decoration-maximized-inactive", TITLE_INACTIVE)):
        oy = 0
        for name in ("topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"):
            out.append(f'<rect id="{prefix}-{name}" x="{ox}" y="{oy}" width="2" height="2" fill="rgb{fill}"/>')
            oy += 4
        ox += 10
    out.append("</svg>")
    return "\n".join(out) + "\n"


# el semáforo: rojo, amarillo y verde de 12 px en un botón de 16; el símbolo aparece al pasar el mouse por los tres
LIGHTS = {   # relleno, borde, símbolo
    "close": ("#ff5f57", "#e2463f", "#4d0000"),
    "minimize": ("#febc2e", "#e1a116", "#985700"),
    "maximize": ("#28c840", "#1aab29", "#006500"),
}
LIGHTS["restore"] = LIGHTS["maximize"]
GRAY = ("#4b4b4e", "#3d3d40")      # ventana inactiva
DISABLED = ("#3a3a3d", "#333336")  # botón que no se puede usar (p. ej. maximizar una ventana de tamaño fijo)


def glyph(kind, color):
    c = 8
    if kind == "close":
        return (f'<path d="M5.4 5.4 L10.6 10.6 M10.6 5.4 L5.4 10.6" stroke="{color}" stroke-width="1.3" '
                f'stroke-linecap="round" fill="none"/>')
    if kind == "minimize":
        return f'<path d="M4.8 8 H11.2" stroke="{color}" stroke-width="1.4" stroke-linecap="round" fill="none"/>'
    if kind == "maximize":   # dos triángulos hacia afuera (pantalla grande)
        return (f'<path d="M5.2 9.6 V5.2 H9.6 Z M10.8 6.4 V10.8 H6.4 Z" fill="{color}"/>')
    # restore: los triángulos hacia adentro
    return f'<path d="M7.6 4.4 V7.6 H4.4 Z M8.4 11.6 V8.4 H11.6 Z" fill="{color}"/>'


def button_svg(kind):
    fill, stroke, sym = LIGHTS[kind]
    def circle(prefix, f, s, g=""):
        return (f'<g id="{prefix}-center"><rect x="0" y="0" width="16" height="16" fill="none"/>'
                f'<circle cx="8" cy="8" r="5.75" fill="{f}" stroke="{s}" stroke-width="0.5"/>{g}</g>')
    darker = {"close": ("#bf4942", "#a63a34"), "minimize": ("#bf8e22", "#a67a12"),
              "maximize": ("#1d9730", "#167f24"), "restore": ("#1d9730", "#167f24")}[kind]
    states = [
        circle("active", fill, stroke),
        circle("hover", fill, stroke, glyph(kind, sym)),
        circle("pressed", darker[0], darker[1], glyph(kind, sym)),
        circle("inactive", GRAY[0], GRAY[1]),
        circle("hover-inactive", fill, stroke, glyph(kind, sym)),
        circle("pressed-inactive", darker[0], darker[1], glyph(kind, sym)),
        circle("deactivated", DISABLED[0], DISABLED[1]),
        circle("deactivated-inactive", DISABLED[0], DISABLED[1]),
    ]
    body = "\n".join(f'<g transform="translate({i * 20} 0)">{s}</g>' for i, s in enumerate(states))
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            f'<!-- DJOS Glass: botón "{kind}" del semáforo (lo genera branding/gen-glass.py: no editar a mano) -->\n'
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{20 * len(states)}" height="16" '
            f'viewBox="0 0 {20 * len(states)} 16">\n{body}\n</svg>\n')


# ---------------------------------------------------------------- fondo de pantalla
def wallpaper(W, H):
    """capas de vidrio que se cruzan en diagonal (naranja, magenta y violeta) sobre un fondo casi negro"""
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    u, v = x / W, y / H
    img = np.zeros((H, W, 3), np.float32)
    base_top = np.array([20, 16, 26], np.float32); base_bot = np.array([6, 6, 10], np.float32)
    img[:] = base_top * (1 - v[..., None]) + base_bot * v[..., None]

    def band(center, amp, freq, phase, width, soft):
        # una cinta: la distancia a una curva suave, con borde difuso
        c = center + amp * np.sin(2 * math.pi * (freq * u + phase)) + 0.18 * (u - 0.5)
        d = (v - c) / width
        return np.clip(1 - np.abs(d), 0, 1) ** soft, d

    layers = [   # centro, amplitud, frecuencia, fase, ancho, suavidad, color arriba, color abajo, intensidad
        (0.78, 0.10, 0.55, 0.10, 0.34, 1.6, (120, 30, 140), (40, 10, 70), 0.55),
        (0.66, 0.12, 0.45, 0.32, 0.26, 1.4, (255, 70, 120), (150, 20, 90), 0.55),
        (0.56, 0.11, 0.50, 0.55, 0.20, 1.3, (255, 140, 40), (230, 70, 20), 0.75),
        (0.48, 0.09, 0.60, 0.78, 0.12, 1.2, (255, 190, 110), (255, 110, 40), 0.55),
    ]
    for center, amp, freq, phase, width, soft, ca, cb, k in layers:
        a, d = band(center, amp, freq, phase, width, soft)
        t = np.clip((d + 1) / 2, 0, 1)[..., None]
        col = np.array(ca, np.float32) * (1 - t) + np.array(cb, np.float32) * t
        # el borde de arriba de cada cinta brilla un poco (vidrio)
        rim = np.exp(-((d + 0.92) / 0.05) ** 2)[..., None] * 0.35
        a = a[..., None] * k
        img = img * (1 - a) + col * a + rim * np.array(ca, np.float32) * 0.6
    # viñeta y un poco de grano (sin escalones en los degradados)
    vig = 1 - 0.45 * (((u - 0.5) * 1.1) ** 2 + ((v - 0.45) * 1.3) ** 2)
    img *= vig[..., None]
    img += np.random.default_rng(3).normal(0, 1.2, img.shape).astype(np.float32)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")


# ---------------------------------------------------------------- ícono del Launchpad (dock)
def launchpad_svg():
    colors = ["#ff7a1a", "#ff3b6b", "#bf5af2", "#0a84ff", "#30d0c4", "#32d74b", "#ffd60a", "#ff9f0a", "#8e8e93"]
    cells = []
    for i, c in enumerate(colors):
        cx, cy = 15 + (i % 3) * 13, 15 + (i // 3) * 13
        cells.append(f'<rect x="{cx}" y="{cy}" width="10" height="10" rx="3" fill="{c}"/>')
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!-- DJOS Glass: Launchpad del dock (todas las apps); lo genera branding/gen-glass.py -->\n'
            '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">\n'
            ' <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
            '<stop offset="0" stop-color="#4a4a50"/><stop offset="1" stop-color="#1f1f23"/></linearGradient></defs>\n'
            ' <rect x="4" y="4" width="56" height="56" rx="13" fill="url(#bg)"/>\n'
            ' <rect x="4.5" y="4.5" width="55" height="55" rx="12.5" fill="none" stroke="#ffffff" stroke-opacity="0.14"/>\n'
            ' ' + "\n ".join(cells) + "\n</svg>\n")


# ---------------------------------------------------------------- vistas previas del tema
def icon(name, size):
    for d in (APPS, os.path.join(SYS, "usr/share/icons/hicolor/scalable/apps"), "/usr/share/icons/Papirus/64x64/apps",
              "/usr/share/icons/Papirus/48x48/apps", "/usr/share/icons/Papirus/64x64/places"):
        p = os.path.join(d, name + ".svg")
        if os.path.exists(p):
            return svg_png(p, size)
    return None


def preview(W, H, wall):
    k = W / 1920
    img = wall.resize((W, H), Image.LANCZOS).convert("RGBA")
    # ventana de ejemplo con el semáforo
    wx, wy, ww, wh = int(560 * k), int(210 * k), int(800 * k), int(520 * k)
    sh = Image.new("L", img.size, 0)
    ImageDraw.Draw(sh).rounded_rectangle((wx, wy + 14 * k, wx + ww, wy + wh + 14 * k), radius=12 * k, fill=170)
    sh = sh.filter(ImageFilter.GaussianBlur(26 * k))
    img.paste(Image.new("RGBA", img.size, (0, 0, 0, 255)), (0, 0), sh)
    win = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(win)
    d.rounded_rectangle((wx, wy, wx + ww, wy + wh), radius=12 * k, fill=(42, 42, 44, 255), outline=(0, 0, 0, 220))
    d.rounded_rectangle((wx + 1, wy + 1, wx + ww - 1, wy + 44 * k), radius=11 * k, fill=TITLE_ACTIVE + (255,))
    d.rectangle((wx + 1, wy + 30 * k, wx + ww - 1, wy + 44 * k), fill=TITLE_ACTIVE + (255,))
    d.line((wx + 1, wy + 44 * k, wx + ww - 1, wy + 44 * k), fill=(24, 24, 26, 255), width=max(1, int(k)))
    for i, c in enumerate(("#febc2e", "#28c840", "#ff5f57")):   # a la derecha, como en Windows (ButtonsOnRight=IAX)
        cx, cy, r = wx + ww - (62 - i * 20) * k, wy + 22 * k, 6.5 * k
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)
    # barra lateral y lista, como un explorador de archivos
    d.rectangle((wx + 1, wy + 45 * k, wx + 190 * k, wy + wh - 1), fill=(36, 36, 38, 255))
    for i in range(7):
        y0 = wy + (70 + i * 34) * k
        d.rounded_rectangle((wx + 16 * k, y0, wx + (16 + 110 - (i % 3) * 20) * k, y0 + 12 * k), radius=6 * k,
                            fill=(255, 122, 26, 255) if i == 1 else (70, 70, 74, 255))
    for i in range(10):
        y0 = wy + (66 + i * 42) * k
        if y0 + 24 * k > wy + wh:
            break
        d.rounded_rectangle((wx + 214 * k, y0, wx + 250 * k, y0 + 28 * k), radius=5 * k, fill=(255, 140, 40, 255))
        d.rounded_rectangle((wx + 266 * k, y0 + 8 * k, wx + (266 + 260 - (i % 4) * 40) * k, y0 + 20 * k),
                            radius=6 * k, fill=(82, 82, 86, 255))
    img.alpha_composite(win)
    # barra de arriba (translúcida)
    bar = Image.new("RGBA", (W, int(28 * k)), (20, 20, 22, 170))
    img.alpha_composite(bar, (0, 0))
    d = ImageDraw.Draw(img)
    f = font("semibold", max(10, int(14 * k)))
    fr = font("regular", max(10, int(14 * k)))
    logo = svg_png(os.path.join(HERE, "djos-mark-mono.svg"), int(18 * k))
    img.alpha_composite(logo, (int(16 * k), int(5 * k)))
    x = 48 * k
    for i, word in enumerate(("Files", "File", "Edit", "View", "Go", "Help")):
        d.text((x, 6 * k), word, font=f if i == 0 else fr, fill=(240, 240, 242, 255))
        x += d.textlength(word, font=f if i == 0 else fr) + 22 * k
    clock = "Wed Oct 1  9:41 PM"
    d.text((W - 20 * k - d.textlength(clock, font=fr), 6 * k), clock, font=fr, fill=(240, 240, 242, 255))
    # dock flotante y centrado
    names = ["richiedj", "djoscenter", "firefox", "system-file-manager", "utilities-terminal", "systemsettings",
             "plasmadiscover", "djos-launchpad", "user-trash"]
    isz, gap = int(52 * k), int(10 * k)
    dw = len(names) * isz + (len(names) + 1) * gap + int(14 * k)
    dh = isz + 2 * gap
    dx, dy = (W - dw) // 2, H - dh - int(10 * k)
    dock = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(dock)
    dd.rounded_rectangle((dx, dy, dx + dw, dy + dh), radius=18 * k, fill=(40, 40, 44, 175),
                         outline=(255, 255, 255, 40), width=max(1, int(k)))
    img.alpha_composite(dock)
    x = dx + gap
    for i, n in enumerate(names):
        if n == "djos-launchpad":
            x += int(14 * k)   # separador antes del Launchpad y la papelera
            ImageDraw.Draw(img).line((x - 10 * k, dy + 14 * k, x - 10 * k, dy + dh - 14 * k),
                                     fill=(255, 255, 255, 60), width=max(1, int(k)))
        ic = icon(n, isz)
        if ic is not None:
            img.alpha_composite(ic, (x, dy + gap))
        if i in (0, 2, 3):   # puntito de "abierta"
            ImageDraw.Draw(img).ellipse((x + isz / 2 - 2 * k, dy + dh - 6 * k, x + isz / 2 + 2 * k, dy + dh - 2 * k),
                                        fill=(235, 235, 235, 230))
        x += isz + gap
    return img.convert("RGB")


def main():
    os.makedirs(AUR, exist_ok=True)
    act, W, H = decoration_canvas(True)
    ina, _, _ = decoration_canvas(False)
    with open(os.path.join(AUR, "decoration.svg"), "w") as f:
        f.write(frame_svg(act, ina, W, H))
    for kind in ("close", "minimize", "maximize", "restore"):
        with open(os.path.join(AUR, kind + ".svg"), "w") as f:
            f.write(button_svg(kind))

    with open(os.path.join(APPS, "djos-launchpad.svg"), "w") as f:
        f.write(launchpad_svg())

    os.makedirs(os.path.join(WALL, "contents/images"), exist_ok=True)
    big = wallpaper(3840, 2160)
    for w, h in ((1920, 1080), (1920, 1200), (2560, 1440), (3440, 1440), (3840, 2160)):
        im = big if (w, h) == (3840, 2160) else None
        if im is None:   # el mismo dibujo, recortado al formato de cada pantalla
            r = max(w / 3840, h / 2160)
            im = big.resize((round(3840 * r), round(2160 * r)), Image.LANCZOS)
            l, t = (im.width - w) // 2, (im.height - h) // 2
            im = im.crop((l, t, l + w, t + h))
        im.save(os.path.join(WALL, f"contents/images/{w}x{h}.jpg"), quality=90, optimize=True, progressive=True)
    big.resize((400, 225), Image.LANCZOS).save(os.path.join(WALL, "contents/screenshot.jpg"), quality=88)

    os.makedirs(LNF, exist_ok=True)
    preview(1920, 1080, big).save(os.path.join(LNF, "fullscreenpreview.jpg"), quality=88, optimize=True)
    preview(640, 360, big).save(os.path.join(LNF, "preview.png"), optimize=True)
    print("gen-glass: listo")


if __name__ == "__main__":
    main()
