#!/usr/bin/env bash
set -euo pipefail

# lint-on-save.sh — Run the appropriate linter after Claude edits a file.
# Receives PostToolUse JSON on stdin with tool_input containing the file path.

INPUT="$(cat)"

# Extract the file path from tool_input using node
FILE_PATH="$(printf '%s' "${INPUT}" | node -e "
  const chunks = [];
  process.stdin.on('data', c => chunks.push(c));
  process.stdin.on('end', () => {
    try {
      const data = JSON.parse(chunks.join(''));
      const ti = data.tool_input || {};
      const fp = ti.file_path || ti.path || '';
      process.stdout.write(fp);
    } catch {
      process.exit(0);
    }
  });
")"

# Exit silently if no file path was found
if [[ -z "${FILE_PATH}" ]]; then
  exit 0
fi

# Extract extension (lowercase)
EXT="${FILE_PATH##*.}"
EXT="$(printf '%s' "${EXT}" | tr '[:upper:]' '[:lower:]')"

# Determine linter command based on file extension
LINT_CMD=""

case "${EXT}" in
  js|jsx|ts|tsx)
    if command -v eslint &>/dev/null; then
      LINT_CMD="eslint --fix"
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      LINT_CMD="ruff check --fix"
    elif command -v flake8 &>/dev/null; then
      LINT_CMD="flake8"
    fi
    ;;
  rb|rake|gemspec)
    if command -v rubocop &>/dev/null; then
      LINT_CMD="rubocop -A"
    fi
    ;;
  go)
    if command -v golangci-lint &>/dev/null; then
      LINT_CMD="golangci-lint run"
    fi
    ;;
  rs)
    if command -v cargo &>/dev/null; then
      LINT_CMD="cargo clippy"
    fi
    ;;
  php)
    if [[ -x "./vendor/bin/phpstan" ]]; then
      LINT_CMD="./vendor/bin/phpstan analyse"
    elif command -v phpstan &>/dev/null; then
      LINT_CMD="phpstan analyse"
    fi
    ;;
  sh|bash)
    if command -v shellcheck &>/dev/null; then
      LINT_CMD="shellcheck"
    fi
    ;;
  c|cpp|cc|h|hpp)
    if command -v cppcheck &>/dev/null; then
      LINT_CMD="cppcheck"
    fi
    ;;
  *)
    # No linter for this extension — exit silently
    exit 0
    ;;
esac

# Exit silently if no linter is installed
if [[ -z "${LINT_CMD}" ]]; then
  exit 0
fi

# Run the linter capturing stderr; always exit 0 so we never block Claude
LINT_OUTPUT=""
LINT_OUTPUT="$(bash -c "${LINT_CMD} \"${FILE_PATH}\"" 2>&1)" || true

if [[ -n "${LINT_OUTPUT}" ]]; then
  printf '%s\n' "${LINT_OUTPUT}"
fi

exit 0
