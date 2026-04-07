import webview
import os
import threading
import time
from datetime import date

user = os.getenv("USER")
path = "file:///Users/" + user + "/homey-pulse/pulse-form.html"
flag_dir = os.path.expanduser("~/homey-pulse/flags")
flag_file = os.path.join(flag_dir, date.today().isoformat())

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
                # Write flag immediately on submission
                os.makedirs(flag_dir, exist_ok=True)
                open(flag_file, "w").close()
                time.sleep(3)
                window.destroy()
                break
        except:
            break
        time.sleep(1)

threading.Thread(target=auto_close, daemon=True).start()
webview.start()
