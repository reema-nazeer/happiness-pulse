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

# Step 1: Xcode Command Line Tools
echo "  [1/6] Checking developer tools..."
if ! xcode-select -p &> /dev/null; then
  echo "         Installing Xcode Command Line Tools..."
  echo "         A popup may appear - click Install and wait."
  echo ""
  xcode-select --install 2>/dev/null
  echo "         Waiting for install to complete..."
  until xcode-select -p &> /dev/null; do
    sleep 5
  done
  echo "         Developer tools installed ✓"
else
  echo "         Already installed ✓"
fi

# Step 2: Homebrew
echo ""
echo "  [2/6] Checking Homebrew..."
if command -v /opt/homebrew/bin/brew &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Homebrew..."
  echo ""
  echo "  ⚠️  You may need to enter your Mac password below."
  echo "     (Characters won't show as you type - that's normal)"
  echo ""
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || fail "Homebrew install"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
  eval "$(/opt/homebrew/bin/brew shellenv)"
  echo ""
  echo "         Homebrew installed ✓"
fi

# Make sure brew is in PATH for this session
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null

# Step 3: Python
echo ""
echo "  [3/6] Checking Python..."
if /opt/homebrew/bin/python3 --version &> /dev/null; then
  echo "         Already installed ✓"
else
  echo "         Installing Python (this takes a minute)..."
  /opt/homebrew/bin/brew install python3 || fail "Python install"
  echo "         Python installed ✓"
fi

# Step 4: Pulse app environment
echo ""
echo "  [4/6] Setting up Happiness Pulse..."
mkdir -p "$PULSE_DIR" || fail "Create folder"

if [ ! -d "$PULSE_DIR/venv" ]; then
  /opt/homebrew/bin/python3 -m venv "$PULSE_DIR/venv" || fail "Create Python environment"
fi

"$PULSE_DIR/venv/bin/pip" install --quiet pywebview || fail "Install pywebview"
echo "         App environment ready ✓"

# Step 5: Download files
echo ""
echo "  [5/6] Downloading pulse files..."
curl -sL "$BASE/pulse-form.html" -o "$PULSE_DIR/pulse-form.html" || fail "Download pulse-form.html"
curl -sL "$BASE/launch.py" -o "$PULSE_DIR/launch.py" || fail "Download launch.py"
curl -sL "$BASE/pulse.sh" -o "$PULSE_DIR/pulse.sh" || fail "Download pulse.sh"
chmod +x "$PULSE_DIR/pulse.sh"

# Verify files downloaded properly
if [ ! -s "$PULSE_DIR/pulse-form.html" ]; then
  fail "pulse-form.html is empty - check internet connection"
fi
if [ ! -s "$PULSE_DIR/launch.py" ]; then
  fail "launch.py is empty - check internet connection"
fi

echo "         Files downloaded ✓"

# Step 6: LaunchAgent
echo ""
echo "  [6/6] Setting up daily trigger..."

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

# Clear any existing flag so they can test
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
