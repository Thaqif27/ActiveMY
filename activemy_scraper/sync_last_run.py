import os
from datetime import datetime, timezone
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()

try:
    if not firebase_admin._apps:
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        
    db = firestore.client()
    
    # Get the latest successful log
    logs = db.collection('scraper_logs').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(1).get()
    
    if logs:
        latest_log = logs[0].to_dict()
        latest_timestamp = latest_log['timestamp']
        print(f"Found latest log timestamp: {latest_timestamp}")
        
        # Update settings/scraper_settings
        db.collection('settings').document('scraper_settings').set({
            'last_run': latest_timestamp,
            'status': 'success'
        }, merge=True)
        print("Successfully synced last_run to settings/scraper_settings!")
    else:
        print("No logs found.")
        
except Exception as e:
    print(f"Error: {e}")
