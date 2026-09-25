"""Az épülethomlokzat ablaktextúráinak előállítása kódból (rajzfilmes stílus, vastag körvonallal).

Futtatás:  pip install pillow  →  python tools/generate_textures.py
Kimenet:   assets/textures/window_grey.png, window_lit.png (feltöltés után a Config.CITY.FACADE-be)

Egy csempe = egy emelet egy ablaka. A háttér átlátszó, így a fal színe (a festék) látszik mögötte.
A játék a csempét ismételve rakja ki a falakra (Texture), ezért a felső és alsó szélen nincs rajz.
"""

from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 256
SCALE = 4  # nagyobb méretben rajzolunk, aztán kicsinyítünk: simább élek
OUT = Path(__file__).resolve().parent.parent / "assets" / "textures"

OUTLINE = (45, 45, 58, 255)

STYLES = {
    # szürke (festetlen) állapot: sötét, kékes üveg, szürke keret
    "window_grey": {
        "frame": (196, 196, 202, 255),
        "sill": (170, 170, 178, 255),
        "glass": (82, 96, 118, 255),
        "glass_low": (66, 78, 98, 255),
        "shine": (138, 152, 172, 255),
    },
    # befestett állapot: meleg fényű ablak, krémfehér keret
    "window_lit": {
        "frame": (248, 243, 230, 255),
        "sill": (226, 218, 200, 255),
        "glass": (255, 222, 128, 255),
        "glass_low": (250, 190, 90, 255),
        "shine": (255, 246, 206, 255),
    },
}


def px(value):
    return int(value * SIZE * SCALE)


def draw_tile(style):
    img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    line = px(0.018)
    radius = px(0.03)

    # Árnyék a párkány alatt (félig átlátszó)
    d.rounded_rectangle([px(0.19), px(0.74), px(0.81), px(0.79)], radius=radius, fill=(0, 0, 0, 55))
    # Keret
    d.rounded_rectangle([px(0.24), px(0.14), px(0.76), px(0.70)], radius=radius, fill=style["frame"], outline=OUTLINE, width=line)
    # Üveg: felül világosabb, alul sötétebb sáv
    glass = [px(0.30), px(0.20), px(0.70), px(0.64)]
    d.rectangle(glass, fill=style["glass"], outline=OUTLINE, width=line // 2)
    d.rectangle([glass[0] + line // 2, px(0.50), glass[2] - line // 2, glass[3] - line // 2], fill=style["glass_low"])
    # Csillanás: két ferde csík
    for x0, w in [(0.36, 0.07), (0.47, 0.03)]:
        d.polygon(
            [(px(x0), px(0.62)), (px(x0 + w), px(0.62)), (px(x0 + w + 0.12), px(0.22)), (px(x0 + 0.12), px(0.22))],
            fill=style["shine"],
        )
    # Osztók (kereszt)
    d.rectangle([px(0.485), px(0.20), px(0.515), px(0.64)], fill=style["frame"], outline=OUTLINE, width=line // 2)
    d.rectangle([px(0.30), px(0.385), px(0.70), px(0.415)], fill=style["frame"], outline=OUTLINE, width=line // 2)
    # Párkány
    d.rounded_rectangle([px(0.19), px(0.69), px(0.81), px(0.75)], radius=radius // 2, fill=style["sill"], outline=OUTLINE, width=line)

    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, style in STYLES.items():
        path = OUT / f"{name}.png"
        draw_tile(style).save(path)
        print(path.name)


if __name__ == "__main__":
    main()
