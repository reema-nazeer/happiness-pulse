#!/bin/bash
set -euo pipefail

WEBHOOK_URL="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
BASE_DIR="$HOME/homey-pulse"
APP_NAME="HappinessPulse.app"
APP_PATH="$BASE_DIR/$APP_NAME"
FLAGS_DIR="$BASE_DIR/flags"
LAUNCH_AGENT_ID="uk.co.homey.pulse"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/${LAUNCH_AGENT_ID}.plist"
PLIST_TEMPLATE="./Scripts/uk.co.homey.pulse.plist"

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
TMP_ZIP="$(mktemp "/tmp/homey-pulse-${ARCH}.XXXXXX.zip")"
TMP_UNZIP_DIR="$(mktemp -d "/tmp/homey-pulse-unzip.XXXXXX")"
cleanup() {
    rm -f "$TMP_ZIP" 2>/dev/null || true
    rm -rf "$TMP_UNZIP_DIR" 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$BASE_DIR" "$FLAGS_DIR" "$LAUNCH_AGENTS_DIR"
pkill -f HappinessPulse || true

if ! curl -sL --connect-timeout 4 --max-time 8 "$RELEASE_URL" -o "$TMP_ZIP"; then
    echo "Failed to download Homey Happiness Pulse update from GitHub Releases."
    echo "Check your connection or corporate firewall and try again."
    exit 1
fi

if ! unzip -q "$TMP_ZIP" -d "$TMP_UNZIP_DIR"; then
    echo "Downloaded update package is invalid or corrupted."
    exit 1
fi

if [ ! -d "$TMP_UNZIP_DIR/$APP_NAME" ]; then
    echo "Release archive did not contain $APP_NAME."
    exit 1
fi

rm -rf "$APP_PATH"
mv "$TMP_UNZIP_DIR/$APP_NAME" "$APP_PATH"
xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true

write_launch_agent_plist() {
    local source_template="$1"
    if [ -f "$source_template" ]; then
        sed "s|\$HOME|$HOME|g" "$source_template" > "$LAUNCH_AGENT_PATH"
        return 0
    fi

    cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>uk.co.homey.pulse</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/homey-pulse/HappinessPulse.app/Contents/MacOS/HappinessPulse</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StartInterval</key>
    <integer>300</integer>
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
    <string>/dev/null</string>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
</dict>
</plist>
EOF
}

write_launch_agent_plist "$PLIST_TEMPLATE"

launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_PATH"

curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"update-v2\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\"}" \
  "$WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Homey Happiness Pulse updated successfully!${NC}"
echo "The pulse will appear once daily during work hours. No action needed."
