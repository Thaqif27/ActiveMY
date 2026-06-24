import os
import sys
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
    
    # Reset status and run_hour
    db.collection('scraper_settings').document('settings').set({
        'status': 'idle',
        'run_hour': 1
    }, merge=True)
    
    print("Reset settings to idle and run_hour to 1")
except Exception as e:
    print(f"Error: {e}")
