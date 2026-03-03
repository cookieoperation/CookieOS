import sys
import os
import requests
import json

# CookieOS Aluminum AI App Builder v1.0
# Uses Ollama to generate app code and builds it

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "llama3"

SYSTEM_PROMPT = """
You are the CookieOS AI App Builder. Generate a single-file React/HTML/CSS application based on the user's description.
Output ONLY valid code. No markdown formatting.
- Use Vanilla JS/CSS for simplicity if possible.
- Wrap everything in a single index.html.
"""

def generate_app(description):
    print(f"🧠 Thinking about your app: {description}...")
    try:
        data = {
            "model": MODEL,
            "prompt": f"{SYSTEM_PROMPT}\nUser Request: {description}\nCode:",
            "stream": False
        }
        response = requests.post(OLLAMA_URL, json=data)
        response.raise_for_status()
        return response.json().get("response", "").strip()
    except Exception as e:
        return f"<h1>Error generating app</h1><p>{str(e)}</p>"

def main():
    if len(sys.argv) < 2:
        print("Usage: ai-app-builder 'a simple calculator'")
        sys.exit(1)

    description = " ".join(sys.argv[1:])
    app_code = generate_app(description)
    
    # Save to a new app directory
    app_name = description.lower().replace(" ", "_")
    os.makedirs(f"/opt/cookieos/apps/{app_name}", exist_ok=True)
    
    with open(f"/opt/cookieos/apps/{app_name}/index.html", "w") as f:
        f.write(app_code)
        
    print(f"✅ App created successfully in /opt/cookieos/apps/{app_name}!")

if __name__ == "__main__":
    main()
