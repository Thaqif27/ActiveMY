import firebase_admin
from firebase_admin import credentials, firestore
import os
import json
from dotenv import load_dotenv

load_dotenv()

# Initialize Firestore
try:
    cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'activemy-a6bf1-firebase-adminsdk.json')
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
except Exception as e:
    print(f"Error initializing Firebase: {e}")
    exit(1)

def clean_locations():
    events_ref = db.collection('events')
    docs = events_ref.stream()
    
    updated = 0
    
    for doc in docs:
        data = doc.to_dict()
        loc = data.get('location', '')
        loc_lower = loc.lower()
        
        # Check if the location string has any of the bad phrases or exact bad words
        has_bad = any(bad in loc_lower for bad in ['not_provided', 'null', 'none', 'n/a', 'not provided', 'not available', 'unspecified', 'unknown'])
        has_exact_bad = False
        for p in loc_lower.split(','):
            pl = p.strip()
            if pl in ['about', 'venue', 'location']:
                has_exact_bad = True
                break
                
        if has_bad or has_exact_bad:
            parts = [p.strip() for p in loc.split(',')]
            
            def is_valid(p):
                pl = p.lower()
                if pl in ['about', 'venue', 'location']: return False
                for bad in ['not_provided', 'null', 'none', 'n/a', 'not provided', 'not available', 'unspecified', 'unknown']:
                    if bad in pl:
                        return False
                return bool(p.strip())
                
            clean_parts = [p for p in parts if is_valid(p)]
            new_loc = ", ".join(clean_parts) if clean_parts else 'Malaysia'
            
            if new_loc != loc:
                print(f"Updating {data.get('title')[:30]}...: '{loc}' -> '{new_loc}'")
                doc.reference.update({'location': new_loc})
                updated += 1
                
    print(f"Finished updating {updated} events.")

if __name__ == "__main__":
    clean_locations()
