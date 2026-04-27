#!/bin/bash
# Homey Pulse — in-place updater.
# Preserves per-user state (saved department, daily flag files) across updates.
# Runs `python3 -m py_compile` on the new launch.py to catch syntax errors
# before the user's next launch.

BASE="https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main"
WH="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
D="$HOME/homey-pulse"

# Preserve per-user state — neither of these should be touched by an update:
#   $D/department  saved department (pre-selected on next launch)
#   $D/flags/      one file per day to dedupe the popup
# (Listing them here is documentation; we simply don't delete them below.)

# Refresh the executable bits
curl -sL "$BASE/pulse-form.html" -o "$D/pulse-form.html"
curl -sL "$BASE/pulse.sh"        -o "$D/pulse.sh"
curl -sL "$BASE/launch.py"       -o "$D/launch.py"
chmod +x "$D/pulse.sh"

# Refresh assets (best-effort — form has inline SVG fallback)
mkdir -p "$D/assets"
curl -sL --fail "$BASE/assets/homey-logo.svg"        -o "$D/assets/homey-logo.svg"        2>/dev/null
curl -sL --fail "$BASE/assets/homey-logo.png"        -o "$D/assets/homey-logo.png"        2>/dev/null
curl -sL --fail "$BASE/assets/homey-logo-white.svg"  -o "$D/assets/homey-logo-white.svg"  2>/dev/null
curl -sL --fail "$BASE/assets/homey-logo-white.png"  -o "$D/assets/homey-logo-white.png"  2>/dev/null

# Make sure the flags directory still exists in case it was wiped
mkdir -p "$D/flags"

# Discard old launcher tmp renders (stateless)
rm -f /tmp/homey-pulse-*

# Syntax-check the new launch.py before the next scheduled run hits a
# broken popup. Pick the first python3 that's available.
PY=""
for candidate in /opt/homebrew/bin/python3 /usr/bin/python3 python3; do
  if command -v "$candidate" >/dev/null 2>&1; then
    PY="$candidate"
    break
  fi
done

COMPILE_RESULT=""
if [ -n "$PY" ]; then
  if "$PY" -m py_compile "$D/launch.py" >/tmp/homey-pulse-update-syntax.log 2>&1; then
    COMPILE_RESULT="ok"
  else
    COMPILE_RESULT="failed"
  fi
fi

# Report install/update to the webhook (best-effort)
curl -sL -X POST "$WH" \
  -H "Content-Type: text/plain" \
  -d "{\"type\":\"update\",\"username\":\"$(whoami)\",\"source\":\"update\"}" \
  > /dev/null 2>&1

if [ "$COMPILE_RESULT" = "ok" ]; then
  echo "✅ Updated! launch.py compiled cleanly."
elif [ "$COMPILE_RESULT" = "failed" ]; then
  echo "⚠️  Updated, but launch.py has a syntax error:"
  echo ""
  cat /tmp/homey-pulse-update-syntax.log
  echo ""
  echo "    The previous version is the one already on disk. The next scheduled"
  echo "    run will fail until this is fixed. Send the error above to the CI team."
  exit 1
else
  echo "✅ Updated! (couldn't find python3 to syntax-check launch.py — will surface at next run if there's an issue)"
fi
