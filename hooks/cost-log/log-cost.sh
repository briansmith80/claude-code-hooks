#!/usr/bin/env bash
set -euo pipefail

# Cost Log: Append token usage to a CSV after each turn
# Stop hook — receives JSON on stdin

input=$(cat)

log_file="${HOME}/.claude/cost-log.csv"

# Create log file with header if it doesn't exist
if [[ ! -f "${log_file}" ]]; then
  mkdir -p "$(dirname "${log_file}")"
  printf "timestamp,stop_reason,input_tokens,output_tokens,cache_read,cache_write\n" > "${log_file}"
fi

# Parse usage data via stdin to node (avoids ARG_MAX and process list exposure)
# Quote stop_reason to prevent CSV injection
line=$(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      const u = o.usage || {};
      const ts = new Date().toISOString();
      let reason = String(o.stop_reason || 'unknown');
      // CSV-safe: quote the field and escape embedded quotes
      reason = '\"' + reason.replace(/\"/g, '\"\"') + '\"';
      const inp = u.input_tokens || 0;
      const out = u.output_tokens || 0;
      const cr = u.cache_read_input_tokens || 0;
      const cw = u.cache_creation_input_tokens || 0;
      process.stdout.write([ts, reason, inp, out, cr, cw].join(','));
    } catch {}
  });
" 2>/dev/null) || exit 0

[[ -z "${line}" ]] && exit 0

printf "%s\n" "${line}" >> "${log_file}"

exit 0
