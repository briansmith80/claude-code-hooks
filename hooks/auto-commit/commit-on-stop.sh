#!/usr/bin/env bash
set -euo pipefail

# Auto-Commit: Commit changes after each Claude turn
# Stop hook — receives JSON on stdin

# Consume stdin (required even if unused)
input=$(cat)

# ------- Configuration defaults -------
COMMIT_MSG_PREFIX="auto"
COMMIT_STAGED_ONLY=false
COMMIT_SKIP_HOOKS=false

# Load user config if present
CONFIG_FILE="${HOME}/.claude-hooks/auto-commit/config"
if [[ -f "${CONFIG_FILE}" ]]; then
  while IFS='=' read -r key value; do
    # Skip comments and blank lines
    key="${key%%#*}"
    key="${key// /}"
    [[ -z "${key}" ]] && continue
    # Strip surrounding quotes from value
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    case "${key}" in
      COMMIT_MSG_PREFIX|COMMIT_STAGED_ONLY|COMMIT_SKIP_HOOKS)
        printf -v "${key}" '%s' "${value}"
        ;;
    esac
  done < "${CONFIG_FILE}"
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
commit_flags=()
if [[ "${COMMIT_SKIP_HOOKS}" == "true" ]]; then
  commit_flags+=(--no-verify)
fi
git commit -m "${commit_msg}" "${commit_flags[@]}" >/dev/null 2>&1 || true

exit 0
