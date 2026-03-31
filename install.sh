#!/bin/bash

clear
echo ""
echo "  ⚡ Homey Happiness Pulse - Installing..."
echo "  ==========================================="
echo ""

PULSE_DIR="$HOME/homey-pulse"
AGENT="$HOME/Library/LaunchAgents/uk.co.homey.pulse.plist"
BASE="https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main"

echo "  [1/5] Checking Homebrew..."
if command -v /opt/homebrew/bin/brew &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Homebrew (you may need your Mac password)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo "         Homebrew installed ✓"
fi

echo ""
echo "  [2/5] Checking Python..."
if /opt/homebrew/bin/python3 --version &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Python..."
  /opt/homebrew/bin/brew install python3
  echo "         Python installed ✓"
fi

echo ""
echo "  [3/5] Setting up Happiness Pulse..."
mkdir -p "$PULSE_DIR"
if [ ! -d "$PULSE_DIR/venv" ]; then
  /opt/homebrew/bin/python3 -m venv "$PULSE_DIR/venv"
fi
"$PULSE_DIR/venv/bin/pip" install --quiet pywebview
echo "         App environment ready ✓"

echo ""
echo "  [4/5] Downloading pulse files..."
curl -sL "$BASE/pulse-form.html" -o "$PULSE_DIR/pulse-form.html"
curl -sL "$BASE/launch.py" -o "$PULSE_DIR/launch.py"
curl -sL "$BASE/pulse.sh" -o "$PULSE_DIR/pulse.sh"
chmod +x "$PULSE_DIR/pulse.sh"
echo "         Files downloaded ✓"

echo ""
echo "  [5/5] Setting up daily trigger..."
cat > "$AGENT" << PEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>uk.co.homey.pulse</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${PULSE_DIR}/pulse.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PEOF

launchctl unload "$AGENT" 2>/dev/null
launchctl load "$AGENT"
echo "         Daily trigger active ✓"

echo ""
echo "  ==========================================="
echo "  ⚡ All done! Homey Happiness Pulse is installed."
echo ""
echo "  A popup will appear each weekday morning when"
echo "  you open your laptop. Takes 5 seconds and is"
echo "  completely anonymous."
echo "  ==========================================="
echo ""
