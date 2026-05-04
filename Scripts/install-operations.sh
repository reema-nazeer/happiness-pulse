#!/bin/bash
# Install Homey Happiness Pulse for the Operations team.
# This is the v3 build: department is baked in, so users never see a picker.
#
# IMPORTANT — before distributing this script, the CI team must replace
# __WEBHOOK_URL__ below with the real Apps Script web-app URL pointing at
# the new (v3) Google Sheet. Until that's done, the script will refuse to run.

export PULSE_DEPARTMENT="Operations"
export PULSE_WEBHOOK_URL="__WEBHOOK_URL__"

DIR="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$DIR/install-department.sh"
