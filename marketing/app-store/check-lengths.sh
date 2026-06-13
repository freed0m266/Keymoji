#!/usr/bin/env bash
# Verify App Store metadata fields fit their character limits.
# Parses listing-en.md: every "## <field> (max N..." heading is
# followed by a fenced ``` block whose content is measured (Unicode code points,
# matching how App Store Connect counts characters).
#
# Usage: marketing/app-store/check-lengths.sh
# Exits non-zero if any field is over its limit.

set -euo pipefail
cd "$(dirname "$0")"

python3 - "$@" <<'PY'
import re, sys, glob

fail = 0
for path in sorted(glob.glob("listing-*.md")):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    print(f"\n== {path} ==")
    # Find "## Field (max N...)" then the next fenced block.
    for m in re.finditer(r"^##\s+(.*?)\(max\s+(\d+)[^\n]*\)\s*$", text, re.M):
        field = m.group(1).strip()
        limit = int(m.group(2))
        rest = text[m.end():]
        block = re.search(r"```[^\n]*\n(.*?)\n```", rest, re.S)
        if not block:
            print(f"  ?? {field}: no code block found")
            continue
        content = block.group(1)
        n = len(content)
        status = "OK " if n <= limit else "OVER"
        if n > limit:
            fail = 1
        print(f"  [{status}] {field}: {n}/{limit}")

sys.exit(fail)
PY
