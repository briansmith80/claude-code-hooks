#!/usr/bin/env bash
set -euo pipefail

# Auto-Lint: Run the appropriate linter after Claude edits a file
# PostToolUse hook for Edit|Write — receives JSON on stdin

input=$(cat)

# Parse file_path via stdin to node (avoids ARG_MAX and process list exposure)
file_path=$(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      process.stdout.write((o.tool_input || {}).file_path || '');
    } catch { process.stdout.write(''); }
  });
" 2>/dev/null) || exit 0

[[ -z "${file_path}" ]] && exit 0
[[ ! -f "${file_path}" ]] && exit 0

# Prevent option injection: ensure path doesn't start with a dash
safe_path="${file_path}"
[[ "${safe_path}" == -* ]] && safe_path="./${safe_path}"

ext="${file_path##*.}"
ext=$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')

# Determine linter command based on file extension
lint_cmd=()

case "${ext}" in
  js|jsx|ts|tsx)
    command -v eslint &>/dev/null && lint_cmd=(eslint --fix --)
    ;;
  py)
    if command -v ruff &>/dev/null; then
      lint_cmd=(ruff check --fix --)
    elif command -v flake8 &>/dev/null; then
      lint_cmd=(flake8 --)
    fi
    ;;
  rb|rake|gemspec)
    command -v rubocop &>/dev/null && lint_cmd=(rubocop -A --)
    ;;
  go)
    command -v golangci-lint &>/dev/null && lint_cmd=(golangci-lint run)
    ;;
  rs)
    command -v cargo &>/dev/null && lint_cmd=(cargo clippy -- -W warnings)
    ;;
  php)
    if [[ -x ./vendor/bin/phpstan ]]; then
      lint_cmd=(./vendor/bin/phpstan analyse --)
    elif command -v phpstan &>/dev/null; then
      lint_cmd=(phpstan analyse --)
    fi
    ;;
  sh|bash)
    command -v shellcheck &>/dev/null && lint_cmd=(shellcheck --)
    ;;
  c|cpp|cc|cxx|h|hpp)
    command -v cppcheck &>/dev/null && lint_cmd=(cppcheck --)
    ;;
esac

[[ ${#lint_cmd[@]} -eq 0 ]] && exit 0

# Run the linter; always exit 0 so we never block Claude
# Go and Rust linters handle paths differently — no safe_path argument
case "${ext}" in
  go)
    lint_output=$("${lint_cmd[@]}" "${safe_path}" 2>&1) || true
    ;;
  rs)
    lint_output=$("${lint_cmd[@]}" 2>&1) || true
    ;;
  *)
    lint_output=$("${lint_cmd[@]}" "${safe_path}" 2>&1) || true
    ;;
esac

if [[ -n "${lint_output}" ]]; then
  printf '%s\n' "${lint_output}"
fi

exit 0
