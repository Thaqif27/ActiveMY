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
    
    scrapers = ['jomrun', 'ticket2u', 'racexasia', 'malaysiarunner', 'malaysiacyclist', 'sohikers']
    
    for s in scrapers:
        db.collection('settings').document(f'scraper_{s}').set({
            'status': 'idle'
        }, merge=True)
        print(f"Reset {s} to idle")
        
    print("All scrapers reset to idle.")
except Exception as e:
    print(f"Error: {e}")
