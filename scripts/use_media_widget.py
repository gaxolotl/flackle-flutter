"""Switches image widgets to the media resolver and adds imports."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "lib"

IMPORTS = {
    "app.dart": "import 'core/media.dart';",
    "ui/common.dart": "import '../core/media.dart';",
}
DEFAULT_IMPORT = "import '../core/media.dart';"


def add_import(path: pathlib.Path, text: str) -> str:
    if "core/media.dart" in text:
        return text
    relative = path.relative_to(ROOT).as_posix()
    line = IMPORTS.get(relative, DEFAULT_IMPORT)
    marker = "import 'package:flutter/material.dart';"
    if marker in text:
        return text.replace(marker, f"{marker}\n\n{line}", 1)
    marker = "import 'package:flutter/foundation.dart';"
    if marker in text:
        return text.replace(marker, f"{marker}\n\n{line}", 1)
    return text


def main() -> None:
    updated = []
    for path in sorted(ROOT.rglob("*.dart")):
        if path.name == "media.dart":
            continue
        text = path.read_text(encoding="utf-8")
        if "Image.network(" not in text:
            continue
        lines = text.split("\n")
        changed = False
        for index, line in enumerate(lines):
            if "Image.network(" not in line:
                continue
            if "qrserver" in line or "return Image.network(value" in line:
                continue
            lines[index] = line.replace("Image.network(", "AppImage(")
            changed = True
        if not changed:
            continue
        text = "\n".join(lines)
        text = add_import(path, text)
        path.write_text(text, encoding="utf-8")
        updated.append(path.relative_to(ROOT).as_posix())
    print("updated:", updated)


if __name__ == "__main__":
    main()
