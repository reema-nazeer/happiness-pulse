#!/bin/bash

clear
echo ""
echo "  ⚡ Homey Happiness Pulse - Installing..."
echo "  ==========================================="
echo ""

PULSE_DIR="$HOME/homey-pulse"
AGENT="$HOME/Library/LaunchAgents/uk.co.homey.pulse.plist"
BASE="https://raw.githubusercontent.com/reema-nazeer/happiness-pulse/main"

fail() {
  echo ""
  echo "  ❌ Something went wrong at: $1"
  echo ""
  echo "  Take a screenshot of this window and send it to"
  echo "  the CI team. They'll help you fix it."
  echo ""
  read -p "  Press Enter to close..."
  exit 1
}

# Step 1: Find Python 3
echo "  [1/4] Checking Python..."

PYTHON=""

if /opt/homebrew/bin/python3 --version &> /dev/null 2>&1; then
  PYTHON="/opt/homebrew/bin/python3"
elif /usr/bin/python3 --version &> /dev/null 2>&1; then
  PYTHON="/usr/bin/python3"
elif python3 --version &> /dev/null 2>&1; then
  PYTHON="python3"
fi

if [ -z "$PYTHON" ]; then
  echo "         Python not found. Installing Xcode tools..."
  echo "         A popup may appear - click Install and wait."
  xcode-select --install 2>/dev/null
  echo ""
  echo "         Waiting for install to finish..."
  until xcode-select -p &> /dev/null; do
    sleep 5
  done
  if /usr/bin/python3 --version &> /dev/null 2>&1; then
    PYTHON="/usr/bin/python3"
  else
    fail "Python not available after Xcode tools install"
  fi
fi

echo "         Found: $($PYTHON --version) ✓"

# Step 2: Set up environment
echo ""
echo "  [2/4] Setting up Happiness Pulse..."
mkdir -p "$PULSE_DIR" || fail "Create folder"

if [ ! -d "$PULSE_DIR/venv" ]; then
  $PYTHON -m venv "$PULSE_DIR/venv" || fail "Create Python environment"
fi

echo "         Upgrading package manager..."
"$PULSE_DIR/venv/bin/python3" -m pip install --upgrade pip --quiet || fail "Upgrade pip"

echo "         Installing app components (this may take a few minutes)..."
"$PULSE_DIR/venv/bin/pip" install --quiet pywebview || fail "Install pywebview"
echo "         App environment ready ✓"

# Step 3: Download files
echo ""
echo "  [3/4] Downloading pulse files..."
curl -sL "$BASE/pulse-form.html" -o "$PULSE_DIR/pulse-form.html" || fail "Download pulse-form.html"
curl -sL "$BASE/launch.py" -o "$PULSE_DIR/launch.py" || fail "Download launch.py"
curl -sL "$BASE/pulse.sh" -o "$PULSE_DIR/pulse.sh" || fail "Download pulse.sh"
chmod +x "$PULSE_DIR/pulse.sh"

if [ ! -s "$PULSE_DIR/pulse-form.html" ]; then
  fail "pulse-form.html is empty - check internet connection"
fi
if [ ! -s "$PULSE_DIR/launch.py" ]; then
  fail "launch.py is empty - check internet connection"
fi

echo "         Files downloaded ✓"

# Step 4: LaunchAgent
echo ""
echo "  [4/4] Setting up daily trigger..."

mkdir -p "$HOME/Library/LaunchAgents"

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
launchctl load "$AGENT" || fail "Load LaunchAgent"
echo "         Daily trigger active ✓"

rm -f /tmp/homey-pulse-*

echo ""
echo "  ==========================================="
echo ""
echo "  ⚡ All done! Homey Happiness Pulse is installed."
echo ""
echo "  What happens now:"
echo "  - A popup will appear each weekday morning (7AM-8PM)"
echo "    when you open your laptop"
echo "  - It takes 5 seconds to complete"
echo "  - It's completely anonymous"
echo "  - If you close it, it comes back in 5 minutes"
echo ""
echo "  You can close this window now."
echo ""
echo "  ==========================================="
echo ""

read -p "  Press Enter to close..."
