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
webhook_url = os.getenv("HOMEY_PULSE_WEBHOOK_URL", "").strip()

# Restrict webhook to HTTPS to avoid accidental insecure transport.
if webhook_url:
    parsed = urlparse(webhook_url)
    if parsed.scheme.lower() != "https" or not parsed.netloc:
        raise ValueError("HOMEY_PULSE_WEBHOOK_URL must be a valid https URL")

template = TEMPLATE_PATH.read_text(encoding="utf-8")
safe_webhook_literal = json.dumps(webhook_url)
rendered = template.replace('"__WEBHOOK_URL__"', safe_webhook_literal)

tmp_file = tempfile.NamedTemporaryFile(
    mode="w", suffix=".html", prefix="homey-pulse-", delete=False, encoding="utf-8"
)
tmp_file.write(rendered)
tmp_file.close()
path = Path(tmp_file.name).resolve().as_uri()

window = webview.create_window(
    "Homey Pulse",
    path,
    width=480,
    height=700,
    resizable=False,
    on_top=True,
    frameless=True,
    easy_drag=False
)

def auto_close():
    time.sleep(5)
    while True:
        try:
            r = window.evaluate_js("document.getElementById('tv').style.display")
            if r == "flex":
                time.sleep(3)
                window.destroy()
                break
        except:
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
