---
description: Start working on a numbered task from the tasks/ folder (Codex review runs by default)
argument-hint: <number> [--skip-review]
---

Start working on the task numbered `$1` from the `tasks/` folder.

**Codex review** runs automatically at the end of the task (step 8). Pass `--skip-review` (or `-s`) as any argument after the number to skip it — useful for purely mechanical scaffolding tasks. Default (`/task <number>` with no extra flag) always reviews.

Steps:
1. Normalize the input: `$1` may be given as `2` or `02` — both refer to the file prefixed with `02-`. Strip leading zeros, then match `tasks/<n>-*.md` or `tasks/0<n>-*.md`.
2. If no file matches, list available tasks (`ls tasks/`) and stop.
3. Read the matched task file fully.
4. Read `CLAUDE.md` and any other relevant files referenced in the task's scope so you have enough context.
5. Briefly confirm understanding: one or two sentences summarizing the goal and any open questions. If the scope has ambiguity that affects implementation, ask before coding.
6. Create a new git branch for the task before making any changes. Naming convention: `feature/<zero-padded-number>-<short-kebab-slug>` derived from the task filename (e.g. task `02-fiat-currency-selection.md` → `feature/02-fiat-currency-selection`). Branch off from `main`. If the branch already exists, check it out instead of recreating it. If the working tree is dirty, stop and ask the user how to proceed before switching branches.
7. Begin implementation. Follow the project's conventions (MVVM, protocol-first, `@Observable`, DI via `AppDependency`, mocks under `Testing/`, `#if DEBUG` for previews, etc.).
8. **Codex closing code review** — runs by default. Skip this step **only** if any argument after the task number is `--skip-review` or `-s`.
   - Stage the changes (`git add ...`).
   - Run `codex review --uncommitted` on the staged diff. Codex defaults to `gpt-5.5` with `model_reasoning_effort = "xhigh"` (configured in `~/.codex/config.toml`) — no flags needed.
   - Wait for it to finish, then read the findings:
     - **Apply** findings that identify real bugs, missing edge cases, concurrency or memory issues, incorrect API usage, or substantially better designs that fit the project's conventions. Re-run tests after each applied finding.
     - **Skip** findings that are off-base, context-unaware, suggest features outside the task's scope, contradict an explicit decision already taken, or are clearly hallucinations (e.g. claiming code won't compile when tests just passed). Note the reason briefly when reporting.
     - **Pause and ask the user** if a finding has security or data-loss implications, or if you're genuinely unsure whether it should land.
   - If Codex times out, returns nothing, or repeatedly produces nonsense, log that and continue without the review for this task.
   - When reporting back, summarize: "Codex found N findings — applied P (list them), skipped S (list them + why)."
9. After applying accepted findings and re-running tests, mark the task done by appending `**Status:** Done — <date>` at the top of the task file (don't delete the file).

Do not commit changes unless explicitly asked.
