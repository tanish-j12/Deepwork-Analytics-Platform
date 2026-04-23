import time
import requests
import threading
import pygetwindow as gw
from datetime import datetime
from flask import Flask, request, jsonify
from flask_cors import CORS
import logging

print("==========================================")
print("🚀 DeepWork Auto-Tracker Booting...")
print("==========================================")

# ==============================================================================
# 1. THE COMMUNICATION BRIDGE (Listens for UI Login)
# ==============================================================================
app = Flask(__name__)
CORS(app) 

USER_ID = None

@app.route('/link-tracker', methods=['POST'])
def link_tracker():
    global USER_ID
    data = request.json
    USER_ID = data.get('u_id')
    user_name = data.get('name')
    
    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)

    print(f"\n✅ UI LOGIN DETECTED!")
    print(f"🔗 Tracker automatically linked to {user_name} (ID: {USER_ID})")
    print("------------------------------------------")
    
    return jsonify({"success": True, "message": "Tracker Linked!"})

def run_local_server():
    app.run(host='127.0.0.1', port=5005, debug=False, use_reloader=False)

threading.Thread(target=run_local_server, daemon=True).start()

print("⏳ Waiting for you to log in via the Web UI (http://localhost:3000)...")

while USER_ID is None:
    time.sleep(1)

# ==============================================================================
# 2. THE TRACKING ENGINE (With Hard Guard Logic)
# ==============================================================================
print("\n👀 Waiting for a study session to be started in the UI...")

CURRENT_SESSION_ID = None 

while True:
    try:
        # 1. Ask the server safely
        response = requests.get(f"http://localhost:3000/api/sessions/active/{USER_ID}")
        
        try:
            session_data = response.json()
            S_ID = session_data.get('s_id')
        except ValueError:
            print(f"⚠️ Backend Error: Server returned status {response.status_code}")
            S_ID = None

        # --- THE HARD GUARD ---
        # If the server says there is NO active session, we MUST stop tracking.
        if S_ID is None:
            if CURRENT_SESSION_ID is not None:
                print(f"\n🔴 Session Ended in UI. Stopping tracker loop...")
                CURRENT_SESSION_ID = None
            
            # Reset to waiting state and skip the rest of this loop
            time.sleep(5) 
            continue 
        # ----------------------

        # 2. If we reach here, a session is CONFIRMED active in the DB
        if CURRENT_SESSION_ID != S_ID:
            print(f"\n🟢 Active Session Detected! (ID: {S_ID})")
            print("   Now tracking your productivity...")
            CURRENT_SESSION_ID = S_ID

        # 3. Track the window
        window = gw.getActiveWindow()
        if window and window.title:
            payload = {
                "s_id": S_ID,
                "title": window.title,
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
            
            # Send data to the categorized logger
            requests.post("http://localhost:3000/api/tracker/log", json=payload)
            print(f"   [{time.strftime('%H:%M:%S')}] Tracked: {window.title[:50]}...")
        
    except requests.exceptions.ConnectionError:
        print("❌ Connection Lost: Waiting for Node.js server...")
        time.sleep(5)

    # Check again in 5 seconds
    time.sleep(5)