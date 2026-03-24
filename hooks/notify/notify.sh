#!/usr/bin/env bash
set -euo pipefail

# Notify: Send a desktop notification when Claude finishes a turn
# Stop hook — receives JSON with stop_reason, token counts on stdin

# ---------------------------------------------------------------------------
# Config defaults (override via ~/.claude-hooks/notify/config)
# ---------------------------------------------------------------------------
NOTIFY_SOUND=true
NOTIFY_SOUND_FILE=""
NOTIFY_MIN_DURATION=0
NOTIFY_ONLY_UNFOCUSED=false

CONFIG_FILE="${HOME}/.claude-hooks/notify/config"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck source=/dev/null
  source "${CONFIG_FILE}"
fi

# ---------------------------------------------------------------------------
# Read and parse stdin
# ---------------------------------------------------------------------------
input=$(cat)

# Parse stop reason and duration from Stop event JSON
IFS=$'\t' read -r message duration < <(printf '%s' "${input}" | node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try {
      const o = JSON.parse(d);
      const reason = o.stop_reason || 'done';
      const dur = Math.round((o.duration_ms || 0) / 1000);
      process.stdout.write('Claude is ' + reason + '\t' + dur);
    } catch { process.stdout.write('Claude finished\t0'); }
  });
" 2>/dev/null) || { message="Claude finished"; duration=0; }

# ---------------------------------------------------------------------------
# Skip if turn was too short
# ---------------------------------------------------------------------------
if (( duration < NOTIFY_MIN_DURATION )); then
  exit 0
fi

# ---------------------------------------------------------------------------
# Skip if terminal is focused (when configured)
# ---------------------------------------------------------------------------
if [[ "${NOTIFY_ONLY_UNFOCUSED}" == true ]]; then
  case "$(uname -s)" in
    Darwin)
      # Check if Terminal/iTerm is the frontmost app
      front=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null) || front=""
      if [[ "${front}" == "Terminal" || "${front}" == "iTerm2" ]]; then
        exit 0
      fi
      ;;
    Linux)
      if command -v xdotool &>/dev/null; then
        active_pid=$(xdotool getactivewindow getwindowpid 2>/dev/null) || active_pid=""
        if [[ "${active_pid}" == "$$" || "${active_pid}" == "${PPID}" ]]; then
          exit 0
        fi
      fi
      ;;
    # Windows (MINGW/MSYS/CYGWIN): focus detection is not supported.
    # Notifications will always be sent regardless of window focus.
  esac
fi

title="Claude Code"

# ---------------------------------------------------------------------------
# Send notification using platform-appropriate method
# ---------------------------------------------------------------------------
case "$(uname -s)" in
  Darwin)
    if [[ "${NOTIFY_SOUND}" == true && -n "${NOTIFY_SOUND_FILE}" ]]; then
      afplay "${NOTIFY_SOUND_FILE}" &
    fi
    osascript - "${title}" "${message}" "${NOTIFY_SOUND}" <<'APPLESCRIPT' 2>/dev/null || true
on run argv
  if (item 3 of argv) is "true" then
    display notification (item 2 of argv) with title (item 1 of argv) sound name "default"
  else
    display notification (item 2 of argv) with title (item 1 of argv)
  end if
end run
APPLESCRIPT
    ;;
  Linux)
    if command -v notify-send &>/dev/null; then
      notify-send -- "${title}" "${message}" 2>/dev/null || true
    fi
    if [[ "${NOTIFY_SOUND}" == true ]]; then
      if [[ -n "${NOTIFY_SOUND_FILE}" ]]; then
        paplay "${NOTIFY_SOUND_FILE}" 2>/dev/null || aplay "${NOTIFY_SOUND_FILE}" 2>/dev/null || true
      else
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || true
      fi
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    NOTIFY_TITLE="${title}" NOTIFY_MSG="${message}" \
    NOTIFY_SOUND_ENABLED="${NOTIFY_SOUND}" NOTIFY_SOUND_PATH="${NOTIFY_SOUND_FILE}" \
      powershell.exe -NoProfile -Command '
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.BalloonTipTitle = $env:NOTIFY_TITLE
        $n.BalloonTipText = $env:NOTIFY_MSG
        $n.Visible = $true
        $n.ShowBalloonTip(3000)
        if ($env:NOTIFY_SOUND_ENABLED -eq "true") {
          if ($env:NOTIFY_SOUND_PATH -and (Test-Path $env:NOTIFY_SOUND_PATH)) {
            (New-Object Media.SoundPlayer $env:NOTIFY_SOUND_PATH).PlaySync()
          } else {
            [System.Media.SystemSounds]::Asterisk.Play()
          }
        }
        Start-Sleep -Milliseconds 1500
        $n.Dispose()
      ' 2>/dev/null || true
    ;;
esac

exit 0
