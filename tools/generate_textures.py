"""Az ablakképek előállítása kódból (rajzfilmes, de részletes stílus).

Futtatás:  pip install pillow  →  python tools/generate_textures.py
Kimenet:   assets/textures/*.png  (feltöltés után az azonosítók a Config.BUILDINGS.WINDOWS-ba és SHUTTERS-be)

Minden ablakkép egy átlátszó hátterű lap, amelyet a játék egy láthatatlan lapra tesz a fal elé (Decal).
A lap közepén van az ablak, a két szélén hely marad a zsalugátereknek: a zsalugáter egy külön kép
(shutters.png) ugyanazon a lapon, amelyet a játék a festék színére színez.

Változatok (mind szürke = festetlen, és kivilágított = befestett változatban):
  classic  négyosztatú ablak, belső árnyék, ég-tükröződés, kő szemöldök és párkány
  curtain  ugyanez függönnyel és virágládával
  tall     magas, íves tetejű ablak (templom, városháza)
"""

from pathlib import Path

from PIL import Image, ImageDraw

W = 256
SCALE = 4  # nagyobb méretben rajzolunk, aztán kicsinyítünk: simább élek
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"
OUTLINE = (45, 45, 58, 255)

PALETTES = {
    "grey": {
        "frame": (200, 200, 206, 255),
        "frame_dark": (160, 160, 168, 255),
        "stone": (178, 176, 172, 255),
        "glass_top": (120, 136, 158, 255),
        "glass_bottom": (70, 82, 102, 255),
        "shine": (170, 182, 200, 200),
        "inner_shadow": (40, 44, 56, 110),
        "curtain": (150, 150, 158, 255),
        "curtain_dark": (120, 120, 128, 255),
        "box": (130, 124, 118, 255),
        "flowers": [(170, 170, 176, 255), (200, 200, 204, 255), (150, 150, 156, 255)],
        "leaf": (120, 128, 118, 255),
    },
    "lit": {
        "frame": (250, 246, 234, 255),
        "frame_dark": (214, 204, 184, 255),
        "stone": (232, 220, 196, 255),
        "glass_top": (255, 236, 170, 255),
        "glass_bottom": (250, 182, 86, 255),
        "shine": (255, 250, 222, 220),
        "inner_shadow": (120, 70, 20, 90),
        "curtain": (214, 70, 70, 255),
        "curtain_dark": (170, 44, 50, 255),
        "box": (160, 100, 64, 255),
        "flowers": [(236, 84, 120, 255), (252, 206, 70, 255), (250, 250, 250, 255)],
        "leaf": (90, 160, 80, 255),
    },
}


def px(value, size):
    return int(value * size * SCALE)


def vertical_gradient(draw, box, top, bottom):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        t = (y - y0) / max(1, y1 - y0 - 1)
        color = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        draw.line([(x0, y), (x1 - 1, y)], fill=color)


