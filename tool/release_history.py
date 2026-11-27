"""Extract every version section from CHANGELOG.md as JSON history."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_HEADING = re.compile(
    r"^##[ \t]+\[?(\d+\.\d+\.\d+)\]?(?:[ \t]+-[ \t]+.*)?[ \t]*$",
    re.MULTILINE,
)


def parse_history(text: str) -> list[dict[str, str]]:
    matches = list(_HEADING.finditer(text))
    entries: list[dict[str, str]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        notes = text[match.end() : end].strip()
        if not notes:
            continue
        entries.append(
            {
                "versionName": match.group(1),
                "notes": notes,
            }
        )
    return entries


def main() -> int:
    changelog = Path("CHANGELOG.md")
    if not changelog.exists():
        print("CHANGELOG.md is missing", file=sys.stderr)
        return 1
    history = parse_history(changelog.read_text(encoding="utf-8"))
    if not history:
        print("no released versions found in CHANGELOG.md", file=sys.stderr)
        return 1
    encoded = json.dumps(history, ensure_ascii=False, indent=2) + "\n"
    if len(sys.argv) < 2:
        sys.stdout.write(encoded)
    else:
        output = Path(sys.argv[1])
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
