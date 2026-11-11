# claude-tdd-orchestrator

A strict test-driven development loop for **Claude Code**, built from three community plugins and one MCP server:

| Piece | Role in the loop |
|---|---|
| [Superpowers](https://github.com/obra/superpowers) | The process: brainstorm → plan → RED / GREEN / REFACTOR → review → finish |
| [Ponytail](https://github.com/DietrichGebert/ponytail) | How much code: the "lazy senior dev" ladder (YAGNI → reuse → stdlib → … → minimum), never at the cost of safety |
| [Caveman](https://github.com/JuliusBrussee/caveman) | How agents talk: terse reports between agents to save tokens; code, commits and decisions stay in normal prose |
| graphify MCP (`https://graphify-mcp.hajiyev.space/mcp`) | Code structure: modules, callers, existing tests, so each stage reads the right code |

On top of those, this repo adds a coordinator command, three phase agents, and an **edit guard** that makes skipping TDD impossible rather than merely discouraged.

---

## How it works

```
/tdd-design <feature>          Claude Fable 5.2 + superpowers:brainstorming
   │                           graphify-grounded questions, one at a time
   ▼                           → docs/designs/<date>-<slug>.md
/tdd docs/designs/<file>.md    coordinator (your session model)
   │  setup: detect test commands, probe graphify, refuse a red baseline
   │  plan:  superpowers:writing-plans, trimmed by Ponytail → docs/plans/
   ▼
   for each task (one behaviour):
     RED       tdd-red       (Sonnet)  one failing test, proven to fail for the right reason
     GREEN     tdd-green     (Sonnet)  least code that passes, via the Ponytail ladder
     REFACTOR  tdd-refactor  (Opus)    cleanup + two-pass review (spec, then quality)
     VERIFY    coordinator             runs the full suite itself
     COMMIT    one commit per task
   ▼
   finish: /ponytail-debt, superpowers:finishing-a-development-branch, summary
```

### The edit guard

`hooks/tdd-guard.mjs` runs before every `Edit` / `Write` / `MultiEdit` / `NotebookEdit` and reads the current phase from `.tdd/phase`:

| Phase | Test files | Production code |
|---|---|---|
| `red` | editable | **blocked** |
| `green` | **blocked** (frozen) | editable |
| `refactor` | editable | editable (suite must stay green) |
| `off` / missing | editable | editable |

`docs/`, `.tdd/`, `.claude/`, `CLAUDE.md` and READMEs are always editable. Blocked edits return the reason to the agent, which then reports back instead of working around it.

Test files are recognised by common conventions: `test/`, `tests/`, `__tests__/`, `spec/`, `e2e/` folders; `*.test.*`, `*.spec.*`; `test_*.py`; `*_test.go|py|rs|ex|exs`; plus `conftest.py` and Jest/Vitest/Playwright configs. Override with `TDD_TEST_PATTERN` (see Tuning).

### Models

| Where | Model | Why |
|---|---|---|
| `/tdd-design` | Claude Fable 5.2 (`claude-fable-5-2`) | Design is where mistakes are most expensive |
| `/tdd` coordinator + planning | your session model (`/model`) | Runs in the main conversation |
| `tdd-red`, `tdd-green` | `sonnet` | Narrow, well-specified jobs |
| `tdd-refactor` | `opus` | Judgment-heavy review |

### graphify

Every stage asks graphify first: design grounds its questions in real modules, planning resolves file paths and task order, RED finds existing tests and fixtures, GREEN checks "already in this codebase?" before writing anything, REFACTOR maps callers for the review.

At the start of each `/tdd` run the coordinator probes graphify with real names from the repo. If graphify is down, empty, or indexed for a different project, the run says so once and uses text search throughout. An empty graphify answer is always treated as *unknown*, never as *doesn't exist*.

---

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI (`claude`)
- Node.js on the **non-interactive** shell's PATH (used by the guard and by Ponytail's hooks). With nvm on macOS, also `brew install node`.
- A git repo per project (the loop commits after each task)
- Access to Claude Fable 5.2 for `/tdd-design` (otherwise change its `model:` line to `opus`)

Works on Linux, WSL2 and macOS.

---

## Install

```bash
git clone https://github.com/<you>/claude-tdd-orchestrator.git
cd claude-tdd-orchestrator
```

### Global (recommended): once per machine, every project

```bash
bash install.sh --global --graphify-token
```

Installs into `~/.claude`:
- agents → `~/.claude/agents/tdd-{red,green,refactor}.md`
- commands → `~/.claude/commands/tdd{,-design,-status,-phase}.md`
- guard → `~/.claude/hooks/tdd-guard.mjs`
- plugins + guard hook **merged** into `~/.claude/settings.json` (backup: `settings.json.bak`)
- graphify as a user-scope MCP server (`claude mcp add --scope user`), with your key if given
- rules in a marked block in `~/.claude/CLAUDE.md` (your own content is untouched)

`/tdd` creates `.tdd/` in each project on first run and adds it to `.gitignore`.

### Per project: commit the setup so collaborators get it

```bash
bash install.sh ~/path/to/project
```

Same files under `<project>/.claude/`, graphify in `<project>/.mcp.json`, rules in `<project>/CLAUDE.md`. An existing `.mcp.json` is not overwritten.

### graphify authentication

The graphify server needs an API key. **The key is never stored in this repo.**

**Global install: key goes into `~/.claude.json` on that machine only**
```bash
bash install.sh --global --graphify-token      # prompts for the key, input hidden
```
Or from the environment, e.g. pulled from a password manager:
```bash
GRAPHIFY_TOKEN="$(op read op://Personal/graphify/token)" bash install.sh --global
```
Avoid typing `GRAPHIFY_TOKEN=abc123 bash install.sh …` with the literal key: it ends up in your shell history.

Rerunning the installer **without** a key keeps the existing graphify entry and its key. Passing a key replaces it, which is how you rotate it.

**Per-project install: key comes from your shell**

The committed `.mcp.json` only references the variable:
```json
"headers": { "Authorization": "Bearer ${GRAPHIFY_TOKEN:-}" }
```
Put the key in your shell profile (`~/.zshrc` on macOS, `~/.bashrc` on WSL/Linux), not in the repo:
```bash
export GRAPHIFY_TOKEN="..."
```

**Manual setup or rotation without the installer**
```bash
claude mcp remove graphify -s user
claude mcp add --transport http --scope user graphify \
  https://graphify-mcp.hajiyev.space/mcp \
  --header "Authorization: Bearer YOUR_TOKEN"
claude mcp get graphify        # Status: ✔ Connected
```

**Different header?** If the server expects e.g. `X-API-Key`, set `GRAPHIFY_HEADER="X-API-Key:"` when running the installer, and change the header in `.mcp.json` to match.

**Testing a key directly**
```bash
curl -i -X POST https://graphify-mcp.hajiyev.space/mcp \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"test","version":"1"}}}'
```
`200` means the key and header are right; `401` means one of them isn't.

**Tools exposed:** `query_graph`, `get_node`, `get_neighbors`, `get_community`, `god_nodes`, `graph_stats`, `shortest_path`, `get_pr_impact`, `list_prs`, `triage_prs`. The agents get them through `mcp__graphify` in their `tools:` lists.

### Updating

```bash
git pull && bash install.sh --global --force     # existing graphify key is kept
```

Safe to rerun: settings are merged, the guard hook is replaced not duplicated, the rules block is swapped in place.

### Check it loaded

Start `claude` in a project and approve the graphify server when asked, then:
- `/plugin` lists superpowers, ponytail, caveman
- `/mcp` shows graphify connected
- `/agents` lists tdd-red, tdd-green, tdd-refactor

---

## Usage

```
/tdd-design users can reset their password by email
/tdd docs/designs/2026-11-11-password-reset.md
```

1. **Design:** answer the questions, approve each section. Saved to `docs/designs/`.
2. **Plan:** `/tdd` turns the design into one-behaviour tasks in `docs/plans/`. **Review this carefully**; everything after follows it.
3. **Loop:** runs unattended task by task, one commit each.

It stops and asks you when:
- the plan needs approval
- a new test already passes (the behaviour may exist)
- GREEN thinks a test is wrong, twice
- review finds a serious issue it can't fix in two rounds
- the baseline suite is already failing

### Commands

| Command | Purpose |
|---|---|
| `/tdd-design <feature>` | Brainstorm on Fable 5.2, save a design doc |
| `/tdd <design.md \| plan.md>` | Plan (from a design) and run the loop; a plan skips straight to the loop |
| `/tdd-status` | Phase, tasks done/total, next task, suite result |
| `/tdd-phase [red\|green\|refactor\|off]` | Inspect or override the guard |

**After an interrupted run, run `/tdd-phase off`.** Otherwise the guard keeps blocking normal edits.

For trivial fixes, skip design: write a two-line plan in `docs/plans/` and pass it to `/tdd`.

---

## Tuning

| What | Where |
|---|---|
| Test file detection | `export TDD_TEST_PATTERN='<JS regex>'` before starting Claude Code |
| Agent models | `model:` in `agents/tdd-*.md` (e.g. `haiku` for RED to cut cost) |
| Design model | `model:` in `commands/tdd-design.md` |
| Caveman level | step 0 of `commands/tdd.md` (`lite` / `full` / `ultra`) |
| graphify URL | `.mcp.json`, and `GRAPHIFY_URL` in `install.sh` |
| graphify key | `--graphify-token` or `GRAPHIFY_TOKEN`; header prefix via `GRAPHIFY_HEADER`. See *graphify authentication* |

---

## Repository layout

```
.claude/
  agents/tdd-red.md         RED: one failing test
  agents/tdd-green.md       GREEN: minimal passing code
  agents/tdd-refactor.md    REFACTOR: cleanup + review
  commands/tdd.md           coordinator loop
  commands/tdd-design.md    Fable 5.2 design stage
  commands/tdd-status.md
  commands/tdd-phase.md
  hooks/tdd-guard.mjs       phase-aware edit guard
  settings.json             plugins, marketplaces, guard hook
.mcp.json                   graphify (per-project install)
CLAUDE.md                   rules: who owns what, hard rules
install.sh                  --global | <project> [--force]
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| A plugin is missing in `/plugin` | The installer continues past plugin errors. Run inside Claude Code: `/plugin install superpowers@claude-plugins-official`, `/plugin marketplace add DietrichGebert/ponytail`, `/plugin install ponytail@ponytail`, `/plugin marketplace add JuliusBrussee/caveman`, `/plugin install caveman@caveman` |
| Guard never blocks | Hook not in settings: rerun the installer, or copy the `hooks` block from `.claude/settings.json` |
| Guard blocks normal work | Leftover phase from an interrupted run: `/tdd-phase off` |
| Hooks fail with `node: not found` | Node isn't on the non-interactive PATH (common with nvm); install a system Node |
| `/tdd-design` errors on the model | No Fable access: set `model: opus` in `commands/tdd-design.md` |
| An agent can't see graphify | List graphify's exact tool names in the agent's `tools:` line, or remove that line |
| `claude mcp get graphify` shows `Dynamic Client Registration rejected (HTTP 401)` | No key was sent, so Claude Code tried OAuth sign-in, which this server doesn't offer. Add the key: `bash install.sh --global --graphify-token` |
| graphify connects on one machine but not another | Keys live per machine in `~/.claude.json`; run the installer with `--graphify-token` on each |
| Both global and project installs present | Project copies take priority and the guard runs twice; remove the project's `tdd-*` agents/commands/hook |

---

## Credits

Built on [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent / Prime Radiant, [Ponytail](https://github.com/DietrichGebert/ponytail) by Dietrich Gebert, and [Caveman](https://github.com/JuliusBrussee/caveman) by Julius Brussee. Those projects are installed from their own repositories, not vendored here.
