"""Generate launcher artwork from the same visual contract as the website.

Requires Pillow. The committed PNGs are the production outputs; this script
exists so the clean black-and-gold icon cannot accidentally be replaced by the
retired glossy mark.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SIZE = 1024
BACKGROUND = "#0A0A0D"
GOLD = "#D8AF55"
FONT_PATH = Path("C:/Windows/Fonts/arial.ttf")


def wordmark_s(*, transparent: bool) -> Image.Image:
    image = Image.new(
        "RGBA",
        (SIZE, SIZE),
        (0, 0, 0, 0) if transparent else BACKGROUND,
    )
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT_PATH), 690)
    bounds = draw.textbbox((0, 0), "S", font=font, stroke_width=0)
    width = bounds[2] - bounds[0]
    height = bounds[3] - bounds[1]
    position = (
        (SIZE - width) / 2 - bounds[0],
        (SIZE - height) / 2 - bounds[1] - 8,
    )
    draw.text(position, "S", font=font, fill=GOLD)
    return image


def save_resized(source: Image.Image, relative_path: str, size: int) -> None:
    destination = ROOT / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(destination)


def main() -> None:
    icon = wordmark_s(transparent=False)
    foreground = wordmark_s(transparent=True)
    save_resized(icon, "assets/icon/app_icon.png", SIZE)
    save_resized(foreground, "assets/icon/app_icon_foreground.png", SIZE)
    save_resized(icon, "web/favicon.png", 96)
    save_resized(icon, "web/icons/Icon-192.png", 192)
    save_resized(icon, "web/icons/Icon-512.png", 512)
    save_resized(icon, "web/icons/Icon-maskable-192.png", 192)
    save_resized(icon, "web/icons/Icon-maskable-512.png", 512)


if __name__ == "__main__":
    main()
