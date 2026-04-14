# Homey Happiness Pulse v2

TODO: Add full product overview and architecture notes.

## Stack
- Native macOS app (`Swift` + `SwiftUI`)
- Single compiled `.app` bundle
- Universal binary (`arm64` + `x86_64`) via GitHub Releases

## Brand
- Strike Yellow: `#DBFF00`
- Storm Purple: `#7C57FC`
- Midnight Black: `#040406`
- Flash White: `#FFFFFF`
- Company: `Homey` ([homey.co.uk](https://homey.co.uk))

## Webhook
- `https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec`

## Project Status
TODO: Fill in implementation details for app logic, launch flow, install/update scripts, and CI release pipeline.

## Runtime Hardening Notes
- Overlay window level uses `.floating` by default to avoid potential Screen Recording permission side effects seen with `.screenSaver` on some macOS setups.
- Installer removes quarantine attributes to avoid app translocation (`xattr -rd com.apple.quarantine`).
- Install/update scripts verify release ZIP integrity using SHA-256 `.sha256` sidecar files from GitHub Releases.
- Local app state files are written with restrictive permissions (`600` files, `700` directories) for lock/flags/pending/log paths.
- Apps Script backend supports optional shared-secret validation via Script Properties:
  - Set `WEBHOOK_SHARED_SECRET` in Apps Script project settings.
  - macOS app can send secret with `HOMEY_PULSE_WEBHOOK_SECRET` env var.
- Test flags:
  - `HappinessPulse --test` bypasses weekday/time/flag checks.
