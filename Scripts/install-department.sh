#!/bin/bash
# Shared install logic for the v3 per-department installers.
# This file is sourced/exec'd by the four thin wrappers
# (install-operations.sh, install-revenue.sh, install-service.sh,
# install-technology.sh).
#
# The wrappers each export:
#   PULSE_DEPARTMENT — one of: Operations | Revenue | Service | Technology
#   PULSE_WEBHOOK_URL — the v3 Apps Script web app URL (NEW Google Sheet)
# before sourcing this file.
#
# This script:
#   1. Validates the env vars
#   2. Removes any v2.x install (LaunchAgent + app + leftover plist)
#   3. Downloads the latest HappinessPulse.app release zip
#   4. Verifies SHA-256 (best-effort — warns if checksum unavailable)
#   5. Writes ~/homey-pulse/config.json with department + webhook_url
#   6. Installs the LaunchAgent with the v3 weekday-only schedule
#
# After this runs, the laptop posts ONLY to the v3 sheet — never to the
# v2 sheet again until the user explicitly reinstalls v2.

set -euo pipefail
umask 077

if [ -z "${PULSE_DEPARTMENT:-}" ]; then
    echo "❌ PULSE_DEPARTMENT not set; do not run this file directly."
    echo "   Use install-operations.sh / install-revenue.sh / install-service.sh / install-technology.sh."
    exit 1
fi

case "$PULSE_DEPARTMENT" in
    Operations|Revenue|Service|Technology) ;;
    *)
        echo "❌ Unknown department: $PULSE_DEPARTMENT"
        exit 1
        ;;
esac

if [ -z "${PULSE_WEBHOOK_URL:-}" ] || [ "$PULSE_WEBHOOK_URL" = "__WEBHOOK_URL__" ]; then
    echo "❌ PULSE_WEBHOOK_URL is not configured."
    echo "   The CI team needs to fill in the v3 Apps Script web-app URL"
    echo "   in install-${PULSE_DEPARTMENT,,}.sh before this can be run."
    exit 1
fi

case "$PULSE_WEBHOOK_URL" in
    https://*) ;;
    *)
        echo "❌ PULSE_WEBHOOK_URL must be an https:// URL. Got: $PULSE_WEBHOOK_URL"
        exit 1
        ;;
esac

BASE_DIR="$HOME/homey-pulse"
APP_NAME="HappinessPulse.app"
APP_PATH="$BASE_DIR/$APP_NAME"
FLAGS_DIR="$BASE_DIR/flags"
PENDING_DIR="$BASE_DIR/pending"
CONFIG_PATH="$BASE_DIR/config.json"
LAUNCH_AGENT_ID="uk.co.homey.pulse"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/${LAUNCH_AGENT_ID}.plist"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ARCH="$(uname -m)"
case "$ARCH" in
    arm64|x86_64) ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

