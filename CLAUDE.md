# TDD orchestrator rules

This project uses Superpowers (workflow), Ponytail (minimal code) and Caveman (terse talk), coordinated by `/tdd`.

## Who owns what
- **Superpowers** owns the process: brainstorm → plan → RED/GREEN/REFACTOR → review → finish. Its TDD skill wins any conflict.
- **Ponytail** owns *how much code*: run the ladder before writing any production code. It never removes validation, error handling, auth or accessibility, and never removes tests.
- **Caveman** owns *how we talk*: subagent reports and orchestrator chatter are caveman. Code, comments, commit messages, plans, docs, security warnings and destructive-action confirmations are normal prose.

## Hard rules
- No production code without a failing test that demands it. The `.tdd/phase` guard enforces this; don't edit the phase file to get around a block — report it.
- One behaviour per test, one task per commit.
- Never `skip`, `xfail`, `.only`, or loosen an assertion to get green.
- A task is done only when the full suite was run and seen passing in this session.
- Outside `/tdd`, keep `.tdd/phase` at `off`.
- An empty graphify result means unknown, not absent. Confirm with Grep before deciding something doesn't exist.
