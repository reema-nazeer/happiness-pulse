"""Homey Happiness Pulse — desktop launcher.

Renders pulse-form.html in a small frameless pywebview window, then auto-closes
3 seconds after the user submits. Exposes a tiny JS API the form uses to save /
load / clear the chosen department so the right pill is pre-selected on next
run."""

import json
import os
import tempfile
import threading
import time
from pathlib import Path
from urllib.parse import urlparse

import webview

BASE_DIR = Path(__file__).resolve().parent
TEMPLATE_PATH = BASE_DIR / "pulse-form.html"

# Per-user state lives outside the install dir so update.sh doesn't wipe it.
PULSE_HOME = Path.home() / "homey-pulse"
DEPARTMENT_FILE = PULSE_HOME / "department"

webhook_url = os.getenv("HOMEY_PULSE_WEBHOOK_URL", "").strip()

# Restrict webhook to HTTPS to avoid accidental insecure transport.
if webhook_url:
    parsed = urlparse(webhook_url)
    if parsed.scheme.lower() != "https" or not parsed.netloc:
        raise ValueError("HOMEY_PULSE_WEBHOOK_URL must be a valid https URL")


VALID_DEPARTMENTS = {"Operations", "Revenue", "Service", "Technology"}


def _read_saved_department() -> str:
    """Return the saved department, or '' if absent / unreadable / unknown."""
    try:
        if not DEPARTMENT_FILE.exists():
            return ""
        value = DEPARTMENT_FILE.read_text(encoding="utf-8").strip()
        return value if value in VALID_DEPARTMENTS else ""
    except OSError:
        return ""


class PulseApi:
    """Methods exposed to JS as `window.pywebview.api.<method>(...)`."""

    def save_department(self, name):
        if not isinstance(name, str) or name not in VALID_DEPARTMENTS:
            return False
        try:
            PULSE_HOME.mkdir(parents=True, exist_ok=True)
            DEPARTMENT_FILE.write_text(name, encoding="utf-8")
            return True
        except OSError:
            return False

    def clear_department(self):
        try:
            if DEPARTMENT_FILE.exists():
                DEPARTMENT_FILE.unlink()
        except OSError:
            pass
        return True


template = TEMPLATE_PATH.read_text(encoding="utf-8")
safe_webhook_literal = json.dumps(webhook_url)
rendered = template.replace('"__WEBHOOK_URL__"', safe_webhook_literal)

tmp_file = tempfile.NamedTemporaryFile(
    mode="w", suffix=".html", prefix="homey-pulse-", delete=False, encoding="utf-8"
)
tmp_file.write(rendered)
tmp_file.close()
path = Path(tmp_file.name).resolve().as_uri()

api = PulseApi()
window = webview.create_window(
    "Homey Pulse",
    path,
    js_api=api,
    width=480,
    height=720,
    resizable=False,
    on_top=True,
    frameless=True,
    easy_drag=False,
)


def _on_shown() -> None:
    """Once the window is visible:
       1. Pre-select the saved department (if any) so the right pill is on.
       2. Focus the textarea so users can type immediately — fixes the
          intermittent 'cursor not in textarea' typing bug from the launcher
          side.
    """
    saved = _read_saved_department()
    if saved:
        window.evaluate_js(
            "if (window.homeyPulseSetDepartment) window.homeyPulseSetDepartment("
            + json.dumps(saved)
            + ");"
        )
    # 100ms delay gives the DOM and pywebview's IPC channel time to settle
    # before we try to focus.
    window.evaluate_js(
        "setTimeout(function(){ var t=document.getElementById('fb'); if(t){t.focus();} }, 100);"
    )


window.events.shown += _on_shown


def auto_close():
    time.sleep(5)
    while True:
        try:
            r = window.evaluate_js("document.getElementById('tv').style.display")
            if r == "flex":
                time.sleep(3)
                window.destroy()
                break
        except Exception:
            break
        time.sleep(1)


threading.Thread(target=auto_close, daemon=True).start()
try:
    webview.start()
finally:
    try:
        os.unlink(tmp_file.name)
    except OSError:
        pass