RELEASE_URL="https://github.com/reema-nazeer/happiness-pulse/releases/latest/download/HappinessPulse-${ARCH}.zip"
CHECKSUM_URL="${RELEASE_URL}.sha256"
TMP_ZIP="$(mktemp "/tmp/homey-pulse-${ARCH}.XXXXXX.zip")"
TMP_SHA="$(mktemp "/tmp/homey-pulse-${ARCH}.XXXXXX.sha256")"
TMP_UNZIP_DIR="$(mktemp -d "/tmp/homey-pulse-unzip.XXXXXX")"
cleanup() {
    rm -f "$TMP_ZIP" 2>/dev/null || true
    rm -f "$TMP_SHA" 2>/dev/null || true
    rm -rf "$TMP_UNZIP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "  ⚡ Homey Happiness Pulse — installing for $PULSE_DEPARTMENT"
echo "  ==========================================="
echo ""

# Step 1: clean out any v2 / old residue so the new install is clean.
echo "  [1/4] Removing previous install (if any)..."
launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PATH" 2>/dev/null || true
pkill -f HappinessPulse 2>/dev/null || true
rm -rf "$APP_PATH" 2>/dev/null || true
# v1 (Python) leftovers
rm -f "$BASE_DIR/launch.py" "$BASE_DIR/pulse.sh" "$BASE_DIR/pulse-form.html" "$BASE_DIR/install.sh" "$BASE_DIR/update.sh" 2>/dev/null || true
rm -rf "$BASE_DIR/venv" "$BASE_DIR/__pycache__" 2>/dev/null || true
echo "         Done."

# Step 2: download release.
echo "  [2/4] Downloading latest .app from GitHub Releases..."
mkdir -p "$BASE_DIR" "$FLAGS_DIR" "$PENDING_DIR" "$LAUNCH_AGENTS_DIR"
if ! curl -sL --connect-timeout 4 --max-time 30 "$RELEASE_URL" -o "$TMP_ZIP"; then
    echo "❌ Failed to download. Check your connection or corporate firewall and retry."
    exit 1
fi

# Checksum: best-effort. Warn but continue if unavailable.
if curl -sL --connect-timeout 4 --max-time 8 "$CHECKSUM_URL" -o "$TMP_SHA" 2>/dev/null; then
    EXPECTED_SUM="$(awk '{print $1}' "$TMP_SHA" | tr -d '\n')"
    ACTUAL_SUM="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
    if [ -n "$EXPECTED_SUM" ] && [ "$EXPECTED_SUM" != "$ACTUAL_SUM" ]; then
        echo "❌ Checksum verification failed."
        echo "   Expected: $EXPECTED_SUM"
        echo "   Actual:   $ACTUAL_SUM"
        exit 1
    fi
fi

if ! unzip -q "$TMP_ZIP" -d "$TMP_UNZIP_DIR"; then
    echo "❌ Downloaded archive is corrupt."
    exit 1
fi
if [ ! -d "$TMP_UNZIP_DIR/$APP_NAME" ]; then
    echo "❌ Archive did not contain $APP_NAME"
    exit 1
fi
mv "$TMP_UNZIP_DIR/$APP_NAME" "$APP_PATH"
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
echo "         App installed."

# Step 3: write config.json — this is what makes the popup department-aware.
echo "  [3/4] Writing department config..."
cat > "$CONFIG_PATH" <<CONFEOF
{
  "department": "$PULSE_DEPARTMENT",
  "webhook_url": "$PULSE_WEBHOOK_URL"
}
CONFEOF
chmod 600 "$CONFIG_PATH"
echo "         $PULSE_DEPARTMENT, posting to v3 sheet."

# Step 4: write run.sh wrapper + LaunchAgent.
cat > "$BASE_DIR/run.sh" << 'RUNEOF'
#!/bin/bash
export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
LOG="$HOME/homey-pulse/pulse-wrapper.log"
LOCKDIR="$HOME/homey-pulse/.run.lock"

# Rotate log if over 100KB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 102400 ]; then
    tail -50 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

# Atomic single-instance lock via mkdir.
if ! mkdir "$LOCKDIR" 2>/dev/null; then
    if [ -d "$LOCKDIR" ]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f%m "$LOCKDIR" 2>/dev/null || echo 0) ))
        if [ "$LOCK_AGE" -gt 600 ]; then
            echo "$(date): Removing stale lock (${LOCK_AGE}s old)" >> "$LOG"
            rm -rf "$LOCKDIR"
            mkdir "$LOCKDIR" 2>/dev/null || { echo "$(date): Failed to acquire lock after stale removal" >> "$LOG"; exit 0; }
        else
            echo "$(date): Another instance running (lock ${LOCK_AGE}s old), exiting" >> "$LOG"
            exit 0
        fi
    fi
else
    echo "$(date): Lock acquired, PID=$$" >> "$LOG"
fi
trap 'rm -rf "$LOCKDIR" 2>/dev/null' EXIT

# Skip if already submitted today.
TODAY="$(date +%Y-%m-%d)"
if [ -f "$HOME/homey-pulse/flags/$TODAY" ]; then
    echo "$(date): Already submitted today ($TODAY), exiting" >> "$LOG"
    exit 0
fi

echo "$(date): Launching app, HOME=$HOME, PID=$$" >> "$LOG"
"$HOME/homey-pulse/HappinessPulse.app/Contents/MacOS/HappinessPulse" >> "$LOG" 2>&1
echo "$(date): App exited with code $?" >> "$LOG"
RUNEOF
chmod +x "$BASE_DIR/run.sh"

echo "  [4/4] Installing LaunchAgent (Mon–Fri schedule)..."
cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>uk.co.homey.pulse</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/homey-pulse/run.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StartCalendarInterval</key>
    <array>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>11</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>14</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>3</integer><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
        <dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>16</integer><key>Minute</key><integer>0</integer></dict>
    </array>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>10</integer>
    <key>LimitLoadToSessionType</key>
    <array>
        <string>Aqua</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/homey-pulse/launch-agent.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/homey-pulse/launch-agent.log</string>
</dict>
</plist>
EOF

launchctl load "$LAUNCH_AGENT_PATH"

# Track install (best-effort) — uses the v3 webhook so it lands in the new sheet.
curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"install-${PULSE_DEPARTMENT,,}-v3\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\",\"department\":\"$PULSE_DEPARTMENT\"}" \
  "$PULSE_WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo ""
echo -e "  ${GREEN}✓ Installed for $PULSE_DEPARTMENT.${NC}"
echo "    The pulse will appear at scheduled times Mon–Fri."
echo "    Logs: $BASE_DIR/launch-agent.log + $BASE_DIR/pulse-wrapper.log"
echo ""
