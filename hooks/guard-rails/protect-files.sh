#!/usr/bin/env bash
set -euo pipefail

# Guard Rails: Block edits to sensitive files
# PreToolUse hook for Edit|Write — receives JSON on stdin

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

# No file path means nothing to protect
[[ -z "${file_path}" ]] && exit 0

# Resolve symlinks and normalize path when possible
if command -v realpath &>/dev/null; then
  resolved=$(realpath -m "${file_path}" 2>/dev/null) || resolved="${file_path}"
elif command -v readlink &>/dev/null; then
  resolved=$(readlink -f "${file_path}" 2>/dev/null) || resolved="${file_path}"
else
  resolved="${file_path}"
fi

basename=$(basename "${resolved}")

# Enable case-insensitive matching (protects against .ENV on Windows/macOS)
shopt -s nocasematch

# Allow known template/example files before blocking .env.* patterns
case "${basename}" in
  .env.example|.env.sample|.env.template|.env.test|.env.dist)
    exit 0
    ;;
esac

# Check filename patterns
case "${basename}" in
  .env|.env.*)
    printf '{"decision":"block","reason":"guard-rails: .env files contain secrets and are protected from modification."}\n'
    exit 0
    ;;
  *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore)
    printf '{"decision":"block","reason":"guard-rails: Key/certificate files are protected from modification."}\n'
    exit 0
    ;;
  id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|id_ecdsa|id_ecdsa.*)
    printf '{"decision":"block","reason":"guard-rails: SSH key files are protected from modification."}\n'
    exit 0
    ;;
  credentials|credentials.*|*secret*|*.secret)
    printf '{"decision":"block","reason":"guard-rails: Credential/secret files are protected from modification."}\n'
    exit 0
    ;;
  .npmrc|.pypirc|.netrc|.htpasswd)
    printf '{"decision":"block","reason":"guard-rails: Auth config files are protected from modification."}\n'
    exit 0
    ;;
  service-account*.json|*-credentials.json)
    printf '{"decision":"block","reason":"guard-rails: Cloud service account files are protected from modification."}\n'
    exit 0
    ;;
esac

# Check directory patterns (use resolved path for symlink protection)
case "${resolved}" in
  */.ssh/*|*/.gnupg/*)
    printf '{"decision":"block","reason":"guard-rails: Files in ~/.ssh and ~/.gnupg are protected."}\n'
    exit 0
    ;;
  */.aws/credentials*|*/.config/gcloud/*|*/.kube/config*)
    printf '{"decision":"block","reason":"guard-rails: Cloud credential files are protected."}\n'
    exit 0
    ;;
  */.docker/config.json)
    printf '{"decision":"block","reason":"guard-rails: Docker credential files are protected."}\n'
    exit 0
    ;;
esac

shopt -u nocasematch
printf '{"decision":"allow"}\n'
exit 0