def draw_window(pal, height, tall=False, curtain=False):
    """Egy ablak rajza. height: a kép magassága (W szélesség mellett)."""
    img = Image.new("RGBA", (W * SCALE, height * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    X = lambda v: px(v, W)  # noqa: E731
    Y = lambda v: px(v, height)  # noqa: E731
    line = X(0.016)

    frame = [X(0.25), Y(0.13), X(0.75), Y(0.70)]
    glass = [frame[0] + X(0.05), frame[1] + X(0.05), frame[2] - X(0.05), frame[3] - X(0.05)]
    arch_h = X(0.25) if tall else 0

    # Kő szemöldök (vagy ív) az ablak fölött
    if tall:
        d.pieslice([frame[0] - X(0.04), frame[1] - X(0.04), frame[2] + X(0.04), frame[1] + 2 * arch_h + X(0.04)],
                   180, 360, fill=pal["stone"], outline=OUTLINE, width=line)
    else:
        d.rounded_rectangle([frame[0] - X(0.05), frame[1] - X(0.07), frame[2] + X(0.05), frame[1] - X(0.005)],
                            radius=X(0.01), fill=pal["stone"], outline=OUTLINE, width=line)
        # zárókő középen
        d.polygon([(X(0.46), frame[1] - X(0.08)), (X(0.54), frame[1] - X(0.08)), (X(0.53), frame[1]), (X(0.47), frame[1])],
                  fill=pal["frame_dark"], outline=OUTLINE)

    # Árnyék a párkány alatt
    d.rectangle([frame[0] - X(0.05), frame[3] + X(0.035), frame[2] + X(0.05), frame[3] + X(0.07)], fill=(0, 0, 0, 50))

    # Keret (íves tetővel, ha magas)
    if tall:
        d.pieslice([frame[0], frame[1], frame[2], frame[1] + 2 * arch_h], 180, 360, fill=pal["frame"], outline=OUTLINE, width=line)
        d.rectangle([frame[0], frame[1] + arch_h, frame[2], frame[3]], fill=pal["frame"], outline=OUTLINE, width=line)
        d.line([(frame[0] + line, frame[1] + arch_h), (frame[2] - line, frame[1] + arch_h)], fill=pal["frame"], width=line * 2)
    else:
        d.rounded_rectangle(frame, radius=X(0.02), fill=pal["frame"], outline=OUTLINE, width=line)

    # Üveg: függőleges színátmenet (ég-tükröződés felül)
    glass_img = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass_img)
    vertical_gradient(gd, glass, pal["glass_top"], pal["glass_bottom"])
    if tall:
        gd.pieslice([glass[0], glass[1], glass[2], glass[1] + 2 * (arch_h - X(0.05))], 180, 360, fill=pal["glass_top"])
    # maszk: csak az üveg területe (íves tetővel)
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    if tall:
        md.pieslice([glass[0], glass[1], glass[2], glass[1] + 2 * (arch_h - X(0.05))], 180, 360, fill=255)
        md.rectangle([glass[0], glass[1] + arch_h - X(0.05), glass[2], glass[3]], fill=255)
    else:
        md.rectangle(glass, fill=255)
    # belső árnyék felül és bal oldalt (mélység)
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    sd.rectangle([glass[0], glass[1], glass[2], glass[1] + X(0.05)], fill=pal["inner_shadow"])
    sd.rectangle([glass[0], glass[1], glass[0] + X(0.04), glass[3]], fill=pal["inner_shadow"])
    glass_img = Image.alpha_composite(glass_img, shade)
    # függöny
    if curtain:
        cd = ImageDraw.Draw(glass_img)
        gw = glass[2] - glass[0]
        for side in (0, 1):
            x0 = glass[0] if side == 0 else glass[2] - int(gw * 0.3)
            x1 = x0 + int(gw * 0.3)
            cd.rectangle([x0, glass[1], x1, glass[3]], fill=pal["curtain"])
            for k in range(3):  # redők
                fx = x0 + int((k + 0.5) / 3 * (x1 - x0))
                cd.line([(fx, glass[1]), (fx, glass[3])], fill=pal["curtain_dark"], width=X(0.012))
        cd.rectangle([glass[0], glass[1], glass[2], glass[1] + X(0.04)], fill=pal["curtain_dark"])
    # csillanás
    sh = ImageDraw.Draw(glass_img)
    for x0, w in [(0.33, 0.06), (0.43, 0.025)]:
        sh.polygon([(X(x0), glass[3] - X(0.02)), (X(x0 + w), glass[3] - X(0.02)),
                    (X(x0 + w + 0.12), glass[1] + X(0.05)), (X(x0 + 0.12), glass[1] + X(0.05))], fill=pal["shine"])
    img.paste(glass_img, (0, 0), Image.composite(glass_img, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask).split()[3])

    # Osztók
    mid_x = (glass[0] + glass[2]) // 2
    bar = X(0.018)
    d.rectangle([mid_x - bar, glass[1] + (arch_h if tall else 0) - (X(0.05) if tall else 0), mid_x + bar, glass[3]],
                fill=pal["frame"], outline=OUTLINE, width=line // 2)
    cross_y = glass[1] + int((glass[3] - glass[1]) * (0.35 if tall else 0.45))
    d.rectangle([glass[0], cross_y - bar, glass[2], cross_y + bar], fill=pal["frame"], outline=OUTLINE, width=line // 2)
    d.rectangle(glass, outline=OUTLINE, width=line // 2) if not tall else None

    # Párkány
    d.rounded_rectangle([frame[0] - X(0.05), frame[3] - X(0.005), frame[2] + X(0.05), frame[3] + X(0.045)],
                        radius=X(0.01), fill=pal["stone"], outline=OUTLINE, width=line)

    # Virágláda a párkányon
    if curtain:
        box = [frame[0] - X(0.02), frame[3] + X(0.045), frame[2] + X(0.02), frame[3] + X(0.12)]
        for i in range(7):
            cx = box[0] + int((i + 0.5) / 7 * (box[2] - box[0]))
            r = X(0.035)
            d.ellipse([cx - r, box[1] - r - X(0.02), cx + r, box[1] + r - X(0.02)], fill=pal["leaf"], outline=OUTLINE, width=line // 2)
        for i in range(6):
            cx = box[0] + int((i + 1) / 7 * (box[2] - box[0]))
            r = X(0.025)
            d.ellipse([cx - r, box[1] - r - X(0.05), cx + r, box[1] + r - X(0.05)], fill=pal["flowers"][i % 3], outline=OUTLINE, width=line // 2)
        d.rounded_rectangle(box, radius=X(0.01), fill=pal["box"], outline=OUTLINE, width=line)

    return img.resize((W, height), Image.LANCZOS)


def draw_shutters(height):
    """Zsalugáterek a lap két szélén (fehér, a játék színezi); középen átlátszó."""
    img = Image.new("RGBA", (W * SCALE, height * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    X = lambda v: px(v, W)  # noqa: E731
    Y = lambda v: px(v, height)  # noqa: E731
    line = X(0.014)
    for x0, x1 in [(0.04, 0.23), (0.77, 0.96)]:
        box = [X(x0), Y(0.12), X(x1), Y(0.71)]
        d.rounded_rectangle(box, radius=X(0.01), fill=(250, 250, 250, 255), outline=OUTLINE, width=line)
        inner = [box[0] + X(0.025), box[1] + X(0.03), box[2] - X(0.025), box[3] - X(0.03)]
        d.rectangle(inner, fill=(226, 226, 226, 255), outline=(90, 90, 100, 255), width=line // 2)
        slats = 9
        for k in range(1, slats):
            y = inner[1] + int(k / slats * (inner[3] - inner[1]))
            d.line([(inner[0], y), (inner[2], y)], fill=(120, 120, 130, 255), width=line // 2)
    return img.resize((W, height), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for state, pal in PALETTES.items():
        draw_window(pal, W).save(OUT / f"window_classic_{state}.png")
        draw_window(pal, W, curtain=True).save(OUT / f"window_curtain_{state}.png")
        draw_window(pal, int(W * 1.5), tall=True).save(OUT / f"window_tall_{state}.png")
    draw_shutters(W).save(OUT / "shutters.png")
    for f in sorted(OUT.glob("*.png")):
        print(f.name)


if __name__ == "__main__":
    main()
