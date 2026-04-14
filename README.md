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
- Test flags:
  - `HappinessPulse --test` bypasses weekday/time/flag checks.
  - `HappinessPulse --test-first-launch` clears `.registered` and opens first-launch flow.
