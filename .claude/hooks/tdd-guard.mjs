#!/usr/bin/env node
// TDD phase guard for Claude Code (PreToolUse on Edit|Write|MultiEdit|NotebookEdit).
// Reads the current phase from .tdd/phase and blocks edits that break the cycle:
//   red      -> only test files (plus docs/.tdd) may change
//   green    -> test files are frozen; only production code may change
//   refactor -> anything may change (the agent must keep the suite green)
//   off      -> guard disabled
// Exit 2 = block, stderr is fed back to the model.
import { readFileSync } from "node:fs";
import { join, relative, isAbsolute } from "node:path";

const root = process.env.CLAUDE_PROJECT_DIR || process.cwd();

let phase = "off";
try { phase = readFileSync(join(root, ".tdd/phase"), "utf8").trim().toLowerCase(); } catch {}
if (!["red", "green", "refactor"].includes(phase)) process.exit(0);

let input = {};
try { input = JSON.parse(readFileSync(0, "utf8") || "{}"); } catch { process.exit(0); }
const target = input?.tool_input?.file_path ?? input?.tool_input?.notebook_path;
if (!target) process.exit(0);

const rel = (isAbsolute(target) ? relative(root, target) : target).replaceAll("\\", "/");

// Override with TDD_TEST_PATTERN (a JS regex source) if your layout differs.
const TEST = new RegExp(
  process.env.TDD_TEST_PATTERN ||
    String.raw`(^|/)(tests?|__tests__|spec|e2e)/|[._-](test|spec)\.[^/]+$|(^|/)test_[^/]+\.py$|_test\.(go|py|rs|exs?)$|(^|/)(conftest\.py|vitest\.config\.\w+|jest\.config\.\w+|playwright\.config\.\w+)$`
);
const ALWAYS_OK = /^(\.tdd\/|docs\/|\.claude\/|CLAUDE\.md$|README)/;

if (ALWAYS_OK.test(rel)) process.exit(0);
const isTest = TEST.test(rel);

if (phase === "red" && !isTest) {
  console.error(
    `TDD guard [RED]: "${rel}" is production code. RED phase = write a failing test only. ` +
      `Run it, watch it fail for the right reason, then hand back to the orchestrator to switch to GREEN.`
  );
  process.exit(2);
}
if (phase === "green" && isTest) {
  console.error(
    `TDD guard [GREEN]: "${rel}" is a test file and is frozen during GREEN. ` +
      `Make the existing failing test pass with the minimum production code. If the test is wrong, report back instead of editing it.`
  );
  process.exit(2);
}
process.exit(0);
