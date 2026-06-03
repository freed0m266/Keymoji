#!/usr/bin/env python3
"""Generate a static dark-mode Kanban dashboard of the Keymoji task files.

Parses every `tasks/[0-9]*.md`, extracts a few lines of metadata (number,
title, status, priority/effort/impact, summary paragraph) with plain regex —
no markdown parser — and renders a single self-contained `tasks/dashboard.html`
(inline CSS + JS, no external assets). Run by hand after a larger task change;
the output is committed to git.

    python3 scripts/generate_dashboard.py            # regenerate + open
    python3 scripts/generate_dashboard.py --no-open  # regenerate only

The output is deterministic: same task data -> byte-identical HTML, so it stays
diff-friendly in git. No timestamps are embedded for that reason.
"""

import argparse
import html
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TASKS_DIR = REPO_ROOT / "tasks"

# --- separators / dashes seen in the source files -------------------------
MIDDOT = "·"          # · field separator on the Priorita line
DASHES = "—–-"   # em-dash, en-dash, hyphen (used interchangeably)

# Column definitions: (status key, display label, border-top accent color).
COLUMNS = [
    ("draft", "Draft", "#555"),
    ("todo", "Todo", "#5b9bd5"),
    ("done", "Done", "#6abf69"),
]

# Impact head word -> (css class suffix). Lookup is case-insensitive; the
# original (source-cased) head word is kept for display.
IMPACT_CLASS = {
    "blokující": "blocking",
    "high": "high",
    "medium": "medium",
    "low": "low",
    "none": "none",
}


# --------------------------------------------------------------------------
# Parsing
# --------------------------------------------------------------------------

def task_number(path):
    """Leading number from a `NN-slug.md` filename."""
    m = re.match(r"(\d+)-", path.name)
    if not m:
        raise SystemExit(f"Cannot parse task number from filename: {path}")
    return int(m.group(1))


def parse_title(lines, path):
    """`# NN — Title` -> 'Title'. Falls back to the filename slug."""
    for ln in lines:
        m = re.match(r"^#\s+\d+\s*[" + DASHES + r"]+\s*(.+?)\s*$", ln)
        if m:
            return m.group(1)
    sys.stderr.write(f"warning: no title heading in {path}\n")
    return path.stem


def parse_status(lines, path):
    """Return ('draft'|'todo'|'done', completion_date_or_None).

    Matches only the exact `**Status:**` line — files may also carry a
    `**Status (history):**` / `**Status (předchozí):**` line which must be
    ignored. An unrecognized status is a hard failure (better signal than a
    silent skip).
    """
    for ln in lines:
        m = re.match(r"^\s*\*\*Status:\*\*\s*(.*)$", ln)
        if not m:
            continue
        value = m.group(1).strip()
        if re.match(r"^Draft\b", value):
            return "draft", None
        if re.match(r"^Done\b", value):
            d = re.search(r"(\d{4}-\d{2}-\d{2})", value)
            if not d:
                raise SystemExit(
                    f"Malformed status in {path}:\n    {ln.strip()!r}\n"
                    f"A 'Done' status requires a completion date: 'Done — YYYY-MM-DD'."
                )
            return "done", d.group(1)
        if re.match(r"^Todo\b", value):
            return "todo", None
        raise SystemExit(
            f"Malformed status in {path}:\n    {ln.strip()!r}\n"
            f"Expected one of: 'Draft …', 'Todo …', 'Done — YYYY-MM-DD'."
        )
    raise SystemExit(f"No '**Status:**' line found in {path}")


def parse_meta(lines, path):
    """Parse the `**Priorita:** X · **Úsilí:** Y · **Dopad:** Z` line.

    Returns (priority_bucket, priority_display, effort, impact_class,
    impact_display). Missing/garbled lines warn and fall back to neutral
    defaults rather than crashing (only status is a hard requirement).
    """
    pat = (
        r"\*\*Priorita:\*\*\s*(.*?)\s*" + MIDDOT +
        r"\s*\*\*Úsilí:\*\*\s*(.*?)\s*" + MIDDOT +
        r"\s*\*\*Dopad:\*\*\s*(.*)$"
    )
    for ln in lines:
        m = re.search(pat, ln)
        if not m:
            continue
        prio_raw, effort_raw, impact_raw = (g.strip() for g in m.groups())

        # Priority bucket: a leading vMAJOR.MINOR collapses to that version,
        # everything else is the whole trimmed label.
        vm = re.match(r"(v\d+\.\d+)", prio_raw)
        bucket = vm.group(1) if vm else prio_raw

        # Effort: keep the single leading token (drops trailing parentheticals
        # like task 28's "S (designerská práce externí)").
        effort = effort_raw.split()[0] if effort_raw.split() else effort_raw

        # Impact: first word before any space/paren drives the color bucket.
        head_m = re.match(r"\s*([^\s(]+)", impact_raw)
        head = head_m.group(1) if head_m else impact_raw
        impact_class = IMPACT_CLASS.get(head.lower(), "none")

        return bucket, prio_raw, effort, impact_class, head

    sys.stderr.write(f"warning: no '**Priorita:**' line found in {path}\n")
    return "—", "", "", "none", ""


