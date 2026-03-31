#!/bin/bash

# ============================================
#   Homey Happiness Pulse - Installer
#   Just double-click this file to install!
# ============================================

clear
echo ""
echo "  ⚡ Homey Happiness Pulse - Installing..."
echo "  ==========================================="
echo ""
echo "  This will set up a quick daily happiness check"
echo "  that pops up when you open your laptop each morning."
echo ""
echo "  It takes about 2-3 minutes. You may need to enter"
echo "  your Mac password during the process."
echo ""
echo "  ==========================================="
echo ""

PULSE_DIR="$HOME/homey-pulse"
AGENT="$HOME/Library/LaunchAgents/uk.co.homey.pulse.plist"
BASE="https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main"

# Step 1: Homebrew
echo "  [1/5] Checking Homebrew..."
if command -v /opt/homebrew/bin/brew &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Homebrew (this takes a minute)..."
  echo "         You may need to enter your Mac password below:"
  echo ""
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo ""
  echo "         Homebrew installed ✓"
fi

# Step 2: Python
echo ""
echo "  [2/5] Checking Python..."
if /opt/homebrew/bin/python3 --version &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Python..."
  /opt/homebrew/bin/brew install python3
  echo "         Python installed ✓"
fi

# Step 3: Pulse app
echo ""
echo "  [3/5] Setting up Happiness Pulse..."
mkdir -p "$PULSE_DIR"
if [ ! -d "$PULSE_DIR/venv" ]; then
  /opt/homebrew/bin/python3 -m venv "$PULSE_DIR/venv"
fi
"$PULSE_DIR/venv/bin/pip" install --quiet pywebview
echo "         App environment ready ✓"

# Step 4: Download files
echo ""
echo "  [4/5] Downloading pulse files..."
curl -sL "$BASE/pulse-form.html" -o "$PULSE_DIR/pulse-form.html"
curl -sL "$BASE/launch.py" -o "$PULSE_DIR/launch.py"
curl -sL "$BASE/pulse.sh" -o "$PULSE_DIR/pulse.sh"
chmod +x "$PULSE_DIR/pulse.sh"
echo "         Files downloaded ✓"

# Step 5: LaunchAgent
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

# Done
echo ""
echo "  ==========================================="
echo ""
echo "  ⚡ All done! Homey Happiness Pulse is installed."
echo ""
echo "  A popup will appear each weekday morning when"
echo "  you open your laptop. It takes 5 seconds to complete"
echo "  and is completely anonymous."
echo ""
echo "  You can close this window now."
echo ""
echo "  ==========================================="
echo ""

read -p "  Press Enter to close..."
