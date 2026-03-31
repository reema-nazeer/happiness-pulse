#!/bin/bash

TODAY=$(date +%Y-%m-%d)
FLAG_FILE="/tmp/homey-pulse-${TODAY}"

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

# Only write flag if popup exited cleanly (meaning they submitted)
if [ $? -eq 0 ]; then
  touch "$FLAG_FILE"
fi
