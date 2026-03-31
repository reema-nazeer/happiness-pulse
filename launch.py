import webview
import os
import threading
import time

user = os.getenv("USER")
path = "file:///Users/" + user + "/homey-pulse/pulse-form.html"

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
webview.start()