def strip_inline_markdown(text):
    """Flatten links, bold and inline code; collapse whitespace."""
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)  # [text](href) -> text
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)        # **x** -> x
    text = re.sub(r"`([^`]*)`", r"\1", text)              # `x` -> x
    return re.sub(r"\s+", " ", text).strip()


def truncate(text, limit=180):
    """Truncate to `limit` chars on a word boundary, appending an ellipsis."""
    if len(text) <= limit:
        return text
    cut = text[:limit]
    space = cut.rfind(" ")
    if space > 0:
        cut = cut[:space]
    return cut.rstrip() + "…"


def parse_summary(lines, path):
    """First non-empty paragraph under the first `## Cíl` or `## Souhrn`."""
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^##\s+(Cíl|Souhrn)\b", ln):
            start = i + 1
            break
    if start is None:
        sys.stderr.write(f"warning: no '## Cíl' or '## Souhrn' section in {path}\n")
        return ""
    j = start
    while j < len(lines) and not lines[j].strip():
        j += 1
    para = []
    while j < len(lines) and lines[j].strip():
        para.append(lines[j].strip())
        j += 1
    return truncate(strip_inline_markdown(" ".join(para)))


def parse_task(path):
    lines = path.read_text(encoding="utf-8").splitlines()
    bucket, prio_display, effort, impact_class, impact_display = parse_meta(lines, path)
    status, done_date = parse_status(lines, path)
    return {
        "number": task_number(path),
        "title": parse_title(lines, path),
        "status": status,
        "done_date": done_date,
        "bucket": bucket,
        "priority": prio_display,
        "effort": effort,
        "impact_class": impact_class,
        "impact": impact_display,
        "summary": parse_summary(lines, path),
    }


# --------------------------------------------------------------------------
# Sorting / grouping
# --------------------------------------------------------------------------

def bucket_sort_key(bucket):
    """Natural order: v1.0 < v1.1 < … < Tech debt < Pre-App-Store < other."""
    vm = re.match(r"v(\d+)\.(\d+)$", bucket)
    if vm:
        return (0, int(vm.group(1)), int(vm.group(2)), "")
    fixed = {"Tech debt": 1, "Pre-App-Store": 2}
    if bucket in fixed:
        return (fixed[bucket], 0, 0, "")
    return (3, 0, 0, bucket)


def is_version_bucket(bucket):
    return re.match(r"v\d+\.\d+$", bucket) is not None


def sorted_buckets(tasks):
    """Unique buckets present, in display order."""
    seen = {t["bucket"] for t in tasks}
    return sorted(seen, key=bucket_sort_key)


def column_tasks(tasks, status):
    items = [t for t in tasks if t["status"] == status]
    if status == "draft":
        return sorted(items, key=lambda t: t["number"])
    if status == "todo":
        return sorted(items, key=lambda t: (bucket_sort_key(t["bucket"]), t["number"]))
    # done: freshest completion first, newer task number breaks ties.
    return sorted(items, key=lambda t: (t["done_date"] or "", t["number"]), reverse=True)


# --------------------------------------------------------------------------
# HTML rendering
# --------------------------------------------------------------------------

