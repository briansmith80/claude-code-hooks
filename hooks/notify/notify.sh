#!/usr/bin/env bash
set -euo pipefail

# Notify: Send a desktop notification when Claude finishes a turn
# Stop hook — receives JSON with stop_reason, token counts on stdin

input=$(cat)

# Parse stop reason from Stop event JSON
message=$(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      const reason = o.stop_reason || 'done';
      process.stdout.write('Claude is ' + reason);
    } catch { process.stdout.write('Claude finished'); }
  });
" 2>/dev/null) || message="Claude finished"

title="Claude Code"

# Send notification using platform-appropriate method
# All methods pass message via environment variable or argv to avoid injection
case "$(uname -s)" in
  Darwin)
    # Pass title and message as AppleScript arguments — no string interpolation
    osascript - "${title}" "${message}" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
APPLESCRIPT
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send -- "${title}" "${message}" 2>/dev/null || true
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Pass message via environment variable — no string interpolation in PowerShell
    NOTIFY_TITLE="${title}" NOTIFY_MSG="${message}" \
      powershell.exe -NoProfile -Command '
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.BalloonTipTitle = $env:NOTIFY_TITLE
        $n.BalloonTipText = $env:NOTIFY_MSG
        $n.Visible = $true
        $n.ShowBalloonTip(3000)
        Start-Sleep -Milliseconds 1500
        $n.Dispose()
      ' 2>/dev/null || true
    ;;
esac

exit 0
