#!/bin/bash
set -euo pipefail

WEBHOOK_URL="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
BASE_DIR="$HOME/homey-pulse"
LAUNCH_AGENT_ID="uk.co.homey.pulse"
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/${LAUNCH_AGENT_ID}.plist"

launchctl unload "$LAUNCH_AGENT_PATH" 2>/dev/null || true
rm -f "$LAUNCH_AGENT_PATH"
pkill -f HappinessPulse || true
rm -rf "$BASE_DIR"

curl -sL -X POST \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"uninstall-v2\",\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"arch\":\"$(uname -m)\",\"os\":\"$(sw_vers -productVersion)\"}" \
  "$WEBHOOK_URL" \
  > /dev/null 2>&1 || true

echo "Homey Happiness Pulse has been removed."
