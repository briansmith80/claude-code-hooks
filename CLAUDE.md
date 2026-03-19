# Claude Code Hooks — Project Conventions

## What This Is
A one-liner installable collection of pre-built hook packs for Claude Code. Users pick hook packs (guard-rails, auto-format, notify, cost-log) and the tool installs the bash scripts and wires up the hooks config in their settings.json.

## Repository Structure
- `install.sh` — curl | bash one-liner installer (downloads CLI, sets up alias)
- `claude-hooks.sh` — Main CLI script (interactive picker, pack installer, config merger)
- `hooks/` — Hook pack definitions, each subdirectory contains:
  - `hooks.json` — Hook config snippet with `_scripts` manifest and `_description`
  - `*.sh` — The actual hook script(s) that Claude Code executes
- GitHub raw base: `https://raw.githubusercontent.com/briansmith80/claude-code-hooks/main`

## Coding Standards
- **Pure bash** with `node -e` for JSON parsing (Claude Code requires Node.js)
- Shebang: `#!/usr/bin/env bash`
- Error handling: `set -euo pipefail` in all scripts
- Always quote variables: `"${var}"` not `$var`
- Use `printf` over `echo` for portability
- Functions: `lowercase_snake_case`; Constants: `UPPER_SNAKE_CASE`
- Indentation: 2 spaces
- Cross-platform: macOS, Linux, Windows (Git Bash / MSYS2)

## Hook Pack Format
Each pack's `hooks.json` uses `__HOOKS_DIR__` as a placeholder path. The installer replaces it with `~/.claude-hooks/` at install time. The `_scripts` array lists files to download/copy. The `_description` field is for display purposes. Both are stripped before merging into settings.json.

## How It Relates to Sibling Projects
- `claude-code-bootstrap` → permissions (permissions.allow/deny)
- `claude-code-status-bar` → status display (statusLine)
- `claude-code-hooks` → hooks (hooks key in settings.json)

All three configure different parts of the same settings.json without overlapping.
