#!/usr/bin/env bash
set -euo pipefail

# Dangerous Command Blocker: Block destructive bash commands
# PreToolUse hook for Bash — receives JSON on stdin

input=$(cat)

# Parse the command field from tool_input via node
cmd=$(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      process.stdout.write((o.tool_input || {}).command || '');
    } catch { process.stdout.write(''); }
  });
" 2>/dev/null) || exit 0

# No command means nothing to check
[[ -z "${cmd}" ]] && exit 0

block() {
  printf '{"decision":"block","reason":"dangerous-cmd: %s"}\n' "$1"
  exit 0
}

# Normalize: collapse whitespace for reliable matching
normalized=$(printf '%s' "${cmd}" | tr -s '[:space:]' ' ')

# Convert to lowercase for case-insensitive checks (bash 3.2 compatible)
lower=$(printf '%s' "${normalized}" | tr '[:upper:]' '[:lower:]')

# Fast-path: single grep to check if command might be dangerous
if ! printf '%s' "${lower}" | grep -qE 'rm\s.*-.*r.*f|git\s+(push|reset|clean|branch)|drop\s+(table|database)|truncate\s+table|mkfs\.|dd\s+.*of=.*/dev/|chmod\s.*777|:\(\)\{|>\s*/dev/(sd|hd|nvme)|kill\s+-9\s+1'; then
  printf '{"decision":"allow"}\n'
  exit 0
fi

# --- rm -rf targeting root, home, or current directory ---
if printf '%s' "${lower}" | grep -qE '(^|\s|/)(rm|/bin/rm|/usr/bin/rm)\s+(-[a-z]*r[a-z]*\s+-[a-z]*f[a-z]*|-[a-z]*f[a-z]*\s+-[a-z]*r[a-z]*|-[a-z]*rf[a-z]*|-[a-z]*fr[a-z]*)\s+(/|~|\.)(\s|$|;|\|)'; then
  block "Blocked recursive force-delete of root, home, or current directory."
fi

# --- git push --force / -f to main or master ---
if printf '%s' "${lower}" | grep -qE 'git\s+push\s+.*(-f|--force)' && printf '%s' "${lower}" | grep -qE '\b(main|master)\b'; then
  block "Blocked force push to main/master branch."
fi

# --- git reset --hard ---
if printf '%s' "${lower}" | grep -qE 'git\s+reset\s+--hard'; then
  block "Blocked git reset --hard — this discards uncommitted changes."
fi

# --- git clean -f (destructive: removes untracked files) ---
if printf '%s' "${lower}" | grep -qE 'git\s+clean\s+.*-[a-z]*f'; then
  block "Blocked git clean -f — this permanently removes untracked files."
fi

# --- git branch -D (force delete branch) ---
if printf '%s' "${lower}" | grep -qE 'git\s+branch\s+.*-D'; then
  block "Blocked git branch -D — use -d for safe branch deletion."
fi

# --- SQL destructive commands (DROP TABLE, DROP DATABASE, TRUNCATE TABLE) ---
if printf '%s' "${lower}" | grep -qE 'drop\s+table'; then
  block "Blocked DROP TABLE command."
fi
if printf '%s' "${lower}" | grep -qE 'drop\s+database'; then
  block "Blocked DROP DATABASE command."
fi
if printf '%s' "${lower}" | grep -qE 'truncate\s+table'; then
  block "Blocked TRUNCATE TABLE command."
fi

# --- mkfs (format filesystem) ---
if printf '%s' "${lower}" | grep -qE '\bmkfs\.'; then
  block "Blocked mkfs command — this formats a filesystem."
fi

# --- dd writing to disk devices ---
if printf '%s' "${lower}" | grep -qE 'dd\s+.*if=.*of=/dev/(sd|hd|nvme|vd|xvd)'; then
  block "Blocked dd write to disk device."
fi

# --- chmod 777 ---
if printf '%s' "${lower}" | grep -qE 'chmod\s+.*\b777\b'; then
  block "Blocked chmod 777 — overly permissive file permissions."
fi

# --- fork bomb ---
if printf '%s' "${cmd}" | grep -qF ':(){ :|:& };:'; then
  block "Blocked fork bomb."
fi

# --- direct writes to block devices ---
if printf '%s' "${lower}" | grep -qE '>\s*/dev/(sd|hd|nvme|vd|xvd)'; then
  block "Blocked direct write to disk device."
fi

# --- kill -9 1 (kill init/systemd) ---
if printf '%s' "${lower}" | grep -qE 'kill\s+-9\s+1(\s|$|;|\|)'; then
  block "Blocked kill -9 1 — this would kill the init process."
fi

# All checks passed
printf '{"decision":"allow"}\n'
exit 0
