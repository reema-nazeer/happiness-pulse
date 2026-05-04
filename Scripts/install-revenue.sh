#!/bin/bash
# Install Homey Happiness Pulse for the Revenue team.
# v3: department baked in.
#
# IMPORTANT — replace __WEBHOOK_URL__ with the v3 Apps Script web-app URL
# before distributing.

export PULSE_DEPARTMENT="Revenue"
export PULSE_WEBHOOK_URL="__WEBHOOK_URL__"

DIR="$(cd "$(dirname "$0")" && pwd)"
exec /bin/bash "$DIR/install-department.sh"
