"""Generate every web brand asset from the signed Android app icon.

The canonical source is ``assets/icon/app_icon.png``: the black handwritten
Silarah wordmark on white. Keeping one source prevents the marketing site,
Flutter web shell, and installed Android app from drifting into different
brands again.
"""

from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets/icon/app_icon.png"


def load_master() -> Image.Image:
    image = Image.open(MASTER).convert("RGBA")
    if image.width != image.height:
        raise ValueError("The canonical Silarah app icon must be square.")
    return image


def save_square(source: Image.Image, relative_path: str, size: int) -> None:
    destination = ROOT / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    source.resize((size, size), Image.Resampling.LANCZOS).save(destination)


def transparent_wordmark(source: Image.Image) -> Image.Image:
    luminance = source.convert("RGB").convert("L")
    alpha = ImageChops.invert(luminance)
    # Remove faint antialiasing residue in the white field while retaining the
    # smooth edge of the handwritten mark.
    alpha = alpha.point(lambda value: 0 if value < 8 else value)
    ink = Image.new("RGBA", source.size, (15, 22, 18, 0))
    ink.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("The canonical app icon contains no visible wordmark.")
    cropped = ink.crop(bounds)
    padding = max(16, cropped.height // 12)
    output = Image.new(
        "RGBA",
        (cropped.width + padding * 2, cropped.height + padding * 2),
        (0, 0, 0, 0),
    )
    output.alpha_composite(cropped, (padding, padding))
    return output


def save_wordmark(source: Image.Image, relative_path: str, width: int) -> None:
    height = round(source.height * (width / source.width))
    destination = ROOT / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    source.resize((width, height), Image.Resampling.LANCZOS).save(destination)


def save_favicon(source: Image.Image, relative_path: str) -> None:
    destination = ROOT / relative_path
    destination.parent.mkdir(parents=True, exist_ok=True)
    source.save(destination, sizes=[(16, 16), (32, 32), (48, 48)])


def main() -> None:
    master = load_master()
    wordmark = transparent_wordmark(master)

    for relative_path, size in (
        ("site/assets/silarah-app-icon-v2.png", 512),
        ("site/favicon-48.png", 48),
        ("site/favicon-96.png", 96),
        ("site/apple-touch-icon.png", 180),
        ("web/favicon.png", 96),
        ("web/icons/Icon-192.png", 192),
        ("web/icons/Icon-512.png", 512),
        ("web/icons/Icon-maskable-192.png", 192),
        ("web/icons/Icon-maskable-512.png", 512),
        ("site-app/assets/silarah-app-icon-v2.png", 512),
        ("site-app/favicon-48.png", 48),
        ("site-app/apple-touch-icon.png", 180),
    ):
        save_square(master, relative_path, size)

    save_wordmark(wordmark, "site/assets/silarah-wordmark-v2.png", 640)
    save_wordmark(wordmark, "site-app/assets/silarah-wordmark-v2.png", 640)
    save_favicon(master, "site/favicon.ico")
    save_favicon(master, "site-app/favicon.ico")


if __name__ == "__main__":
    main()
