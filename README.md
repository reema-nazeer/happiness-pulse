# Homey Happiness Pulse

A daily anonymous happiness check-in for the Homey team. A small popup shows
on each MacBook in the morning, the score (with optional comment) is sent to
a Google Sheet, and a daily summary lands in the leadership inbox at
4:30PM BST.

## What's in the repo

| Path | Purpose |
|---|---|
| `pulse-form.html` | The popup itself — score slider, department pills, feedback box, success animation. |
| `launch.py` | pywebview wrapper that opens the form in a 480×720 frameless window. Saves the chosen department locally so it pre-selects next time. |
| `pulse.sh` | Wrapper run by LaunchAgent every 5 min: skips if today's flag exists, weekend, or out-of-hours; otherwise launches `launch.py`. |
| `install.sh` | One-shot bootstrap: finds python3, creates a venv, installs pywebview, downloads the latest pulse files, registers the LaunchAgent. No Homebrew, no admin password required. |
| `update.sh` | Pulls the latest files in place. Preserves saved department + flags. Runs `py_compile` on the new launch.py and reports any syntax error. |
| `assets/` | Homey brand logos (SVG + PNG, purple + white variants). |
| `apps-script/` | Google Apps Script project files — webhook handler, daily/weekly emails, admin dashboard. Copy/paste into the Apps Script editor when redeploying. |

## Architecture

```
 MacBook (every 5 min)            Google Apps Script              Inbox
 ────────────────────             ──────────────────              ─────
 pulse.sh ──────► launch.py       doPost (Code.gs)
                  │  popup        │
                  │               ▼
                  └──HTTPS───►   Responses sheet
                                  │
                                  ├── dailySummary  (4:30 PM BST) ──► leadership
                                  └── weeklySummary (Fri 5 PM BST) ──► leadership
                                  │
                                  └── admin web app (Admin.gs/admin.html)
                                                 password-gated dashboard
```

## Anonymity rules

- No usernames or device identifiers are stored against scores. The
  `Registrations` and `Installs` sheets log usernames separately for
  install tracking only — they're not joined to responses.
- The daily/weekly emails apply a 2-response minimum per department before
  showing that department in the breakdown table. Below-threshold responses
  still feed the overall total and average so the data isn't lost — just
  not attributed to a small group.
- Anonymous feedback comments are listed with the score but never with a
  department label, even on the admin dashboard. Small teams could be
  triangulated otherwise.

## Live URLs (do not change)

- **Webhook**: `https://script.google.com/macros/s/AKfycbxE6GyN8jsybwc3_1hC2irErQeKO9Yu-j8hgglVXaHuPK8vsdDJwSMJbC2J7eOzsy7g/exec`
- **Sheet**: `https://docs.google.com/spreadsheets/d/1byV_pv5NMI8fMY4v0m74qdNDtdybXvX-KXA2e_0ra0w/`
- **GitHub**: `https://github.com/reema-nazeer/happiness-pulse`

## Brand colours

- Strike Yellow `#DBFF00`
- Storm Purple `#7C57FC`
- Midnight Black `#040406`
- Flash White `#FFFFFF`

## Apps Script deployment notes

The `apps-script/` folder contains the source for the webhook + emails +
admin dashboard. They share helpers (`HOMEY_SPREADSHEET_ID`,
`HOMEY_LONDON_TZ`, `DEPARTMENTS`, `escapeHtml_`, etc.) so they must all be
deployed together as **one Apps Script project** with **two web app
deployments**:

1. **Webhook deployment** — exposes `doPost` from `Code.gs`. URL is the
   one already baked into `install.sh` / `update.sh` / `pulse-form.html`.
   Don't redeploy this in a way that changes the URL.
2. **Admin deployment** — exposes `doGet` from `Admin.gs`, which serves
   `admin.html`. Different deployment so the URLs don't collide.

After first-time deployment, set Script Properties:

- `WEBHOOK_SHARED_SECRET` (optional) — if set, the webhook requires the
  client to send a matching `secret` field. The popup currently does not
  send one, so leaving this unset is fine.
- `ADMIN_PASSWORD` — required for the admin dashboard. Without it, every
  login attempt is rejected.

Then run `installWeeklyTrigger()` once in the Apps Script editor to
schedule the Friday-5PM-BST weekly email. The daily-4:30PM trigger is
unchanged from v1.
