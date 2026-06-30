import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from scrapers.malaysiacyclist_scraper import MalaysiaCyclistScraper

load_dotenv()
cred = credentials.Certificate(os.getenv('FIREBASE_CREDENTIALS_PATH'))
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("Fetching latest scraper data for Malaysia Cyclist...")
mc_scraper = MalaysiaCyclistScraper()

try:
    mc_events = mc_scraper.scrape()
except Exception as e:
    print(f"MC failed: {e}")
    mc_events = []

image_map = {e['title']: e.get('image_url', '') for e in mc_events if e.get('image_url')}

print("Updating Firestore images for malaysiacyclist...")
docs = db.collection('events').where('source', '==', 'malaysiacyclist').get()
count = 0
for doc in docs:
    data = doc.to_dict()
    if not data.get('image_url'):
        title = data.get('title')
        matched_image = image_map.get(title)
        if matched_image:
            db.collection('events').document(doc.id).update({'image_url': matched_image})
            count += 1

print(f"Fixed {count} missing images.")
