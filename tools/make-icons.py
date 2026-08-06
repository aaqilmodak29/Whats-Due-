#!/usr/bin/env python3
"""Generates the app icon for every platform from one definition.

The mark is the one the original web app already used on the owner's home
screen: an assignment card — highlighter spine, three ink rules of decreasing
length, one red square. It is redrawn here rather than upscaled, because the
committed original was a 180px PNG and enlarging it produced soft edges.

Every size is drawn natively at its target resolution instead of being
downsampled from a master, so edges stay crisp at 48px where most icons turn to
mush.

    python tools/make-icons.py

Requires Pillow. Writes into app/android, app/web, app/windows and app/ios.
"""

from __future__ import annotations

import pathlib
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("Pillow is required:  python -m pip install pillow")

REPO = pathlib.Path(__file__).resolve().parent.parent
APP = REPO / "app"

INK = (0x16, 0x20, 0x2E)
CARD = (0xFF, 0xFF, 0xFF)
MARK = (0xDC, 0xEE, 0x3A)
RED = (0xFF, 0x3B, 0x1F)


def draw_icon(size: int, *, art_scale: float = 1.0, background=INK) -> Image.Image:
    """The mark at `size` px.

    `art_scale` shrinks the card within the canvas, which is what Android's
    adaptive icons and the web's maskable icons need — both crop the outer edge,
    so content has to sit inside a safe zone rather than run to the border.
    `background=None` gives a transparent canvas for the adaptive foreground
    layer, where the background is a separate solid colour.
    """
    # Supersample, then reduce once. Drawing directly at 48px would land
    # rectangle edges on fractional pixels; this keeps them clean.
    ss = 8
    canvas = size * ss
    im = Image.new("RGBA", (canvas, canvas), (*background, 255) if background else (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    def px(fraction: float) -> float:
        """Fraction of the canvas, with the card art scaled about the centre."""
        return (0.5 + (fraction - 0.5) * art_scale) * canvas

    # Card. Proportions follow the original: a wide landscape card with a
    # generous margin, sitting slightly above centre.
    card = (px(0.1875), px(0.2188), px(0.8125), px(0.7813))
    d.rectangle(card, fill=CARD)

    # Highlighter spine down the left edge.
    d.rectangle((px(0.1875), px(0.2188), px(0.2344), px(0.7813)), fill=MARK)

    # Three ink rules, decreasing in length, like lines of a title.
    for top, right in ((0.3125, 0.7031), (0.4297, 0.6172), (0.5469, 0.5547)):
        d.rectangle(
            (px(0.2930), px(top), px(right), px(top + 0.0391)), fill=INK
        )

    # The red-pen mark: overdue, bottom right.
    d.rectangle((px(0.7031), px(0.6445), px(0.7656), px(0.7070)), fill=RED)

    return im.resize((size, size), Image.LANCZOS)


def write(path: pathlib.Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)
    print(f"  {path.relative_to(REPO)}  ({im.width}x{im.height})")


def main() -> None:
    print("Android launcher icons")
    # Legacy square icons, full bleed.
    for folder, s in (
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ):
        write(
            APP / "android/app/src/main/res" / folder / "ic_launcher.png",
            draw_icon(s).convert("RGB"),
        )

    print("Android adaptive foreground (108dp, card inside the 66% safe zone)")
    for folder, s in (
        ("mipmap-mdpi", 108),
        ("mipmap-hdpi", 162),
        ("mipmap-xhdpi", 216),
        ("mipmap-xxhdpi", 324),
        ("mipmap-xxxhdpi", 432),
    ):
        # 0.70 is the largest the card can be and still survive a circular
        # mask. Android guarantees only the inner 66dp of the 108dp canvas, so
        # the binding constraint is the card's *corners*, not its width: at
        # native proportions they sit 0.42 canvas-widths from the centre, and
        # 0.42 x 0.70 = 0.295, just inside the 0.306 safe radius.
        write(
            APP / "android/app/src/main/res" / folder / "ic_launcher_foreground.png",
            draw_icon(s, art_scale=0.70, background=None),
        )

    res = APP / "android/app/src/main/res"
    (res / "mipmap-anydpi-v26").mkdir(parents=True, exist_ok=True)
    (res / "mipmap-anydpi-v26/ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        "    <!-- No <monochrome> layer on purpose. Android 13+ themed icons\n"
        "         expect a single-colour silhouette, and pointing it at this\n"
        "         full-colour foreground would flatten the card, spine and red\n"
        "         mark into one indistinct blob. Without it the launcher keeps\n"
        "         using the normal adaptive icon, which is the better result. -->\n"
        "</adaptive-icon>\n",
        encoding="utf-8",
    )
    print("  res/mipmap-anydpi-v26/ic_launcher.xml")

    (res / "values").mkdir(parents=True, exist_ok=True)
    (res / "values/ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<resources>\n"
        '    <color name="ic_launcher_background">#16202E</color>\n'
        "</resources>\n",
        encoding="utf-8",
    )
    print("  res/values/ic_launcher_background.xml")

    print("Web")
    web = APP / "web"
    write(web / "favicon.png", draw_icon(32).convert("RGB"))
    write(web / "icons/Icon-192.png", draw_icon(192).convert("RGB"))
    write(web / "icons/Icon-512.png", draw_icon(512).convert("RGB"))
    # Maskable icons get cropped to a circle by some launchers, so the card has
    # to sit well inside the frame.
    write(web / "icons/Icon-maskable-192.png", draw_icon(192, art_scale=0.7).convert("RGB"))
    write(web / "icons/Icon-maskable-512.png", draw_icon(512, art_scale=0.7).convert("RGB"))

    print("Windows")
    ico = APP / "windows/runner/resources/app_icon.ico"
    ico.parent.mkdir(parents=True, exist_ok=True)
    # A multi-resolution .ico; Windows picks per context (taskbar, alt-tab,
    # Explorer at various zoom levels).
    sizes = [16, 24, 32, 48, 64, 128, 256]
    draw_icon(256).convert("RGB").save(
        ico, format="ICO", sizes=[(s, s) for s in sizes]
    )
    print(f"  {ico.relative_to(REPO)}  ({', '.join(f'{s}x{s}' for s in sizes)})")

    print("iOS")
    ios = APP / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    if ios.is_dir():
        # Replace each existing slot at its own size; the contents.json that
        # ships with the Flutter template already references these filenames.
        for existing in sorted(ios.glob("*.png")):
            with Image.open(existing) as current:
                s = current.width
            write(existing, draw_icon(s).convert("RGB"))
    else:
        print("  (skipped — no iOS project)")

    print("\nPreview")
    out = REPO / "tools/icon-preview.png"
    strip = Image.new("RGB", (16 + (192 + 16) * 3, 224), (0xE3, 0xE8, 0xED))
    for i, s in enumerate((192, 96, 48)):
        icon = draw_icon(s).convert("RGB")
        strip.paste(icon, (16 + (192 + 16) * i, 16 + (192 - s) // 2))
    write(out, strip)


if __name__ == "__main__":
    main()
