#!/bin/bash
set -euo pipefail

WEBHOOK_URL="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
BASE_DIR="$HOME/homey-pulse"
APP_NAME="HappinessPulse.app"
APP_PATH="$BASE_DIR/$APP_NAME"
FLAGS_DIR="$BASE_DIR/flags"
PENDING_DIR="$BASE_DIR/pending"
LAUNCH_AGENT_ID="uk.co.homey.pulse"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/${LAUNCH_AGENT_ID}.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_TEMPLATE="$SCRIPT_DIR/uk.co.homey.pulse.plist"

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

mkdir -p "$BASE_DIR" "$FLAGS_DIR" "$PENDING_DIR" "$LAUNCH_AGENTS_DIR"

if ! curl -sL --connect-timeout 4 --max-time 8 "$RELEASE_URL" -o "$TMP_ZIP"; then
    echo "Failed to download Homey Happiness Pulse from GitHub Releases."
    echo "Check your connection or corporate firewall and try again."
    exit 1
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

sed "s|\$HOME|$HOME|g" "$PLIST_TEMPLATE" > "$LAUNCH_AGENT_PATH"

launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT_PATH"

curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"install-v2\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\"}" \
  "$WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo -e "${GREEN}✓ Homey Happiness Pulse installed successfully!${NC}"
echo "The pulse will appear once daily during work hours. No action needed."
