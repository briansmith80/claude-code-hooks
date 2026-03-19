#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# claude-code-hooks installer
# Usage: curl -fsSL https://raw.githubusercontent.com/briansmith80/claude-code-hooks/main/install.sh | bash
# =============================================================================

REPO_URL="https://raw.githubusercontent.com/briansmith80/claude-code-hooks/main"
INSTALL_DIR="${HOME}/.claude-hooks"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
print_success() { printf "${GREEN}%s${NC}\n" "$1"; }
print_error()   { printf "${RED}error:${NC} %s\n" "$1" >&2; }
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

# ===========================================================================
# Main
# ===========================================================================

printf "\n${BOLD}claude-code-hooks installer${NC}\n\n"

# ---------------------------------------------------------------------------
# 1. Download the main CLI script
# ---------------------------------------------------------------------------
printf "Downloading claude-hooks CLI...\n"
mkdir -p "${INSTALL_DIR}"
fetch_url "${REPO_URL}/claude-hooks.sh" > "${INSTALL_DIR}/claude-hooks.sh"
chmod +x "${INSTALL_DIR}/claude-hooks.sh"
print_success "Saved to ${INSTALL_DIR}/claude-hooks.sh"

# ---------------------------------------------------------------------------
# 2. Add shell alias
# ---------------------------------------------------------------------------
ALIAS_LINE="alias claude-hooks='${INSTALL_DIR}/claude-hooks.sh'"

add_alias() {
  local rc_file="$1"

  # Skip if alias already present
  if grep -qF "alias claude-hooks=" "${rc_file}" 2>/dev/null; then
    printf "${DIM}Alias already exists in %s${NC}\n" "${rc_file}"
    return
  fi

  printf "\n# claude-code-hooks\n%s\n" "${ALIAS_LINE}" >> "${rc_file}"
  print_success "Added alias to ${rc_file}"
}

prompt_add_alias() {
  local rc_file="$1"
  local shell_name="$2"

  printf "\nAdd ${CYAN}claude-hooks${NC} alias to ${CYAN}%s${NC}? [Y/n] " "${rc_file}"

  local answer
  if [[ -t 0 ]]; then
    read -r answer
  elif [[ -e /dev/tty ]]; then
    read -r answer < /dev/tty
  else
    answer="y"
  fi

  case "${answer}" in
    [nN]*)
      printf "${DIM}Skipped. You can add it manually:${NC}\n"
      printf "  %s\n" "${ALIAS_LINE}"
      ;;
    *)
      add_alias "${rc_file}"
      ;;
  esac
}

# Detect shell and offer to add alias
if [[ -f "${HOME}/.zshrc" ]]; then
  prompt_add_alias "${HOME}/.zshrc" "zsh"
elif [[ -f "${HOME}/.bashrc" ]]; then
  prompt_add_alias "${HOME}/.bashrc" "bash"
elif [[ -f "${HOME}/.bash_profile" ]]; then
  prompt_add_alias "${HOME}/.bash_profile" "bash"
else
  # Git Bash on Windows or unknown shell — try .bashrc
  prompt_add_alias "${HOME}/.bashrc" "bash"
fi

# ---------------------------------------------------------------------------
# 3. Done
# ---------------------------------------------------------------------------
printf "\n${GREEN}${BOLD}Installation complete!${NC}\n\n"
printf "Open a new terminal, then:\n\n"
printf "  ${CYAN}cd your-project${NC}\n"
printf "  ${CYAN}claude-hooks${NC}              # interactive picker\n"
printf "  ${CYAN}claude-hooks --list${NC}       # see available packs\n"
printf "  ${CYAN}claude-hooks guard-rails${NC}  # install a specific pack\n"
printf "\n"
