#!/usr/bin/env bash
set -euo pipefail

# Auto-Format: Run the appropriate formatter after a file is edited
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

case "${ext}" in
  js|jsx|ts|tsx|css|scss|less|json|md|mdx|html|yaml|yml|vue|svelte|graphql)
    if command -v prettier &>/dev/null; then
      prettier --write -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      ruff format -- "${safe_path}" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black --quiet -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  rs)
    if command -v rustfmt &>/dev/null; then
      rustfmt -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "${safe_path}" 2>/dev/null || true
    fi
    ;;
  rb|rake|gemspec)
    if command -v rubocop &>/dev/null; then
      rubocop -A --fail-level=fatal -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  php)
    if [[ -x ./vendor/bin/pint ]]; then
      ./vendor/bin/pint -- "${safe_path}" 2>/dev/null || true
    elif command -v pint &>/dev/null; then
      pint -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  ex|exs)
    if command -v mix &>/dev/null; then
      mix format -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  c|cpp|cc|cxx|h|hpp)
    if command -v clang-format &>/dev/null; then
      clang-format -i -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  dart)
    if command -v dart &>/dev/null; then
      dart format -- "${safe_path}" 2>/dev/null || true
    fi
    ;;
  tf|tfvars)
    if command -v terraform &>/dev/null; then
      terraform fmt "${safe_path}" 2>/dev/null || true
    fi
    ;;
esac

exit 0
