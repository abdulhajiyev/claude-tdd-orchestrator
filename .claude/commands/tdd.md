---
description: Run the TDD agent orchestrator (brainstorm → plan → RED/GREEN/REFACTOR per task) for a feature or bugfix
argument-hint: <docs/designs/....md | docs/plans/....md>
---

You are the TDD ORCHESTRATOR. You coordinate; you do not write tests or production code yourself. Subagents can't spawn subagents, so this loop runs here in the main thread.

Request: $ARGUMENTS

## 0. Setup
- `mkdir -p .tdd && echo off > .tdd/phase`, and add `.tdd/` to `.gitignore` if it isn't there (works the same whether the orchestrator was installed globally or into this project).
- `/caveman lite` for your own chat output. Code, commits, plans and anything sent to the user for a decision stay in normal prose.
- Detect the test runner and commands (package.json scripts, pyproject, go.mod, Cargo.toml, etc.). Record `TEST_ONE` (single test) and `TEST_ALL` (full suite) in `.tdd/state.md`. If you can't find them, ask once.
- Probe graphify: pick 2–3 real symbols or file names from this repo (`git ls-files | head`, an exported function) and query graphify for them.
  - Results that match this repo → write `GRAPHIFY: ok` in `.tdd/state.md`.
  - Errors, nothing found, or results from a different project → write `GRAPHIFY: off`, tell the user in one line that graphify has no graph for this project so the run uses text search only, and carry on. Don't stop the run for it.
  - Pass the `GRAPHIFY` value to every subagent you dispatch.
- Run `TEST_ALL`. If the suite is already red, stop and report — never start TDD on a red baseline.
- `echo off > .tdd/phase`

## 1. Design — done separately by `/tdd-design` (Claude Fable 5.2)
- `$ARGUMENTS` is a path under `docs/designs/` → read it, continue to step 2.
- `$ARGUMENTS` is a path under `docs/plans/` → read it, skip to step 3.
- Anything else (a plain description) → do NOT brainstorm here. Reply with one line: `Design first: /tdd-design $ARGUMENTS` and stop.
- Use `superpowers:using-git-worktrees` if the design has more than a couple of behaviours.

## 2. Plan (from the design doc)
- Use `superpowers:writing-plans`. Use the graphify MCP to resolve exact file paths, existing test locations and dependencies between tasks (order tasks so dependents come after what they depend on). Every task must be ONE behaviour, testable in isolation, with exact file paths for the test and the code.
- Run the plan through Ponytail: drop tasks that fail "does this need to exist?". Tests themselves are never dropped by YAGNI.
- Save to `docs/plans/<date>-<slug>.md`, mirror the task checklist in `.tdd/state.md`, show the user, wait for approval.

## 3. Loop — for each task, in order
1. **RED** — `echo red > .tdd/phase`, dispatch `tdd-red` with the task + `TEST_ONE`.
   - `already-passing` → mark task done-by-existing-code, next task.
   - `blocked` → stop, show the user.
2. **GREEN** — `echo green > .tdd/phase`, dispatch `tdd-green` with the test id, `TEST_ONE`, `TEST_ALL`.
   - `blocked` (test looks wrong) → back to RED once with the reason; second block → ask the user.
3. **REFACTOR** — `echo refactor > .tdd/phase`, dispatch `tdd-refactor` with task spec, `git diff`, `TEST_ALL`.
   - Critical/Important issues → new RED for a regression test if it's a behaviour bug, otherwise one more GREEN/REFACTOR pass. Max 2 rounds, then ask.
4. **Verify** — run `TEST_ALL` yourself (`superpowers:verification-before-completion`). Never trust a subagent's "green" without seeing output.
5. **Commit** — `echo off > .tdd/phase`, one commit per task: `test+feat: <behaviour>`. Tick the box in `.tdd/state.md`.

Independent tasks may run in parallel with `superpowers:dispatching-parallel-agents` only in separate worktrees — the phase file is per worktree.

## 4. Finish
- `echo off > .tdd/phase`
- `/ponytail-debt` to log deferred shortcuts.
- `superpowers:finishing-a-development-branch` for merge/PR.
- Final report to the user, normal prose: tasks done, test count before → after, anything deferred.
