#!/bin/bash
# Homey Happiness Pulse — install for the Revenue team.
#
# Self-contained: usable as a single download / one-line curl. Run with:
#
#   curl -sL https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main/Scripts/install-revenue.sh | bash
#
# What this does:
#   1. Removes any previous Homey Pulse install (LaunchAgent + app + leftovers).
#   2. Downloads the latest HappinessPulse.app from GitHub Releases.
#   3. Verifies the SHA-256 (best-effort).
#   4. Writes ~/homey-pulse/config.json baking in this department + webhook URL.
#   5. Installs the run.sh wrapper + Mon–Fri-only LaunchAgent.
#
# After this finishes, the popup posts to the v3 Google Sheet only — never
# back to the v2 sheet.

set -euo pipefail
umask 077

PULSE_DEPARTMENT="Revenue"
PULSE_WEBHOOK_URL="https://script.google.com/macros/s/AKfycbwZbrkn78c7IjYgbjfr56Xhymxh-kADnHFmxHff6seyOVMc5xVaowub4mlCEX_rVA4J/exec"

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

# Step 1 — clean out any v1/v2 install so the new one starts fresh.
echo "  [1/4] Removing previous install (if any)..."
launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PATH" 2>/dev/null || true
pkill -f HappinessPulse 2>/dev/null || true
rm -rf "$APP_PATH" 2>/dev/null || true
rm -f "$BASE_DIR/launch.py" "$BASE_DIR/pulse.sh" "$BASE_DIR/pulse-form.html" "$BASE_DIR/install.sh" "$BASE_DIR/update.sh" 2>/dev/null || true
rm -rf "$BASE_DIR/venv" "$BASE_DIR/__pycache__" 2>/dev/null || true
echo "         Done."

# Step 2 — download the latest .app.
echo "  [2/4] Downloading the latest .app..."
mkdir -p "$BASE_DIR" "$FLAGS_DIR" "$PENDING_DIR" "$LAUNCH_AGENTS_DIR"
if ! curl -sL --connect-timeout 4 --max-time 30 "$RELEASE_URL" -o "$TMP_ZIP"; then
    echo "❌ Download failed. Check your connection or corporate firewall and retry."
    exit 1
fi

if curl -sL --connect-timeout 4 --max-time 8 "$CHECKSUM_URL" -o "$TMP_SHA" 2>/dev/null; then
    EXPECTED_SUM="$(awk '{print $1}' "$TMP_SHA" | tr -d '\n')"
    ACTUAL_SUM="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
    if [ -n "$EXPECTED_SUM" ] && [ "$EXPECTED_SUM" != "$ACTUAL_SUM" ]; then
        echo "❌ Checksum mismatch:"
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

# Step 3 — write config.json. This is what makes the popup department-aware.
echo "  [3/4] Writing department config..."
cat > "$CONFIG_PATH" <<CONFEOF
{
  "department": "$PULSE_DEPARTMENT",
  "webhook_url": "$PULSE_WEBHOOK_URL"
}
CONFEOF
chmod 600 "$CONFIG_PATH"
echo "         $PULSE_DEPARTMENT, posting to v3 sheet."

# Step 4 — write run.sh wrapper + LaunchAgent (Mon–Fri only).
cat > "$BASE_DIR/run.sh" << 'RUNEOF'
#!/bin/bash
export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
LOG="$HOME/homey-pulse/pulse-wrapper.log"
LOCKDIR="$HOME/homey-pulse/.run.lock"

if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 102400 ]; then
    tail -50 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

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

echo "  [4/4] Installing LaunchAgent..."
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

curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"install-revenue-v3\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\",\"department\":\"$PULSE_DEPARTMENT\"}" \
  "$PULSE_WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo ""
echo -e "  ${GREEN}✓ Installed for $PULSE_DEPARTMENT.${NC}"
echo "    The pulse will appear at scheduled times Mon–Fri."
echo "    Logs: $BASE_DIR/launch-agent.log + $BASE_DIR/pulse-wrapper.log"
echo ""
