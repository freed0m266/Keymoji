---
name: task
description: Start work on a numbered Keymoji task from tasks/. Use when the user writes "/task <number>", optionally with "--skip-review" or "-s". Implements the task in this repo, then runs a Claude closing review by default.
---

# Keymoji Task

Work on a numbered task from the Keymoji `tasks/` folder.

`/task <number>` runs the task and then asks Claude to review the staged changes.
`/task <number> --skip-review` or `/task <number> -s` skips the closing review.

## Workflow

1. Parse the first argument as the task number. Accept both `2` and `02`.
2. Strip leading zeros and match either `tasks/<n>-*.md` or `tasks/0<n>-*.md`.
3. If no file matches, list available tasks with `ls tasks/` and stop.
4. Read the matched task file fully.
5. Read `AGENTS.md`, `CLAUDE.md`, and any files referenced by the task scope so there is enough
   context to implement safely.
6. Briefly confirm understanding in one or two sentences, including any open questions. If scope
   ambiguity affects implementation, ask before coding.
7. Create or switch to a branch before making task changes.
   - Branch naming convention: `feature/<zero-padded-number>-<short-kebab-slug>` derived from the
     task filename, for example `tasks/02-fiat-currency-selection.md` becomes
     `feature/02-fiat-currency-selection`.
   - Branch from `main`.
   - If the branch already exists, switch to it.
   - If the working tree is dirty before switching, stop and ask the user how to proceed.
8. Implement the task.
   - Follow Keymoji conventions in `AGENTS.md`.
   - Respect task Scope, Mimo scope, Hotovo kdyz, Rizika, and Reference sections.
   - Add or update focused tests/snapshots according to the touched target.
   - Run relevant verification.
9. Unless `--skip-review` or `-s` was passed, run the Claude closing review.
10. After accepted review findings are handled and tests are re-run, mark the task done by appending
    `**Status:** Done - <YYYY-MM-DD>` near the top of the task file. Do not delete the task file.

Do not commit changes unless the user explicitly asks.

## Claude Closing Review

The review is done by Claude, not Codex.

1. Stage the task changes with `git add ...`.
2. Run a non-interactive Claude review of the staged diff from the repo root. Use a command like:

```bash
claude -p 'Review the staged diff in this repository. Focus on real bugs, missing edge cases, concurrency or memory issues, incorrect API usage, privacy regressions, extension-safety issues, and designs that conflict with the existing Keymoji architecture. Base findings only on the staged diff and repository context. Do not edit files. Return findings with severity, file/line when possible, rationale, and suggested fix. If there are no actionable findings, say so clearly.' \
  --allowedTools 'Bash(git diff:*),Bash(git status:*),Bash(git log:*),Read' \
  --permission-mode dontAsk
```

3. Wait for Claude to finish and triage the findings:
   - Apply findings that identify real bugs, missing edge cases, concurrency or memory issues,
     incorrect API usage, privacy/extension-safety regressions, or substantially better designs
     that fit the task and project conventions.
   - Skip findings that are off-base, context-unaware, outside task scope, contradict an explicit
     decision, or are clearly hallucinated.
   - Pause and ask the user if a finding has security/data-loss implications or if it is genuinely
     unclear whether it should land.
4. Re-run relevant tests after applying any finding.
5. If Claude times out, returns nothing useful, or is unavailable, report that and continue without
   applying review changes.
6. Report back with: `Claude found N findings - applied P (...), skipped S (...).`

