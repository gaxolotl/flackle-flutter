"""Converts the desktop client's woff2 fonts to TrueType for Flutter."""
import pathlib
import sys

from fontTools.ttLib import TTFont

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "public" / "fonts"
TARGET = pathlib.Path(__file__).resolve().parents[1] / "assets" / "fonts"


def main() -> int:
    TARGET.mkdir(parents=True, exist_ok=True)
    for source in sorted(SOURCE.glob("*.woff2")):
        target = TARGET / f"{source.stem}.ttf"
        font = TTFont(source)
        font.flavor = None
        font.save(target)
        font.close()
        print(f"font: {source.name} -> {target.name} ({target.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
