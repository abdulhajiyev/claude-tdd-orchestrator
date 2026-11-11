---
description: Show or set the TDD guard phase (red | green | refactor | off)
argument-hint: [red|green|refactor|off]
allowed-tools: Bash(cat:*), Bash(echo:*)
---

If "$ARGUMENTS" is one of red, green, refactor, off: run `echo $ARGUMENTS > .tdd/phase`.
Then run `cat .tdd/phase` and reply with just the current phase and what the guard allows in it.