CSS = """
:root { color-scheme: dark; }
* { box-sizing: border-box; }
html, body { background: #0a0a0a; margin: 0; }
body {
  color: #e5e5e5;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  font-size: 14px;
  line-height: 1.45;
}
.num, .progress-label, footer.done { font-family: ui-monospace, "SF Mono", Menlo, monospace; }

header.site {
  position: sticky;
  top: 0;
  z-index: 10;
  background: #0a0a0a;
  border-bottom: 1px solid #222;
  padding: 16px 20px;
}
header.site h1 { margin: 0 0 4px; font-size: 18px; font-weight: 600; }
.stats { color: #888; font-size: 13px; }
.stats .mono { font-family: ui-monospace, "SF Mono", Menlo, monospace; }

.progress-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 8px 20px;
  margin: 12px 0 4px;
}
.progress-row { display: flex; align-items: center; gap: 10px; }
.progress-track {
  flex: 1;
  height: 6px;
  background: #1c1c1c;
  border-radius: 999px;
  overflow: hidden;
}
.progress-fill { height: 100%; border-radius: 999px; }
.progress-label { font-size: 12px; color: #888; white-space: nowrap; }

.controls { display: flex; flex-direction: column; gap: 10px; margin-top: 14px; }
input[type="search"] {
  width: 100%;
  background: #141414;
  border: 1px solid #222;
  border-radius: 8px;
  color: #e5e5e5;
  font-size: 14px;
  padding: 8px 12px;
}
input[type="search"]::placeholder { color: #555; }
input[type="search"]:focus { outline: none; border-color: #3a3a3a; }

.filter-chips { display: flex; flex-wrap: wrap; gap: 6px; }
.filter-chips button {
  font: inherit;
  font-size: 11px;
  cursor: pointer;
  border-radius: 999px;
  padding: 3px 10px;
  border: 1px solid #333;
  background: transparent;
  color: #aaa;
}
.filter-chips button:hover { border-color: #444; }
.filter-chips button.active { background: #333; color: #fff; border-color: #333; }

main.board {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  padding: 20px;
  align-items: start;
}
@media (max-width: 900px) { main.board { grid-template-columns: 1fr; } }

.column { border-top: 2px solid #555; padding-top: 12px; }
.column[data-status="draft"] { border-top-color: #555; }
.column[data-status="todo"] { border-top-color: #5b9bd5; }
.column[data-status="done"] { border-top-color: #6abf69; }
.column h2 {
  margin: 0 0 12px;
  font-size: 13px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: #aaa;
}
.column h2 .count {
  color: #555;
  font-family: ui-monospace, "SF Mono", Menlo, monospace;
  margin-left: 4px;
}

.card {
  background: #141414;
  border: 1px solid #222;
  border-radius: 8px;
  padding: 14px;
  margin-bottom: 12px;
}
.card:hover { border-color: #333; }
.card[hidden] { display: none; }
.card > header { display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px; }
.card .num { color: #555; font-size: 12px; }
.card h3 { margin: 0; font-size: 14px; font-weight: 600; }

.badges { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.badge {
  border-radius: 999px;
  padding: 2px 8px;
  font-size: 11px;
  white-space: nowrap;
}
.badge.priority, .badge.effort { border: 1px solid #333; color: #aaa; }
.badge.impact-blocking { background: #5a1f1f; color: #ffb4b4; }
.badge.impact-high { background: #5a3a1f; color: #ffd4a8; }
.badge.impact-medium { background: #4a4a1f; color: #f0e0a0; }
.badge.impact-low,
.badge.impact-none { background: #2a2a2a; color: #888; }

.card .summary { margin: 0; color: #bbb; font-size: 13px; }
.card footer.done { margin-top: 10px; color: #6abf69; font-size: 11px; }
""".strip("\n")

JS = """
(function () {
  var search = document.getElementById("search");
  var chips = Array.prototype.slice.call(document.querySelectorAll(".filter-chips button"));
  var cards = Array.prototype.slice.call(document.querySelectorAll(".card"));
  var columns = Array.prototype.slice.call(document.querySelectorAll(".column"));
  var activeFilter = "all";

  function apply() {
    var q = search.value.trim().toLowerCase();
    cards.forEach(function (card) {
      var matchesSearch = !q || card.dataset.search.indexOf(q) !== -1;
      var matchesFilter = activeFilter === "all" || card.dataset.priority === activeFilter;
      card.hidden = !(matchesSearch && matchesFilter);
    });
    columns.forEach(function (col) {
      var visible = col.querySelectorAll(".card:not([hidden])").length;
      col.querySelector(".count").textContent = visible;
    });
  }

  search.addEventListener("input", apply);
  chips.forEach(function (chip) {
    chip.addEventListener("click", function () {
      chips.forEach(function (c) { c.classList.remove("active"); });
      chip.classList.add("active");
      activeFilter = chip.dataset.filter;
      apply();
    });
  });
})();
""".strip("\n")


def esc(text):
    return html.escape(str(text), quote=True)


