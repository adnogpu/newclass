"""Extract one version section from CHANGELOG.md for CI release metadata."""

from __future__ import annotations

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: release_notes.py <version> [output]", file=sys.stderr)
        return 2
    version = sys.argv[1].strip()
    output = Path(sys.argv[2]) if len(sys.argv) > 2 else None
    changelog = Path("CHANGELOG.md")
    if not changelog.exists():
        print("CHANGELOG.md is missing", file=sys.stderr)
        return 1
    text = changelog.read_text(encoding="utf-8")
    pattern = re.compile(
        rf"^##\s+\[?{re.escape(version)}\]?(?:\s+-\s+.*)?\s*$"
        rf"(?P<body>.*?)(?=^##\s+|\Z)",
        re.MULTILINE | re.DOTALL,
    )
    match = pattern.search(text)
    body = match.group("body").strip() if match else ""
    if not body:
        print(f"no changelog section for version {version}", file=sys.stderr)
        return 1
    notes = body + "\n"
    if output is None:
        sys.stdout.write(notes)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(notes, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
