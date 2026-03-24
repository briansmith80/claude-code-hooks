# claude-code-hooks

**Drop-in hook packs that make Claude Code safer, cleaner, and easier to manage.**

Claude Code hooks let you run scripts before or after Claude takes action — but writing them from scratch is tedious. `claude-code-hooks` gives you production-ready packs you can install in seconds:

- **guard-rails** — Automatically blocks Claude from editing `.env` files, API keys, SSH keys, and other secrets. Sleep easier knowing your credentials are protected.
- **dangerous-cmd** — Catches destructive bash commands before they run. No more accidental `rm -rf`, force pushes, or dropped tables.
- **auto-format** — Every file Claude touches gets formatted with the right tool. Prettier for JS/TS, Black for Python, gofmt for Go, and 10+ more. No more style drift in AI-generated code.
- **auto-lint** — Linting runs automatically after every edit. ESLint, Ruff, RuboCop, ShellCheck, and more — Claude sees the errors and can fix them immediately.
- **auto-test** — Tests run after code changes so regressions get caught in real time. Supports npm, pytest, RSpec, Go, Cargo, PHPUnit, and Mix.
- **notify** — Get a desktop notification the moment Claude finishes working. Stop watching the terminal and multitask with confidence.
- **cost-log** — Track every token Claude spends in a simple CSV. Know exactly where your usage goes across sessions and projects.
- **auto-commit** — Every Claude turn gets checkpointed as a git commit. Easy to review, easy to roll back.
- **session-log** — A markdown diary of every Claude turn — timestamps, token counts, and stop reasons. Perfect for auditing and retrospectives.

Every pack is independent — install only the ones you want. Mix and match to build your ideal workflow. No config files to write, no JSON to hand-edit.

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

## Pack Library

Install one pack, a few, or all of them — each works independently.

```bash
claude-hooks guard-rails                    # just one
claude-hooks guard-rails dangerous-cmd      # a few
claude-hooks auto-format auto-lint notify   # your own combo
```

### Safety

| Pack | Event | What It Does |
|------|-------|-------------|
| **guard-rails** | PreToolUse | Blocks `Edit`/`Write` to `.env`, keys, credentials, SSH files, cloud configs, and more |
| **dangerous-cmd** | PreToolUse | Blocks destructive bash commands — `rm -rf`, force push, `DROP TABLE`, and more |

### Code Quality

| Pack | Event | What It Does |
|------|-------|-------------|
| **auto-format** | PostToolUse | Runs the right formatter after every edit — prettier, black/ruff, gofmt, rustfmt, rubocop, pint, clang-format, and more |
| **auto-lint** | PostToolUse | Runs the right linter after every edit — eslint, ruff, rubocop, shellcheck, and more |
| **auto-test** | PostToolUse | Runs the project's test suite after code changes |

### Awareness

| Pack | Event | What It Does |
|------|-------|-------------|
| **notify** | Stop | Desktop notification when Claude finishes a turn (macOS, Linux, Windows) |
| **cost-log** | Stop | Appends token usage per turn to `~/.claude/cost-log.csv` |
| **auto-commit** | Stop | Auto-commits changes after each Claude turn |
| **session-log** | Stop | Appends a markdown summary of each turn to `~/.claude/session-log.md` |

### Suggested Combos

| Use Case | Command |
|----------|---------|
| Safety first | `claude-hooks guard-rails dangerous-cmd` |
| Clean code | `claude-hooks auto-format auto-lint` |
| Full CI feel | `claude-hooks auto-format auto-lint auto-test` |
| Stay informed | `claude-hooks notify cost-log` |
| Everything | `claude-hooks guard-rails dangerous-cmd auto-format auto-lint auto-test notify cost-log auto-commit session-log` |

## Options

| Flag | Description |
|------|-------------|
| `--local` | Write to `settings.local.json` instead of `settings.json` |
| `--list` | List available packs |
| `--help` | Show help |
| `--version` | Show version |

## How It Works

1. You run `claude-hooks` and pick the packs you want
2. Hook scripts are copied to `~/.claude-hooks/<pack>/`
3. Hook configuration is merged into `~/.claude/settings.json`
4. Claude Code reads the hooks on next startup and runs them automatically

Hooks are **global by default** — they apply to every Claude Code session. Use `--local` to scope hooks to a specific project instead.

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

### dangerous-cmd

Fires **before** Claude uses `Bash`. Inspects the command and blocks it if it matches dangerous patterns:

