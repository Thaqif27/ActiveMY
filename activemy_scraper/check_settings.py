import os
import sys
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()

try:
    if not firebase_admin._apps:
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        if cred_path:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            print("No FIREBASE_CREDENTIALS_PATH found in .env")
            sys.exit(1)
        
    db = firestore.client()
    
    doc = db.collection('scraper_settings').document('settings').get()
    
    print("Scraper settings:")
    if doc.exists:
        data = doc.to_dict()
        for k, v in data.items():
            print(f"{k}: {v}")
    else:
        print("No settings found")
        
except Exception as e:
    print(f"Error checking settings: {e}")
