#!/usr/bin/env python3
"""Create deterministic Play Store brand assets from the approved app icon."""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = pathlib.Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "release" / "play-store"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(ROOT / path), size=size)


def feature_graphic() -> pathlib.Path:
    width, height = 1024, 500
    canvas = Image.new("RGB", (width, height), "#07080c")
    pixels = canvas.load()
    for y in range(height):
        for x in range(width):
            gold_glow = max(0.0, 1.0 - (((x - 260) / 430) ** 2 + ((y - 250) / 380) ** 2))
            teal_glow = max(0.0, 1.0 - (((x - 870) / 520) ** 2 + ((y - 520) / 460) ** 2))
            base = (7, 8, 12)
            pixels[x, y] = (
                min(255, int(base[0] + gold_glow * 17 + teal_glow * 0)),
                min(255, int(base[1] + gold_glow * 13 + teal_glow * 12)),
                min(255, int(base[2] + gold_glow * 5 + teal_glow * 14)),
            )

    icon = Image.open(ROOT / "assets" / "icon" / "app_icon.png").convert("RGB")
    icon = icon.resize((430, 430), Image.Resampling.LANCZOS)
    icon = icon.filter(ImageFilter.GaussianBlur(radius=0.2))
    canvas.paste(icon, (30, 35))

    draw = ImageDraw.Draw(canvas)
    gold = "#d6ad59"
    ivory = "#f5f1e8"
    muted = "#aaa8a5"
    draw.rounded_rectangle((490, 105, 563, 109), radius=2, fill=gold)
    draw.text((490, 132), "SILARAH", font=font("assets/fonts/Inter.ttf", 58), fill=ivory)
    draw.text(
        (493, 224),
        "MARRIAGE, WITH INTENTION",
        font=font("assets/fonts/Inter.ttf", 21),
        fill=gold,
    )
    draw.text(
        (493, 274),
        "Private Muslim matrimonial\nintroductions, thoughtfully made.",
        font=font("assets/fonts/PlayfairDisplay.ttf", 30),
        fill=muted,
        spacing=10,
    )

    OUTPUT.mkdir(parents=True, exist_ok=True)
    destination = OUTPUT / "feature-graphic-1024x500.png"
    canvas.save(destination, format="PNG", optimize=True)
    return destination


if __name__ == "__main__":
    print(feature_graphic())
