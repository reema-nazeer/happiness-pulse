#!/bin/bash

TODAY=$(date +%Y-%m-%d)
FLAG_DIR="$HOME/homey-pulse/flags"
FLAG_FILE="$FLAG_DIR/$TODAY"

mkdir -p "$FLAG_DIR"

# Already submitted today? Exit.
if [ -f "$FLAG_FILE" ]; then
  exit 0
fi

# Weekend? Exit. (6=Saturday, 7=Sunday)
DAY_OF_WEEK=$(date +%u)
if [ "$DAY_OF_WEEK" -gt 5 ]; then
  exit 0
fi

# Outside 7AM-8PM? Exit.
HOUR=$(date +%H)
if [ "$HOUR" -lt 7 ] || [ "$HOUR" -ge 20 ]; then
  exit 0
fi

# Launch the popup
~/homey-pulse/venv/bin/python3 ~/homey-pulse/launch.py

# Write flag regardless of exit code
touch "$FLAG_FILE"

# Clean up old flags (older than 7 days)
find "$FLAG_DIR" -name "????-??-??" -mtime +7 -delete 2>/dev/null