def render_card(task):
    search_blob = (task["title"] + " " + task["summary"]).lower()
    parts = []
    parts.append(
        f'        <article class="card" data-priority="{esc(task["bucket"])}" '
        f'data-impact="{esc(task["impact_class"])}" data-search="{esc(search_blob)}">'
    )
    parts.append('          <header>')
    parts.append(f'            <span class="num">#{task["number"]:02d}</span>')
    parts.append(f'            <h3>{esc(task["title"])}</h3>')
    parts.append('          </header>')

    badges = []
    if task["priority"]:
        badges.append(f'            <span class="badge priority">{esc(task["priority"])}</span>')
    if task["effort"]:
        badges.append(f'            <span class="badge effort">{esc(task["effort"])}</span>')
    if task["impact"]:
        badges.append(
            f'            <span class="badge impact impact-{esc(task["impact_class"])}">'
            f'{esc(task["impact"])}</span>'
        )
    if badges:
        parts.append('          <div class="badges">')
        parts.extend(badges)
        parts.append('          </div>')

    if task["summary"]:
        parts.append(f'          <p class="summary">{esc(task["summary"])}</p>')
    if task["status"] == "done" and task["done_date"]:
        parts.append(f'          <footer class="done">Done {esc(task["done_date"])}</footer>')

    parts.append('        </article>')
    return "\n".join(parts)


def render_column(tasks, status, label):
    cards = column_tasks(tasks, status)
    lines = [
        f'      <section class="column" data-status="{status}">',
        f'        <h2>{label} <span class="count">{len(cards)}</span></h2>',
    ]
    lines.extend(render_card(t) for t in cards)
    lines.append('      </section>')
    return "\n".join(lines)


def render_progress(tasks):
    by_bucket_total = defaultdict(int)
    by_bucket_done = defaultdict(int)
    for t in tasks:
        by_bucket_total[t["bucket"]] += 1
        if t["status"] == "done":
            by_bucket_done[t["bucket"]] += 1

    rows = []
    for bucket in sorted_buckets(tasks):
        total = by_bucket_total[bucket]
        done = by_bucket_done[bucket]
        pct = round(done / total * 100) if total else 0
        color = "#6abf69" if is_version_bucket(bucket) else "#888"
        rows.append(
            '        <div class="progress-row">\n'
            '          <div class="progress-track">'
            f'<div class="progress-fill" style="width:{pct}%;background:{color}"></div></div>\n'
            f'          <span class="progress-label">{esc(bucket)} — {done}/{total} ({pct}%)</span>\n'
            '        </div>'
        )
    return "\n".join(rows)


def render_chips(tasks):
    chips = ['        <button data-filter="all" class="active">All</button>']
    for bucket in sorted_buckets(tasks):
        chips.append(f'        <button data-filter="{esc(bucket)}">{esc(bucket)}</button>')
    return "\n".join(chips)


def render_html(tasks):
    n_total = len(tasks)
    n_done = sum(1 for t in tasks if t["status"] == "done")
    n_todo = sum(1 for t in tasks if t["status"] == "todo")
    n_draft = sum(1 for t in tasks if t["status"] == "draft")

    columns = "\n".join(render_column(tasks, status, label) for status, label, _ in COLUMNS)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="dark">
  <title>Keymoji tasks</title>
  <style>
{CSS}
  </style>
</head>
<body>
  <header class="site">
    <h1>Keymoji tasks</h1>
    <div class="stats">
      <span class="mono">{n_total}</span> total ·
      <span class="mono">{n_done}</span> done ·
      <span class="mono">{n_todo}</span> todo ·
      <span class="mono">{n_draft}</span> draft
    </div>
    <div class="progress-grid">
{render_progress(tasks)}
    </div>
    <div class="controls">
      <input type="search" id="search" placeholder="Search title or summary…" autocomplete="off">
      <div class="filter-chips">
{render_chips(tasks)}
      </div>
    </div>
  </header>
  <main class="board">
{columns}
  </main>
  <script>
{JS}
  </script>
</body>
</html>
"""


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------

def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate the Keymoji task dashboard HTML.")
    parser.add_argument("--no-open", action="store_true", help="Skip opening in browser")
    parser.add_argument("--out", default=str(TASKS_DIR / "dashboard.html"),
                        help="Output path (default: tasks/dashboard.html)")
    args = parser.parse_args(argv)

    task_files = sorted(TASKS_DIR.glob("[0-9]*.md"), key=task_number)
    if not task_files:
        raise SystemExit(f"No task files found in {TASKS_DIR}")

    tasks = [parse_task(p) for p in task_files]
    document = render_html(tasks)

    out_path = Path(args.out)
    out_path.write_text(document, encoding="utf-8")

    n_total = len(tasks)
    n_done = sum(1 for t in tasks if t["status"] == "done")
    n_todo = sum(1 for t in tasks if t["status"] == "todo")
    n_draft = sum(1 for t in tasks if t["status"] == "draft")
    print(
        f"✓ Wrote {out_path} ({n_total} tasks: "
        f"{n_draft} draft, {n_todo} todo, {n_done} done)"
    )

    if not args.no_open:
        subprocess.run(["open", str(out_path)], check=False)


if __name__ == "__main__":
    main()
