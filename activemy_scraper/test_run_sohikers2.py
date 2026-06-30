import sys
import os
import asyncio
import firebase_admin
from firebase_admin import credentials, firestore
from scrapers.sohikers_scraper import SoHikersScraper
from datetime import datetime, timezone
from dotenv import load_dotenv

load_dotenv()
os.environ['GOOGLE_API_KEY'] = 'fake_key'

async def main():
    scraper = SoHikersScraper()
    print("Scraping So Hikers...")
    events = scraper.scrape()
    print(f"Scraped {len(events)} events.")
    
    cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'activemy-a6bf1-firebase-adminsdk.json')
    cred = credentials.Certificate(cred_path)
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
    db = firestore.client()

    uploaded = 0
    for event in events:
        try:
            try:
                event_date = datetime.fromisoformat(event['date'])
            except:
                continue
                
            img_url = event.get('image_url', '')

            existing = db.collection('events')\
                .where('title', '==', event['title'][:100])\
                .where('date', '==', event_date)\
                .limit(1)\
                .get()
            
            if existing:
                doc = existing[0]
                doc_data = doc.to_dict()
                updates = {'scraped_at': datetime.now(timezone.utc), 'status': firestore.DELETE_FIELD}
                if img_url and doc_data.get('image_url') != img_url:
                    updates['image_url'] = img_url
                db.collection('events').document(doc.id).update(updates)
                print(f"Updated {event['title']}")
            else:
                event_data = {
                    'title': event['title'][:200],
                    'description': event.get('description', '')[:500],
                    'category': event.get('category', 'hiking'),
                    'date': event_date,
                    'location': event.get('location', '')[:100],
                    'lat': 0.0,
                    'lng': 0.0,
                    'location_geo': firestore.GeoPoint(0.0, 0.0),
                    'source': 'sohikers',
                    'original_url': event.get('url', ''),
                    'image_url': img_url,
                    'price': event.get('description', '').split('Fee: ')[-1] if 'Fee: ' in event.get('description', '') else 'Free',
                    'scraped_at': datetime.now(timezone.utc),
                    'is_active': True,
                    'is_virtual': False,
                    'ai_processed': False
                }
                doc_ref = db.collection('events').document()
                event_data['id'] = doc_ref.id
                doc_ref.set(event_data)
                print(f"Inserted {event['title']}")
            uploaded += 1
        except Exception as e:
            print(f"Error saving {event.get('title')}: {e}")

    print(f"Done saving {uploaded} events.")

if __name__ == "__main__":
    asyncio.run(main())
