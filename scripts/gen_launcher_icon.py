# One-off generator for the AstrBot Android launcher icon (star on a warm
# yellow rounded square, matching dashboard/public/favicon.svg). Emits legacy
# mipmap PNGs plus adaptive-icon foreground layers.
from PIL import Image, ImageDraw
import os

RES = r"E:\vibe_coding_workspace\astrbot-mobile-dashboard\android\app\src\main\res"

BASE = (255, 236, 156)   # #FFEC9C
WARM = (255, 225, 97)    # #FFE161
RIM = (255, 245, 204)    # #FFF5CC
WHITE = (255, 255, 255)


def star_points(cx, cy, r_out, r_in_ratio=0.4):
    import math
    pts = []
    r_in = r_out * r_in_ratio
    for i in range(10):
        ang = math.radians(-90 + i * 36)
        r = r_out if i % 2 == 0 else r_in
        pts.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    return pts


def gradient_bg(size, top_left, bottom_right, radius_ratio=0.2):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    for y in range(size):
        for_x = y / max(size - 1, 1)
        r = int(top_left[0] + (bottom_right[0] - top_left[0]) * for_x)
        g = int(top_left[1] + (bottom_right[1] - top_left[1]) * for_x)
        b = int(top_left[2] + (bottom_right[2] - top_left[2]) * for_x)
        gd.line([(0, y), (size, y)], fill=(r, g, b, 255))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * radius_ratio), fill=255)
    img.paste(grad, (0, 0), mask)
    return img


def draw_star(size, star_ratio, with_rim=True):
    """Transparent canvas with the star; star_ratio = star outer diameter / size."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = cy = size / 2
    r_out = size * star_ratio / 2
    if with_rim:
        d.polygon(star_points(cx, cy, r_out * 1.045), fill=RIM + (255,))
    d.polygon(star_points(cx, cy, r_out), fill=WHITE + (255,))
    return layer


def build_legacy(size):
    img = gradient_bg(size, BASE, WARM)
    img.alpha_composite(draw_star(size, 0.72))
    return img


def build_foreground(size):
    # Adaptive icon: 108dp canvas, 66dp safe zone -> star diameter ~58%.
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    img.alpha_composite(draw_star(size, 0.58))
    return img


SS = 4  # supersample factor
legacy_src = build_legacy(48 * 10)   # high-res master
fg_src = build_foreground(108 * 8)

for dpi, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    out = os.path.join(RES, f"mipmap-{dpi}", "ic_launcher.png")
    legacy_src.resize((px, px), Image.LANCZOS).save(out)
    print("wrote", out)

for dpi, px in {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}.items():
    d = os.path.join(RES, f"mipmap-{dpi}")
    out = os.path.join(d, "ic_launcher_foreground.png")
    fg_src.resize((px, px), Image.LANCZOS).save(out)
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

with open(os.path.join(RES, "values", "ic_launcher_background.xml"), "w", newline="\n") as f:
    f.write(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<resources>\n"
        "    <color name=\"ic_launcher_background\">#FFEC9C</color>\n"
        "</resources>\n"
    )
print("wrote", os.path.join(RES, "values", "ic_launcher_background.xml"))
print("done")
