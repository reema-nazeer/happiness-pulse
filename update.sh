#!/bin/bash
BASE="https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main"
WH="https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec"
D="$HOME/homey-pulse"
curl -sL "$BASE/pulse-form.html" -o "$D/pulse-form.html"
curl -sL "$BASE/pulse.sh" -o "$D/pulse.sh"
curl -sL "$BASE/launch.py" -o "$D/launch.py"
chmod +x "$D/pulse.sh"
mkdir -p "$D/flags"
rm -f /tmp/homey-pulse-*
curl -sL -X POST "$WH" -H "Content-Type: text/plain" -d "{\"type\":\"install\",\"username\":\"$(whoami)\",\"source\":\"update\"}" > /dev/null 2>&1
echo "✅ Updated!"
