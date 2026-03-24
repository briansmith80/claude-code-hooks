#!/usr/bin/env bash
set -euo pipefail

# Auto-Test: Run the project's test suite after a source file is edited
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

# Skip non-source files — no point running tests for docs, configs, etc.
ext="${file_path##*.}"
ext=$(printf '%s' "${ext}" | tr '[:upper:]' '[:lower:]')
case "${ext}" in
  md|txt|json|yaml|yml|toml|ini|cfg|conf|lock|log|csv|svg|png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot)
    exit 0
    ;;
esac

# Find the project root by walking up from the edited file
project_dir=$(dirname "${file_path}")
while [[ "${project_dir}" != "/" && "${project_dir}" != "${project_dir%/*}" ]]; do
  # Stop if we find a common project root indicator
  for marker in package.json pyproject.toml setup.py go.mod Cargo.toml composer.json mix.exs Gemfile; do
    [[ -f "${project_dir}/${marker}" ]] && break 2
  done
  project_dir=$(dirname "${project_dir}")
done

# If we hit / without finding a project root, bail
[[ "${project_dir}" == "/" ]] && exit 0

# Detect project type and choose test command
test_cmd=()

if [[ -f "${project_dir}/package.json" ]]; then
  # Node.js — detect test runner from package.json
  runner=$(node -e "
    const fs = require('fs');
    try {
      const pkg = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
      const all = Object.assign({}, pkg.devDependencies || {}, pkg.dependencies || {});
      if (all['vitest']) { process.stdout.write('vitest'); }
      else if (all['jest']) { process.stdout.write('jest'); }
      else { process.stdout.write('npm'); }
    } catch { process.stdout.write('npm'); }
  " "${project_dir}/package.json" 2>/dev/null) || runner="npm"

  case "${runner}" in
    vitest) test_cmd=(npx vitest run) ;;
    jest)   test_cmd=(npx jest) ;;
    *)      test_cmd=(npm test) ;;
  esac

elif [[ -f "${project_dir}/pytest.ini" || -f "${project_dir}/pyproject.toml" || -f "${project_dir}/setup.py" ]]; then
  test_cmd=(pytest)

elif [[ -f "${project_dir}/Gemfile" ]]; then
  if [[ -f "${project_dir}/bin/rails" ]]; then
    test_cmd=(bundle exec rails test)
  else
    test_cmd=(bundle exec rspec)
  fi

elif [[ -f "${project_dir}/go.mod" ]]; then
  test_cmd=(go test ./...)

elif [[ -f "${project_dir}/Cargo.toml" ]]; then
  test_cmd=(cargo test)

elif [[ -f "${project_dir}/composer.json" ]]; then
  if [[ -f "${project_dir}/artisan" ]]; then
    test_cmd=(php artisan test)
  else
    test_cmd=(./vendor/bin/phpunit)
  fi

elif [[ -f "${project_dir}/mix.exs" ]]; then
  test_cmd=(mix test)
fi

[[ ${#test_cmd[@]} -eq 0 ]] && exit 0

# Run tests with a timeout to avoid blocking Claude
# Capture output so it appears in the hook result
TIMEOUT_SECONDS=120

run_with_timeout() {
  local secs="$1"; shift
  if command -v timeout &>/dev/null; then
    timeout "${secs}" "$@"
  elif command -v gtimeout &>/dev/null; then
    gtimeout "${secs}" "$@"
  else
    "$@"
  fi
}

output=$(
  cd "${project_dir}" && \
  run_with_timeout "${TIMEOUT_SECONDS}" "${test_cmd[@]}" 2>&1 \
  || true
)

if [[ -n "${output}" ]]; then
  printf "[auto-test] ran: %s\n\n%s\n" "${test_cmd[*]}" "${output}"
fi

exit 0
