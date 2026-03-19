#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# claude-hooks — Install pre-built hook packs for Claude Code
# https://github.com/briansmith80/claude-code-hooks
# =============================================================================

VERSION="1.0.0"
HOOKS_DIR="${HOME}/.claude-hooks"
REPO_URL="https://raw.githubusercontent.com/briansmith80/claude-code-hooks/main"

# Resolve script directory (for local pack files when running from cloned repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Available packs (order matters for display)
PACKS=("guard-rails" "auto-format" "notify" "cost-log")

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
print_success() { printf "${GREEN}%s${NC}\n" "$1"; }
print_error()   { printf "${RED}error:${NC} %s\n" "$1" >&2; }
print_warning() { printf "${YELLOW}warning:${NC} %s\n" "$1"; }
print_info()    { printf "${BLUE}::${NC} %s\n" "$1"; }

# ---------------------------------------------------------------------------
# Fetch a URL via curl or wget
# ---------------------------------------------------------------------------
fetch_url() {
  if command -v curl &>/dev/null; then
    curl -fsSL "$1"
  elif command -v wget &>/dev/null; then
    wget -qO- "$1"
  else
    print_error "Neither curl nor wget found."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Pack descriptions (kept in sync with hooks.json _description fields)
# ---------------------------------------------------------------------------
get_pack_description() {
  case "$1" in
    guard-rails)  printf "Protect sensitive files (.env, keys, credentials)" ;;
    auto-format)  printf "Auto-format files after edits (prettier, black, gofmt...)" ;;
    notify)       printf "Desktop notification when Claude needs attention" ;;
    cost-log)     printf "Log token usage per turn to ~/.claude/cost-log.csv" ;;
    *)            printf "Unknown pack" ;;
  esac
}