- `rm -rf /`, `rm -rf ~`, `rm -rf .` (recursive force delete of critical paths)
- `git push --force` / `git push -f` to main/master
- `git reset --hard`, `git clean -f`, `git branch -D`
- `DROP TABLE`, `DROP DATABASE`, `TRUNCATE TABLE`
- `mkfs.` (format filesystem)
- `dd if=` writing to disk devices
- `chmod 777`, fork bombs, device writes

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

### auto-lint

Fires **after** Claude uses `Edit` or `Write`. Detects the file extension and runs the appropriate linter if it's installed:

| Extension | Linter |
|-----------|--------|
| js, jsx, ts, tsx | `eslint --fix` |
| py | `ruff check --fix` or `flake8` |
| rb, rake, gemspec | `rubocop -A` |
| go | `golangci-lint run` |
| rs | `cargo clippy` |
| php | `phpstan analyse` |
| sh, bash | `shellcheck` |
| c, cpp, cc, h, hpp | `cppcheck` |

Lint output is reported back to Claude so it can fix issues automatically.

### auto-test

Fires **after** Claude uses `Edit` or `Write`. Detects the project type and runs the appropriate test runner:

| Config File | Test Runner |
|-------------|-------------|
| `package.json` | `npm test` (detects vitest/jest) |
| `pyproject.toml` / `pytest.ini` | `pytest` |
| `Gemfile` | `bundle exec rspec` or `rails test` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |
| `composer.json` | `phpunit` or `php artisan test` |
| `mix.exs` | `mix test` |

Skips non-source files (markdown, config, etc.). Test output is reported back to Claude.

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

### auto-commit

Fires when Claude **stops** (end of turn). Automatically commits any uncommitted changes as a checkpoint.

Commit messages follow the format: `auto: Claude Code checkpoint [timestamp]`

**Configuration** — create `~/.claude-hooks/auto-commit/config` to customize:

```bash
COMMIT_MSG_PREFIX="auto"       # prefix for commit messages
COMMIT_STAGED_ONLY=false       # if true, only commit already-staged files
COMMIT_SKIP_HOOKS=false        # if true, skip git pre-commit hooks
```

### session-log

Fires when Claude **stops** (end of turn). Appends a markdown entry to `~/.claude/session-log.md` with:

- Timestamp and project name
- Stop reason
- Token usage (input, output, cache read/write)
- Working directory

## Uninstall

**Remove all hooks:**

```bash
# Delete hook scripts
rm -rf ~/.claude-hooks

# Remove hooks config from settings.json
node -e "
  const fs = require('fs');
  const f = process.env.HOME + '/.claude/settings.json';
  try {
    const s = JSON.parse(fs.readFileSync(f, 'utf8'));
    delete s.hooks;
    fs.writeFileSync(f, JSON.stringify(s, null, 2) + '\n');
    console.log('Hooks removed from ' + f);
  } catch(e) { console.error(e.message); }
"
```

**Remove a single pack:** Open `~/.claude/settings.json`, find the hook entry for the pack you want to remove, and delete it. Then delete the pack's script folder:

```bash
rm -rf ~/.claude-hooks/<pack-name>
```

**Remove the CLI alias:** Delete the `# claude-code-hooks` line and the alias below it from your `~/.bashrc` or `~/.zshrc`.

## FAQ

**Do I need all the packs?**
No. Every pack is independent. Install one, three, or all nine — whatever fits your workflow. You can always add or remove packs later.

**Will hooks slow down Claude?**
Minimally. Safety hooks (guard-rails, dangerous-cmd) add a few milliseconds per tool call. Code quality hooks (auto-format, auto-lint) run fast formatters/linters. The auto-test pack runs your test suite, so speed depends on your project — consider it for smaller projects or use the cost-log pack instead if you want lightweight tracking.

**Do hooks work in VS Code / JetBrains?**
Yes. Hooks are part of Claude Code itself, not the IDE. They work anywhere Claude Code runs — terminal, VS Code, JetBrains, or any IDE with Claude Code integration.

**Can I customize which files are protected?**
The guard-rails pack has a built-in list of sensitive patterns. For custom rules, you can edit `~/.claude-hooks/guard-rails/protect-files.sh` directly — it's just a bash script.

**What happens if a formatter or linter isn't installed?**
Nothing. The auto-format and auto-lint packs check for each tool before running it. If prettier isn't installed, the hook silently skips. No errors, no blocking.

**Does auto-commit bypass my git hooks?**
No, not by default. Set `COMMIT_SKIP_HOOKS=true` in `~/.claude-hooks/auto-commit/config` if you want to skip pre-commit hooks for auto-commits.

**Where do logs go?**
- **cost-log** writes to `~/.claude/cost-log.csv`
- **session-log** writes to `~/.claude/session-log.md`

Both are append-only. Open them in any text editor or spreadsheet app.

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
