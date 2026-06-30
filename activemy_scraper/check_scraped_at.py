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

yesterday = datetime.now(timezone.utc) - timedelta(days=1)
print(f"Querying for events scraped after {yesterday}...")

docs = db.collection('events').where('scraped_at', '>=', yesterday).order_by('scraped_at', direction=firestore.Query.DESCENDING).limit(10).stream()

count = 0
for doc in docs:
    data = doc.to_dict()
    count += 1
    print(f"Title: {data.get('title')}, Scraped at: {data.get('scraped_at')}")

print(f"Total found: {count}")