# ---------------------------------------------------------------------------
# Validate a pack name
# ---------------------------------------------------------------------------
is_valid_pack() {
  local name="$1"
  for p in "${PACKS[@]}"; do
    [[ "${p}" == "${name}" ]] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# List available packs
# ---------------------------------------------------------------------------
list_packs() {
  printf "\n${BOLD}Available Hook Packs${NC}\n\n"
  for pack in "${PACKS[@]}"; do
    local desc
    desc=$(get_pack_description "${pack}")
    printf "  ${CYAN}%-15s${NC} %s\n" "${pack}" "${desc}"
  done
  printf "\n"
}

# ---------------------------------------------------------------------------
# Interactive picker — lets user select one or more packs
# ---------------------------------------------------------------------------
pick_packs() {
  printf "\n${BOLD}Available Hook Packs${NC}\n\n"

  local i=1
  for pack in "${PACKS[@]}"; do
    local desc
    desc=$(get_pack_description "${pack}")
    printf "  ${CYAN}%d)${NC} %-15s %s\n" "${i}" "${pack}" "${desc}"
    ((i++))
  done

  printf "\n"
  printf "${BOLD}Select packs to install ${DIM}(comma-separated numbers, or 'all')${NC}: "

  local choice
  if [[ -t 0 ]]; then
    read -r choice
  elif [[ -e /dev/tty ]]; then
    read -r choice < /dev/tty
  else
    print_error "No interactive terminal available. Specify packs as arguments."
    exit 1
  fi

  SELECTED_PACKS=()

  if [[ "${choice}" == "all" || "${choice}" == "a" ]]; then
    SELECTED_PACKS=("${PACKS[@]}")
    return
  fi

  # Parse comma/space-separated numbers
  IFS=', ' read -ra nums <<< "${choice}"
  for num in "${nums[@]}"; do
    num=$(echo "${num}" | tr -d '[:space:]')
    [[ -z "${num}" ]] && continue
    if [[ "${num}" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#PACKS[@]} )); then
      SELECTED_PACKS+=("${PACKS[$((num - 1))]}")
    else
      print_warning "Ignoring invalid selection: ${num}"
    fi
  done

  if [[ ${#SELECTED_PACKS[@]} -eq 0 ]]; then
    print_error "No packs selected."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Install a single pack — download scripts + merge config
# ---------------------------------------------------------------------------
install_pack() {
  local pack="$1"
  local settings_file="$2"

  local pack_dir="${HOOKS_DIR}/${pack}"
  mkdir -p "${pack_dir}"

  # -----------------------------------------------------------------------
  # 1. Load hooks.json (local repo first, then remote)
  # -----------------------------------------------------------------------
  local hooks_json
  local local_file="${SCRIPT_DIR}/hooks/${pack}/hooks.json"

  if [[ -f "${local_file}" ]]; then
    hooks_json=$(cat "${local_file}")
  else
    hooks_json=$(fetch_url "${REPO_URL}/hooks/${pack}/hooks.json")
  fi

  # -----------------------------------------------------------------------
  # 2. Download / copy hook scripts listed in _scripts
  # -----------------------------------------------------------------------
  local scripts
  scripts=$(printf '%s' "${hooks_json}" | node -e "
    let d = '';
    process.stdin.on('data', c => d += c);
    process.stdin.on('end', () => {
      const o = JSON.parse(d);
      (o._scripts || []).forEach(s => console.log(s));
    });
  " 2>/dev/null) || true

  while IFS= read -r script; do
    [[ -z "${script}" ]] && continue
    # Validate script name — block path traversal
    if [[ "${script}" == */* || "${script}" == *..* ]]; then
      print_warning "Skipping suspicious script name: ${script}"
      continue
    fi
    local local_script="${SCRIPT_DIR}/hooks/${pack}/${script}"
    if [[ -f "${local_script}" ]]; then
      cp "${local_script}" "${pack_dir}/${script}"
    else
      fetch_url "${REPO_URL}/hooks/${pack}/${script}" > "${pack_dir}/${script}"
    fi
    chmod +x "${pack_dir}/${script}"
  done <<< "${scripts}"

  # -----------------------------------------------------------------------
  # 3. Merge hooks config into settings.json
  # -----------------------------------------------------------------------
  merge_hooks "${hooks_json}" "${settings_file}"

  print_success "  Installed: ${pack}"
}

# ---------------------------------------------------------------------------
# Merge a pack's hooks config into the target settings file
# ---------------------------------------------------------------------------
merge_hooks() {
  local pack_json="$1"
  local settings_file="$2"

  printf '%s' "${pack_json}" | node -e "
    const fs = require('fs');
    const path = require('path');

    let packRaw = '';
    process.stdin.on('data', c => packRaw += c);
    process.stdin.on('end', () => {
      const packData = JSON.parse(packRaw);
      const settingsFile = process.argv[1];
      const hooksDir = process.argv[2];

      // Read existing settings — distinguish missing file from bad JSON
      let settings = {};
      try {
        const raw = fs.readFileSync(settingsFile, 'utf8');
        settings = JSON.parse(raw);
      } catch (e) {
        if (e.code !== 'ENOENT') {
          process.stderr.write('Error: ' + settingsFile + ' contains invalid JSON. Fix it before installing hooks.\n');
          process.exit(1);
        }
      }

      if (!settings.hooks) settings.hooks = {};

      const packHooks = packData.hooks || {};

      for (const [event, rules] of Object.entries(packHooks)) {
        if (!settings.hooks[event]) settings.hooks[event] = [];

        for (const rule of rules) {
          // Replace placeholder with actual install path
          const ruleStr = JSON.stringify(rule).replace(/__HOOKS_DIR__/g, hooksDir);
          const processed = JSON.parse(ruleStr);

          // Deduplicate by comparing hook commands
          const newCmds = (processed.hooks || []).map(h => h.command).sort().join('|');
          const isDupe = settings.hooks[event].some(existing => {
            const existCmds = (existing.hooks || []).map(h => h.command).sort().join('|');
            return existCmds === newCmds;
          });

          if (!isDupe) {
            settings.hooks[event].push(processed);
          }
        }
      }

      // Atomic write: write to temp file, then rename
      const tmpFile = settingsFile + '.tmp';
      fs.writeFileSync(tmpFile, JSON.stringify(settings, null, 2) + '\n');
      fs.renameSync(tmpFile, settingsFile);
    });
  " "${settings_file}" "${HOOKS_DIR}"
}

# ---------------------------------------------------------------------------
# Show help
# ---------------------------------------------------------------------------
show_help() {
  printf "\n${BOLD}claude-hooks${NC} v${VERSION}\n"
  printf "Install pre-built hook packs for Claude Code.\n\n"
  printf "${BOLD}Usage:${NC}\n"
  printf "  claude-hooks                       Interactive pack picker\n"
  printf "  claude-hooks <pack> [<pack>...]     Install specific pack(s)\n"
  printf "  claude-hooks --list                 List available packs\n"
  printf "  claude-hooks --help                 Show this help\n"
  printf "  claude-hooks --version              Show version\n"
  printf "\n"
  printf "${BOLD}Options:${NC}\n"
  printf "  --local        Write to settings.local.json instead of settings.json\n"
  printf "\n"
  printf "${BOLD}Examples:${NC}\n"
  printf "  claude-hooks guard-rails            Install guard-rails pack\n"
  printf "  claude-hooks guard-rails notify     Install multiple packs\n"
  printf "  claude-hooks --local auto-format    Install to local settings\n"
  printf "\n"
}

# ===========================================================================
# Main
# ===========================================================================

USE_LOCAL=false
SELECTED_PACKS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --list|-l)
      list_packs
      exit 0
      ;;
    --local)
      USE_LOCAL=true
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    --version|-v)
      printf "claude-hooks v%s\n" "${VERSION}"
      exit 0
      ;;
    -*)
      print_error "Unknown option: $1"
      printf "Run ${CYAN}claude-hooks --help${NC} for usage.\n"
      exit 1
      ;;
    *)
      if is_valid_pack "$1"; then
        SELECTED_PACKS+=("$1")
      else
        print_error "Unknown pack: $1"
        printf "Run ${CYAN}claude-hooks --list${NC} to see available packs.\n"
        exit 1
      fi
      ;;
  esac
  shift
done

# Check for node (required for JSON merging and hook scripts)
if ! command -v node &>/dev/null; then
  print_error "Node.js is required but not found. Claude Code requires Node.js — please install it first."
  exit 1
fi

# Interactive picker if no packs specified
if [[ ${#SELECTED_PACKS[@]} -eq 0 ]]; then
  pick_packs
fi

# Determine target settings file
if [[ "${USE_LOCAL}" == true ]]; then
  SETTINGS_FILE=".claude/settings.local.json"
else
  SETTINGS_FILE=".claude/settings.json"
fi

# Ensure .claude directory and settings file exist
mkdir -p ".claude"
if [[ ! -f "${SETTINGS_FILE}" ]]; then
  printf "{}\n" > "${SETTINGS_FILE}"
fi

# Print header
printf "\n${BOLD}Installing hook packs...${NC}\n\n"

# Install each selected pack
for pack in "${SELECTED_PACKS[@]}"; do
  install_pack "${pack}" "${SETTINGS_FILE}"
done

# Summary
printf "\n${GREEN}${BOLD}Done!${NC} "
printf "Installed %d pack(s) into ${CYAN}%s${NC}\n" "${#SELECTED_PACKS[@]}" "${SETTINGS_FILE}"
printf "Hook scripts saved to ${CYAN}%s${NC}\n\n" "${HOOKS_DIR}"
printf "${DIM}Restart Claude Code for hooks to take effect.${NC}\n\n"
