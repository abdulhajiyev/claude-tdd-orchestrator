#!/usr/bin/env bash
# TDD orchestrator installer: Superpowers + Ponytail + Caveman + graphify MCP.
#
#   ./install.sh --global            install once into ~/.claude, works in every project
#   ./install.sh [path/to/project]   install into one project (defaults to current dir)
#   add --force to overwrite agents/commands/hook from an older version
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRAPHIFY_URL="https://graphify-mcp.hajiyev.space/mcp"
GLOBAL=0; FORCE=0; TARGET="$PWD"
for a in "$@"; do
  case "$a" in
    --global) GLOBAL=1 ;;
    --force)  FORCE=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) TARGET="$a" ;;
  esac
done

command -v claude >/dev/null || { echo "claude CLI not found on PATH"; exit 1; }
command -v node   >/dev/null || { echo "node not found (Ponytail hooks + tdd-guard need it on the non-interactive PATH)"; exit 1; }

if [ "$GLOBAL" = 1 ]; then
  DEST="$HOME/.claude"
  RULES="$DEST/CLAUDE.md"
  HOOK_CMD='node "$HOME/.claude/hooks/tdd-guard.mjs"'
else
  DEST="$TARGET/.claude"
  RULES="$TARGET/CLAUDE.md"
  HOOK_CMD='node "$CLAUDE_PROJECT_DIR/.claude/hooks/tdd-guard.mjs"'
fi

echo "==> Plugins (user scope)"
claude plugin install superpowers@claude-plugins-official || true
claude plugin marketplace add DietrichGebert/ponytail || true
claude plugin install ponytail@ponytail || true
claude plugin marketplace add JuliusBrussee/caveman || true
claude plugin install caveman@caveman || true

echo "==> Agents, commands, hook -> $DEST"
mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/hooks"
for f in "$HERE"/.claude/agents/*.md "$HERE"/.claude/commands/*.md; do
  dest="$DEST/$(basename "$(dirname "$f")")/$(basename "$f")"
  if [ -e "$dest" ] && [ "$FORCE" = 0 ]; then
    echo "   skip (exists, use --force to update): $dest"
  else
    cp "$f" "$dest"
  fi
done
cp "$HERE/.claude/hooks/tdd-guard.mjs" "$DEST/hooks/"
chmod +x "$DEST/hooks/tdd-guard.mjs"

echo "==> Merging plugins + guard hook into $DEST/settings.json"
[ -f "$DEST/settings.json" ] && cp "$DEST/settings.json" "$DEST/settings.json.bak"
node - "$HERE/.claude/settings.json" "$DEST/settings.json" "$HOOK_CMD" <<'EOF'
const fs = require("fs");
const [src, dst, hookCmd] = process.argv.slice(2);
const b = JSON.parse(fs.readFileSync(src, "utf8"));
let s = {};
if (fs.existsSync(dst)) {
  try { s = JSON.parse(fs.readFileSync(dst, "utf8")); }
  catch { console.error(`!! ${dst} is not valid JSON; left untouched`); process.exit(0); }
}
s.extraKnownMarketplaces = { ...(s.extraKnownMarketplaces || {}), ...b.extraKnownMarketplaces };
s.enabledPlugins = { ...(s.enabledPlugins || {}), ...b.enabledPlugins };
s.hooks ??= {};
const pre = (s.hooks.PreToolUse ??= []);
const stale = (h) => /tdd-guard\.mjs/.test(h.command || "");
for (const m of pre) m.hooks = (m.hooks || []).filter((h) => !stale(h));
s.hooks.PreToolUse = pre.filter((m) => m.hooks.length);
s.hooks.PreToolUse.push({
  matcher: "Edit|Write|MultiEdit|NotebookEdit",
  hooks: [{ type: "command", command: hookCmd }],
});
fs.writeFileSync(dst, JSON.stringify(s, null, 2) + "\n");
EOF

echo "==> graphify MCP"
if [ "$GLOBAL" = 1 ]; then
  claude mcp add --transport http --scope user graphify "$GRAPHIFY_URL" 2>/dev/null \
    || echo "   graphify already configured at user scope (or add failed: check with 'claude mcp list')"
elif [ -f "$TARGET/.mcp.json" ]; then
  echo "!! $TARGET/.mcp.json exists — add the graphify entry from this bundle's .mcp.json by hand"
else
  cp "$HERE/.mcp.json" "$TARGET/.mcp.json"
fi

echo "==> Rules -> $RULES"
node - "$HERE/CLAUDE.md" "$RULES" <<'EOF'
const fs = require("fs");
const [src, dst] = process.argv.slice(2);
const START = "<!-- tdd-orchestrator:start -->", END = "<!-- tdd-orchestrator:end -->";
const block = `${START}\n${fs.readFileSync(src, "utf8").trim()}\n${END}`;
let cur = fs.existsSync(dst) ? fs.readFileSync(dst, "utf8") : "";
const i = cur.indexOf(START), j = cur.indexOf(END);
cur = i >= 0 && j > i
  ? cur.slice(0, i) + block + cur.slice(j + END.length)
  : (cur.trim() ? cur.trimEnd() + "\n\n" : "") + block + "\n";
fs.writeFileSync(dst, cur);
EOF

if [ "$GLOBAL" = 0 ]; then
  mkdir -p "$TARGET/.tdd" && echo off > "$TARGET/.tdd/phase"
  grep -qxF '.tdd/' "$TARGET/.gitignore" 2>/dev/null || echo '.tdd/' >> "$TARGET/.gitignore"
  echo "Done. Restart Claude Code in $TARGET, then: /tdd-design <feature>"
else
  echo "Done. Restart Claude Code in any project, then: /tdd-design <feature>"
fi
