import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore
from scrapers.malaysiacyclist_scraper import MalaysiaCyclistScraper
from scrapers.sohikers_scraper import SoHikersScraper

load_dotenv()
cred = credentials.Certificate(os.getenv('FIREBASE_CREDENTIALS_PATH'))
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("Fetching latest scraper data...")
mc_scraper = MalaysiaCyclistScraper()
so_scraper = SoHikersScraper()

try:
    mc_events = mc_scraper.scrape()
except Exception as e:
    print(f"MC failed: {e}")
    mc_events = []
    
try:
    so_events = so_scraper.scrape()
except Exception as e:
    print(f"SO failed: {e}")
    so_events = []

all_scraper_events = mc_events + so_events
url_map = {e['title']: e.get('url', e.get('original_url', '')) for e in all_scraper_events}

print("Updating Firestore...")
docs = db.collection('events').where('source', 'in', ['malaysiacyclist', 'sohikers']).get()
count = 0
for doc in docs:
    data = doc.to_dict()
    if data.get('original_url') == '':
        title = data.get('title')
        # Some titles in Firestore were truncated to 200 chars, but hopefully these are short enough
        matched_url = url_map.get(title)
        if matched_url:
            db.collection('events').document(doc.id).update({'original_url': matched_url})
            print(f"Updated URL")
            count += 1

print(f"Fixed {count} missing URLs.")
