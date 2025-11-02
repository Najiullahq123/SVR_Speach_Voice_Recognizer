
import os
import subprocess
import time
import threading
import RPi.GPIO as GPIO
from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import credentials, firestore

# === GPIO Setup ===
YELLOW_LED = 5   # Boot indicator
WHITE_LED = 17   # Wi-Fi indicator

GPIO.setmode(GPIO.BCM)
GPIO.setup(YELLOW_LED, GPIO.OUT)
GPIO.setup(WHITE_LED, GPIO.OUT)

GPIO.output(YELLOW_LED, GPIO.HIGH)   # System booted
GPIO.output(WHITE_LED, GPIO.LOW)     # Wi-Fi off initially

# === Device ID ===
LOCAL_DEVICE_ID = "6cce8e7f6f7f13f3d12e01b48cda71b6"

# === Firebase Setup ===
cred = credentials.Certificate("/home/pi/svr-app-96763-firebase-adminsdk-fbsvc-590156fc6d.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

# === Flask App ===
app = Flask(__name__)

def is_wifi_connected():
  try:
        result = subprocess.run(["iwgetid", "-r"], stdout=subprocess.PIPE)
        ssid = result.stdout.decode().strip()
        if ssid:
            return True
        else:
            return False
  except:
        return False

def start_hotspot():
    """Start a hotspot if Wi-Fi not connected"""
    print("[INFO] Starting hotspot for provisioning...")
    subprocess.call(["sudo", "systemctl", "start", "hostapd"])
    subprocess.call(["sudo", "systemctl", "start", "dnsmasq"])

def stop_hotspot():
    """Stop the hotspot after Wi-Fi configured"""
    subprocess.call("sudo systemctl stop hostapd", shell=True)
    subprocess.call("sudo systemctl stop dnsmasq", shell=True)
    
if is_wifi_connected():
    GPIO.output(WHITE_LED, GPIO.HIGH)
else:
    GPIO.output(WHITE_LED, GPIO.LOW)
    start_hotspot()

@app.route('/provision', methods=['POST'])
def provision():
    data = request.json
    ssid = data.get("ssid")
    password = data.get("password")
    uid = data.get("uid")
    deviceId = data.get("deviceId")

    if not ssid or not password or not uid or not deviceId:
        return jsonify({"status": "error", "message": "Missing fields"}), 400

    if deviceId != LOCAL_DEVICE_ID:
        return jsonify({"status": "error", "message": "Device ID mismatch"}), 403

    # Write Wi-Fi config
    wpa_config = f"""
country=US
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={{
    ssid="{ssid}"
    psk="{password}"
}}
"""
    try:
        with open("/etc/wpa_supplicant/wpa_supplicant.conf", "w") as f:
            f.write(wpa_config)
        subprocess.call("wpa_cli -i wlan0 reconfigure", shell=True)
        time.sleep(10)
        stop_hotspot()
    except Exception as e:
        return jsonify({"status": "fail", "message": f"Failed to configure WiFi: {e}"}), 500

    if is_wifi_connected():
        GPIO.output(WHITE_LED, GPIO.HIGH)  # Wi-Fi connected
        doc_ref = db.collection("devices").document(deviceId)
        doc_ref.set({
            "assignedTo": uid,
            "status": "online",
            "lastSeen": firestore.SERVER_TIMESTAMP
        }, merge=True)
        return jsonify({"status": "success", "message": "Wi-Fi connected and device registered"})
    else:
        GPIO.output(WHITE_LED, GPIO.LOW)
        return jsonify({"status": "fail", "message": "Wi-Fi connection failed"}), 500

def monitor_connection():
    """Background task: keep Firestore updated with online/offline"""
    while True:
        if is_wifi_connected():
            GPIO.output(WHITE_LED, GPIO.HIGH)
            db.collection("devices").document(LOCAL_DEVICE_ID).update({
                "status": "online",
                "lastSeen": firestore.SERVER_TIMESTAMP
            })
        else:
            GPIO.output(WHITE_LED, GPIO.LOW)
            db.collection("devices").document(LOCAL_DEVICE_ID).update({
                "status": "offline",
                "lastSeen": firestore.SERVER_TIMESTAMP
            })
            start_hotspot()  # start hotspot when disconnected
        time.sleep(30)

if __name__ == "__main__":
    # If Wi-Fi is not connected, start hotspot
    if not is_wifi_connected():
        start_hotspot()

    # Start background monitor thread
    t = threading.Thread(target=monitor_connection, daemon=True)
    t.start()

    # Start Flask server
    app.run(host="0.0.0.0", port=5000)
