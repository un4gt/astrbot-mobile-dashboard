# Regenerates the Android launcher icons from assets/icon.png.
#
# - legacy ic_launcher.png: the source image scaled to each density
# - adaptive icon foreground: the source image scaled into the 66dp safe
#   zone of the 108dp canvas (edges cropped by launchers stay clean)
# - adaptive background color: sampled from the image's top-left corner
import os

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
SRC = os.path.join(ROOT, "assets", "icon.png")

# 108dp adaptive canvas; visible safe zone is the center 66dp.
CANVAS_DP = 108
SAFE_DP = 66


def load_source():
    img = Image.open(SRC).convert("RGBA")
    # Trim fully-transparent border so the artwork, not empty space, fills
    # the safe zone.
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    return img


def build_legacy(src):
    return src


def build_foreground(src):
    canvas = Image.new("RGBA", (CANVAS_DP * 8, CANVAS_DP * 8), (0, 0, 0, 0))
    safe = canvas.width * SAFE_DP / CANVAS_DP
    fg = src.resize((int(safe), int(safe)), Image.LANCZOS)
    canvas.alpha_composite(fg, ((canvas.width - fg.width) // 2,
                                (canvas.height - fg.height) // 2))
    return canvas


def background_color(src):
    # Corner pixel of the (bbox-trimmed) artwork; fall back to a soft yellow.
    r, g, b, _ = src.getpixel((0, 0))
    return f"#{r:02X}{g:02X}{b:02X}" if (r or g or b) else "#FFEC9C"


def main():
    src = load_source()
    legacy = build_legacy(src)
    fg = build_foreground(src)
    bg = background_color(src)
    print(f"source {src.size}, background {bg}")

    for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                    "xxhdpi": 144, "xxxhdpi": 192}.items():
        out = os.path.join(RES, f"mipmap-{dpi}", "ic_launcher.png")
        legacy.resize((px, px), Image.LANCZOS).save(out)
        print("wrote", out)

    for dpi, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216,
                    "xxhdpi": 324, "xxxhdpi": 432}.items():
        out = os.path.join(RES, f"mipmap-{dpi}", "ic_launcher_foreground.png")
        fg.resize((px, px), Image.LANCZOS).save(out)
        print("wrote", out)

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", newline="\n") as f:
        f.write(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
            "<adaptive-icon xmlns:android=\"http://schemas.android.com/apk/res/android\">\n"
            "    <background android:drawable=\"@color/ic_launcher_background\"/>\n"
            "    <foreground android:drawable=\"@mipmap/ic_launcher_foreground\"/>\n"
            "</adaptive-icon>\n"
        )
    print("wrote", os.path.join(anydpi, "ic_launcher.xml"))

    with open(os.path.join(RES, "values", "ic_launcher_background.xml"),
              "w", newline="\n") as f:
        f.write(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
            "<resources>\n"
            f"    <color name=\"ic_launcher_background\">{bg}</color>\n"
            "</resources>\n"
        )
    print("wrote", os.path.join(RES, "values", "ic_launcher_background.xml"))
    print("done")


if __name__ == "__main__":
    main()
