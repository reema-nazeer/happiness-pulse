#!/bin/bash
set -euo pipefail
umask 077

WEBHOOK_URL="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
BASE_DIR="$HOME/homey-pulse"
APP_NAME="HappinessPulse.app"
APP_PATH="$BASE_DIR/$APP_NAME"
FLAGS_DIR="$BASE_DIR/flags"
PENDING_DIR="$BASE_DIR/pending"
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

# Clean up old v1 files if upgrading
rm -f "$BASE_DIR/launch.py" "$BASE_DIR/pulse.sh" "$BASE_DIR/pulse-form.html" "$BASE_DIR/install.sh" "$BASE_DIR/update.sh" 2>/dev/null || true
rm -rf "$BASE_DIR/venv" "$BASE_DIR/__pycache__" 2>/dev/null || true

mkdir -p "$BASE_DIR" "$FLAGS_DIR" "$PENDING_DIR" "$LAUNCH_AGENTS_DIR"

if ! curl -sL --connect-timeout 4 --max-time 8 "$RELEASE_URL" -o "$TMP_ZIP"; then
    echo "Failed to download Homey Happiness Pulse from GitHub Releases."
    echo "Check your connection or corporate firewall and try again."
    exit 1
fi

# Checksum verification (optional - warn but continue if unavailable)
if curl -sL --connect-timeout 4 --max-time 8 "$CHECKSUM_URL" -o "$TMP_SHA" 2>/dev/null; then
    EXPECTED_SUM="$(awk '{print $1}' "$TMP_SHA" | tr -d '\n')"
    ACTUAL_SUM="$(shasum -a 256 "$TMP_ZIP" | awk '{print $1}')"
    if [ -n "$EXPECTED_SUM" ] && [ "$EXPECTED_SUM" != "$ACTUAL_SUM" ]; then
        echo "Checksum verification failed for downloaded package."
        echo "Expected: $EXPECTED_SUM"
        echo "Actual:   $ACTUAL_SUM"
        exit 1
    fi
else
    echo "Warning: Could not download checksum file. Skipping verification."
fi

if ! unzip -q "$TMP_ZIP" -d "$TMP_UNZIP_DIR"; then
    echo "Downloaded package is invalid or corrupted."
    exit 1
fi

if [ ! -d "$TMP_UNZIP_DIR/$APP_NAME" ]; then
    echo "Release archive did not contain $APP_NAME."
    exit 1
fi

rm -rf "$APP_PATH"
mv "$TMP_UNZIP_DIR/$APP_NAME" "$APP_PATH"
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

# Create wrapper script for launchd compatibility
# launchd launches apps in a minimal environment which can cause silent failures.
# The wrapper ensures HOME, PATH, and logging are set up correctly.
cat > "$BASE_DIR/run.sh" << 'RUNEOF'
#!/bin/bash
export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
LOG="$HOME/homey-pulse/pulse-wrapper.log"

# Rotate log if over 100KB
if [ -f "$LOG" ] && [ "$(stat -f%z "$LOG" 2>/dev/null || echo 0)" -gt 102400 ]; then
    tail -50 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
fi

echo "$(date): Wrapper started, HOME=$HOME, PID=$$" >> "$LOG"
"$HOME/homey-pulse/HappinessPulse.app/Contents/MacOS/HappinessPulse" >> "$LOG" 2>&1
echo "$(date): App exited with code $?" >> "$LOG"
RUNEOF
chmod +x "$BASE_DIR/run.sh"

# Write LaunchAgent plist using wrapper script
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
    <key>StartInterval</key>
    <integer>300</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityBackgroundIO</key>
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
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
EOF

launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_PATH"

curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"install-v2\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\"}" \
  "$WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Homey Happiness Pulse installed successfully!${NC}"
echo "The pulse will appear once daily during work hours. No action needed."
