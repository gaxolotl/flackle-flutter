"""Repairs UI strings corrupted by a legacy-encoding round trip and normalises
typography to ASCII so later edits cannot reintroduce mojibake."""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1] / "lib"

PUNCTUATION = {
    "\u2014": " - ",
    "\u2013": " - ",
    "\u2026": "...",
    "\u2018": "'",
    "\u2019": "'",
    "\u201c": '"',
    "\u201d": '"',
    "\u00d7": "x",
    "\u2192": "->",
    "\u21b3": "Reply to ",
    "\u2318": "Ctrl+",
    "\u00a0": " ",
    "\ufeff": "",
}

# Lines that cannot be recovered by the CP1251 round trip are rewritten here.
MANUAL = [
    (
        "screens/chat_view.dart",
        "for (final emoji in const",
        "            for (final emoji in const ['\\u{1F44D}', '\\u{2764}\\u{FE0F}', '\\u{1F602}']))",
    ),
    (
        "screens/workspace_screen.dart",
        "K',",
        "                    child: Text('Ctrl K',",
    ),
]


def is_corrupt(line: str) -> bool:
    for ch in line:
        code = ord(ch)
        if 0x0400 <= code <= 0x04FF:
            return True
        if ch == "\ufffd" or 0x80 <= code <= 0x9F:
            return True
        if 0x2500 <= code <= 0x25FF and ch not in "\u2500\u2502":
            return True
    return False


def round_trip(line: str) -> str | None:
    try:
        raw = line.encode("cp1251")
    except UnicodeEncodeError:
        return None
    try:
        fixed = raw.decode("utf-8")
    except UnicodeDecodeError:
        return None
    if "\ufffd" in fixed:
        return None
    return fixed


def normalise(line: str) -> str:
    for source, target in PUNCTUATION.items():
        line = line.replace(source, target)
    return line


def repair_file(path: pathlib.Path) -> int:
    text = path.read_text(encoding="utf-8", errors="replace")
    changed = 0
    lines = text.split("\n")
    relative = path.relative_to(ROOT).as_posix()
    for index, line in enumerate(lines):
        if not is_corrupt(line):
            continue
        replaced = False
        for file_suffix, needle, replacement in MANUAL:
            if relative.endswith(file_suffix) and needle in line:
                lines[index] = replacement
                changed += 1
                replaced = True
                break
        if replaced:
            continue
        fixed = round_trip(line)
        if fixed is None:
            # Strip unrecoverable runs, keeping the rest of the literal intact.
            fixed = re.sub(r"[^\x00-\x7F]+", "-", line)
        lines[index] = normalise(fixed)
        changed += 1

    result = normalise("\n".join(lines))
    path.write_text(result, encoding="utf-8", newline="\n")
    return changed


def main() -> int:
    total = 0
    for path in sorted(ROOT.rglob("*.dart")):
        total += repair_file(path)
    print(f"repaired {total} lines")
    leftovers = []
    for path in ROOT.rglob("*.dart"):
        for index, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            if is_corrupt(line):
                leftovers.append(f"{path.relative_to(ROOT)}:{index}")
    print("leftovers:", leftovers[:20], "count", len(leftovers))
    return 0


if __name__ == "__main__":
    sys.exit(main())
