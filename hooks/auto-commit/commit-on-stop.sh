#!/usr/bin/env bash
set -euo pipefail

# Auto-Commit: Commit changes after each Claude turn
# Stop hook — receives JSON on stdin

# Consume stdin (required even if unused)
input=$(cat)

# ------- Configuration defaults -------
COMMIT_MSG_PREFIX="auto"
COMMIT_STAGED_ONLY=false

# Load user config if present
config_file="${HOME}/.claude-hooks/auto-commit/config"
if [[ -f "${config_file}" ]]; then
  # shellcheck source=/dev/null
  source "${config_file}"
fi

# ------- Guard: must be inside a git repo -------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# ------- Check for changes -------
if [[ "${COMMIT_STAGED_ONLY}" == "true" ]]; then
  # Only proceed if there are already-staged changes
  staged=$(git diff --cached --name-only 2>/dev/null) || exit 0
  [[ -z "${staged}" ]] && exit 0
else
  # Check for any uncommitted changes (staged + unstaged + untracked)
  changes=$(git status --porcelain 2>/dev/null) || exit 0
  [[ -z "${changes}" ]] && exit 0

  # Stage all tracked modifications and new files (respects .gitignore)
  git add -A >/dev/null 2>&1 || exit 0
fi

# ------- Build commit message -------
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || timestamp="unknown"
commit_msg="${COMMIT_MSG_PREFIX}: Claude Code checkpoint [${timestamp}]"

# ------- Commit -------
git commit -m "${commit_msg}" --no-verify >/dev/null 2>&1 || true

exit 0
