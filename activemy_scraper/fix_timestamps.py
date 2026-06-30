import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta, timezone

load_dotenv()
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
cred = credentials.Certificate(cred_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("Fixing timezone offset for scraped_at...")
count = 0
docs = db.collection('events').get()

now_utc = datetime.now(timezone.utc)

for doc in docs:
    data = doc.to_dict()
    updates = {}
    
    if 'scraped_at' in data and data['scraped_at']:
        scraped_at = data['scraped_at']
        if isinstance(scraped_at, datetime):
            # Check if it's in the future
            if scraped_at > now_utc:
                # It's in the future, likely due to naive local time being saved as UTC
                # Assuming local time is UTC+8
                corrected_time = scraped_at - timedelta(hours=8)
                updates['scraped_at'] = corrected_time
    
    if updates:
        db.collection('events').document(doc.id).update(updates)
        count += 1

print(f"Fixed {count} events.")
