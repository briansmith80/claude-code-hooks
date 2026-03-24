# claude-code-hooks

Pre-built hook packs for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). One command to install guard-rails, auto-formatting, notifications, and cost logging.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/briansmith80/claude-code-hooks/main/install.sh | bash
```

## Usage

```bash
cd your-project

claude-hooks                       # interactive picker
claude-hooks guard-rails           # install a specific pack
claude-hooks guard-rails notify    # install multiple packs
claude-hooks --list                # see available packs
```

## Available Packs

| Pack | Event | What It Does |
|------|-------|-------------|
| **guard-rails** | PreToolUse | Blocks `Edit`/`Write` to `.env`, keys, credentials, SSH files, cloud configs, and more |
| **auto-format** | PostToolUse | Runs the right formatter after every edit — prettier, black/ruff, gofmt, rustfmt, rubocop, pint, clang-format, and more |
| **notify** | Stop | Desktop notification when Claude finishes a turn (macOS, Linux, Windows) |
| **cost-log** | Stop | Appends token usage per turn to `~/.claude/cost-log.csv` |

## Options

| Flag | Description |
|------|-------------|
| `--local` | Write to `settings.local.json` instead of `settings.json` |
| `--list` | List available packs |
| `--help` | Show help |
| `--version` | Show version |

## How It Works

1. Hook scripts are saved to `~/.claude-hooks/<pack>/`
2. Hook configuration is merged into `~/.claude/settings.json`
3. Claude Code reads the hooks on startup and executes them at the right time

Running the same pack twice is safe — duplicates are detected and skipped.

## Hook Packs in Detail

### guard-rails

Fires **before** Claude uses `Edit` or `Write`. Checks the target file against protected patterns and blocks the operation if it matches.

**Protected patterns:**
- `.env`, `.env.*` (but allows `.env.example`, `.env.sample`, `.env.template`)
- `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`
- `id_rsa`, `id_ed25519`, `id_ecdsa` (and variants)
- `credentials`, `*secret*`, `.npmrc`, `.pypirc`, `.netrc`, `.htpasswd`
- `service-account*.json`, `*-credentials.json`
- Files in `~/.ssh/`, `~/.gnupg/`, `~/.aws/`, `~/.config/gcloud/`, `~/.kube/`, `~/.docker/`

Matching is case-insensitive and resolves symlinks when possible.

> **Note:** guard-rails protects against `Edit` and `Write` tool calls only. It does not intercept `Bash` commands like `cat .env` or `cp .env`. For full protection, also add sensitive paths to `permissions.deny` in your settings.

### auto-format

Fires **after** Claude uses `Edit` or `Write`. Detects the file extension and runs the appropriate formatter if it's installed:

| Extension | Formatter |
|-----------|-----------|
| js, ts, jsx, tsx, css, scss, less, json, md, mdx, html, yaml, yml, vue, svelte, graphql | `prettier` |
| py | `ruff format` or `black` |
| rs | `rustfmt` |
| go | `gofmt` |
| rb, rake, gemspec | `rubocop -A` |
| php | `./vendor/bin/pint` or `pint` |
| ex, exs | `mix format` |
| c, cpp, cc, cxx, h, hpp | `clang-format` |
| dart | `dart format` |
| tf, tfvars | `terraform fmt` |

### notify

Fires when Claude **stops** (end of turn). Sends a native desktop notification:

- **macOS** — `osascript` (Notification Center)
- **Linux** — `notify-send`
- **Windows** — PowerShell balloon notification

**Configuration** — create `~/.claude-hooks/notify/config` to customize:

```bash
NOTIFY_SOUND=true            # play sound with notification (true/false)
NOTIFY_SOUND_FILE=""         # custom .wav path (empty = system default)
NOTIFY_MIN_DURATION=0        # skip if turn was shorter than N seconds
NOTIFY_ONLY_UNFOCUSED=false  # only notify when terminal isn't focused
```

### cost-log

Fires when Claude **stops** (end of turn). Appends a CSV row to `~/.claude/cost-log.csv`:

```
timestamp,stop_reason,input_tokens,output_tokens,cache_read,cache_write
```

## Requirements

- **Node.js** (already required by Claude Code)
- **bash** (macOS/Linux native, Git Bash on Windows)

## Related Projects

| Project | Configures |
|---------|-----------|
| [claude-code-bootstrap](https://github.com/briansmith80/claude-code-bootstrap) | Permissions (`permissions.allow/deny`) |
| [claude-code-status-bar](https://github.com/briansmith80/claude-code-status-bar) | Status display (`statusLine`) |
| **claude-code-hooks** | Hooks (`hooks`) |

All three configure different parts of the same `settings.json` without overlapping.

## License

MIT
