#!/usr/bin/env bash
set -euo pipefail

# Session Log: Append a markdown summary of each turn
# Stop hook — receives JSON on stdin

input=$(cat)

log_file="${HOME}/.claude/session-log.md"

# Ensure the log directory exists
mkdir -p "$(dirname "${log_file}")"

# Parse stop event JSON and build the markdown entry
entry=$(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      const u = o.usage || {};
      const reason = String(o.stop_reason || 'unknown');
      const inp = u.input_tokens || 0;
      const out = u.output_tokens || 0;
      const cr = u.cache_read_input_tokens || 0;
      const cw = u.cache_creation_input_tokens || 0;
      const cwd = process.cwd();
      const project = require('path').basename(cwd);

      const fmt = n => n.toLocaleString('en-US');

      const now = new Date();
      const pad = v => String(v).padStart(2, '0');
      const ts = now.getFullYear()
        + '-' + pad(now.getMonth() + 1)
        + '-' + pad(now.getDate())
        + ' ' + pad(now.getHours())
        + ':' + pad(now.getMinutes())
        + ':' + pad(now.getSeconds());

      const lines = [
        '### ' + ts + ' — ' + project,
        '',
        '- **Stop reason:** ' + reason,
        '- **Tokens:** ' + fmt(inp) + ' in / ' + fmt(out) + ' out (cache: ' + fmt(cr) + ' read, ' + fmt(cw) + ' write)',
        '- **Working directory:** ' + cwd,
        '',
        '---',
        '',
      ];
      process.stdout.write(lines.join('\n'));
    } catch {}
  });
" 2>/dev/null) || exit 0

[[ -z "${entry}" ]] && exit 0

printf "%s\n" "${entry}" >> "${log_file}"

exit 0
