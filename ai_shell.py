import sys
import subprocess
import requests
import json

# CookieOS Aluminum AI Shell v1.0
# Translates natural language to Bash using Ollama

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "llama3" # Or user preferred model

SYSTEM_PROMPT = """
You are the CookieOS Native Fusion AI Shell. Your job is to translate natural language into native Android (AOSP) or Linux (Debian) commands.
- Output ONLY the command. No explanations.
- FOR ANDROID: Use 'am start -n <package/activity>', 'pm install <apk>', or 'input tap <x> <y>'.
- FOR LINUX: Use standard Bash (ls, cd, apt, systemctl).
- NATIVE INTEGRATION: There is no Waydroid. Use 'am' and 'pm' directly.

Examples:
User: "Open the Camera" -> am start -n com.android.camera2/com.android.camera.CameraActivity
User: "Install spotify" -> pm install /opt/cookieos/apps/spotify.apk
User: "List files" -> ls -la
User: "Reboot" -> reboot
"""

def translate_to_bash(prompt):
    try:
        data = {
            "model": MODEL,
            "prompt": f"{SYSTEM_PROMPT}\nUser: {prompt}\nOutput:",
            "stream": False
        }
        response = requests.post(OLLAMA_URL, json=data)
        response.raise_for_status()
        return response.json().get("response", "").strip()
    except Exception as e:
        return f"echo 'Error: Could not connect to Ollama ({str(e)})'"

def main():
    if len(sys.argv) < 2:
        print("Usage: ai-shell <natural language command>")
        sys.exit(1)

    user_prompt = " ".join(sys.argv[1:])
    bash_cmd = translate_to_bash(user_prompt)
    
    # In a real OS, we might want a confirmation step. 
    # For now, we print it for the UI to consume.
    print(bash_cmd)

if __name__ == "__main__":
    main()
