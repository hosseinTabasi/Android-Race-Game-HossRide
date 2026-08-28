#!/usr/bin/env python3
"""
Builds the app icon set from a source photograph.

Android needs three separate images and they are not interchangeable:

  main_192x192      the legacy launcher icon, shown as-is on older Android
  adaptive_background   full-bleed, gets masked to whatever shape the
                        launcher uses (circle, squircle, rounded square)
  adaptive_foreground   ALSO masked, and more aggressively - only the centre
                        ~66% is guaranteed visible, because the launcher
                        parallaxes the layers independently

That safe-zone rule is why the foreground here is the subject scaled down
onto a transparent canvas rather than a full-bleed copy: a full-bleed
foreground would have the rider's head cropped off by the mask on most
launchers.

Usage:
    python tools/make_icons.py <source-image>
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"

# Fraction of the frame the adaptive foreground may safely occupy.
SAFE_ZONE = 0.66


def square_crop(img: Image.Image, focus_y: float = 0.38) -> Image.Image:
    """
    Crops to a square, centred horizontally and biased toward `focus_y`
    vertically so a portrait keeps the subject's head rather than their waist.
    """
    w, h = img.size
    side = min(w, h)

    left = (w - side) // 2
    centre = int(h * focus_y)
    top = max(0, min(centre - side // 2, h - side))

    return img.crop((left, top, left + side, top + side))


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: python tools/make_icons.py <source-image>")
        raise SystemExit(1)

    src_path = Path(sys.argv[1])
    if not src_path.exists():
        print(f"not found: {src_path}")
        raise SystemExit(1)

    OUT.mkdir(parents=True, exist_ok=True)
    src = Image.open(src_path).convert("RGB")
    print(f"source: {src_path.name}  {src.size[0]}x{src.size[1]}")

    subject = square_crop(src)

    # --- main / legacy icon ---------------------------------------------
    main_icon = subject.resize((512, 512), Image.LANCZOS)
    main_icon.save(OUT / "icon.png")
    print(f"  icon.png                     512x512")

    main_icon.resize((192, 192), Image.LANCZOS).save(OUT / "icon_192.png")
    print(f"  icon_192.png                 192x192")

    # --- adaptive background --------------------------------------------
    # Full bleed, slightly blurred and darkened. It sits behind the
    # foreground and is meant to read as colour and tone, not detail -
    # sharp detail in both layers just looks like a double exposure.
    bg = subject.resize((432, 432), Image.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(radius=7))
    bg = ImageEnhance.Brightness(bg).enhance(0.62)
    bg = ImageEnhance.Color(bg).enhance(0.85)
    bg.save(OUT / "icon_adaptive_bg.png")
    print(f"  icon_adaptive_bg.png         432x432  (blurred, darkened)")

    # --- adaptive foreground ---------------------------------------------
    # The subject, scaled into the safe zone on transparency.
    inner = int(432 * SAFE_ZONE)
    fg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    subj = subject.resize((inner, inner), Image.LANCZOS).convert("RGBA")

    # Round the corners a little so it doesn't read as a photo pasted on top.
    mask = Image.new("L", (inner, inner), 0)
    from PIL import ImageDraw

    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, inner - 1, inner - 1), radius=int(inner * 0.16), fill=255
    )
    subj.putalpha(mask)

    offset = (432 - inner) // 2
    fg.paste(subj, (offset, offset), subj)
    fg.save(OUT / "icon_adaptive_fg.png")
    print(f"  icon_adaptive_fg.png         432x432  (subject in safe zone)")

    print("\nDone.")


if __name__ == "__main__":
    main()
