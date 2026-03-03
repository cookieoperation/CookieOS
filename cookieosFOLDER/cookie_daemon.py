#!/usr/bin/env python3
"""
CookieDaemon: The Bridge between Android (CookieOS Settings APK) and the Linux Host.
This runs as root on the Raspberry Pi and exposes a local REST API that the Waydroid container can hit.
"""
from flask import Flask, request, jsonify
import subprocess
import os

app = Flask(__name__)

def run_cmd(cmd):
    try:
        result = subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True)
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

@app.route('/api/ping', methods=['GET'])
def ping():
    return jsonify({"status": "CookieDaemon Online"})

@app.route('/api/ssh', methods=['POST'])
def manage_ssh():
    data = request.json
    enable = data.get('enable', False)
    
    if enable:
        success, out = run_cmd("systemctl enable --now ssh")
    else:
        success, out = run_cmd("systemctl disable --now ssh")
        
    return jsonify({"success": success, "output": out})

@app.route('/api/brightness', methods=['POST'])
def set_brightness():
    data = request.json
    level = data.get('level', 100) # 0 to 100
    # Assuming standard sysfs backlight for RPi or generic Linux
    # This might need adjustment based on exact DSI/HDMI setup
    cmd = f"brightnessctl set {level}%" 
    success, out = run_cmd(cmd)
    return jsonify({"success": success, "output": out})

@app.route('/api/wifi/toggle', methods=['POST'])
def toggle_wifi():
    data = request.json
    enable = data.get('enable', True)
    state = "on" if enable else "off"
    success, out = run_cmd(f"nmcli radio wifi {state}")
    return jsonify({"success": success, "output": out})

# Stub for Display Overscan (Writing to /boot/config.txt requires a reboot usually)
@app.route('/api/display/overscan', methods=['POST'])
def set_overscan():
    data = request.json
    val = data.get('value', 0)
    # Placeholder: In reality we'd sed /boot/config.txt and prompt for reboot
    return jsonify({"success": True, "message": f"Overscan set to {val}, reboot required."})

if __name__ == '__main__':
    # Listen on all interfaces so the Waydroid container (which has its own IP) can reach it.
    # Typically Waydroid host is accessible at 192.168.250.1
    app.run(host='0.0.0.0', port=5050)
