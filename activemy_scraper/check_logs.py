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
    
    docs = db.collection('scraper_logs').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(5).stream()
    
    print("Fetching last 5 scraper logs...\n")
    for doc in docs:
        data = doc.to_dict()
        print(f"[{doc.id}] Timestamp: {data.get('timestamp')}")
        print(f"Status: {data.get('status')}")
        print(f"Triggered by: {data.get('triggered_by')}")
        print(f"Events found: {data.get('events_found')}, uploaded: {data.get('events_uploaded')}")
        details = data.get('details', {})
        for scraper, r in details.items():
            print(f"  {scraper}: found {r.get('found', 0)}, uploaded {r.get('uploaded', 0)}, status: {r.get('status')}")
            if 'error' in r:
                print(f"    Error: {r['error']}")
        print("-" * 50)
        
except Exception as e:
    print(f"Error checking logs: {e}")
