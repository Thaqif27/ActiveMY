"""ActiveMY Scraper Backend - FastAPI Server with Manual Run Capability"""
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
import warnings
warnings.filterwarnings("ignore", category=Warning)
import os
import sys
import logging
import argparse
from datetime import datetime, timedelta
from typing import List, Dict, Any
from dotenv import load_dotenv

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from contextlib import asynccontextmanager
from apscheduler.schedulers.background import BackgroundScheduler

# Load environment variables
load_dotenv()

from recommendation_engine import recommend_for_user, recommend_for_all_users

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============ FIREBASE INITIALIZATION ============
import firebase_admin
from firebase_admin import credentials, firestore, messaging

try:
    if not firebase_admin._apps:
        cred_json_str = os.getenv('FIREBASE_CREDENTIALS_JSON')
        if cred_json_str:
            import json
            cred_dict = json.loads(cred_json_str)
            cred = credentials.Certificate(cred_dict)
        else:
            cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'activemy-a6bf1-firebase-adminsdk.json')
            cred = credentials.Certificate(cred_path)
            
        firebase_admin.initialize_app(cred)
        logger.info("Firebase initialized successfully")
    db = firestore.client()
except Exception as e:
    logger.error(f"Firebase initialization failed: {e}")
    db = None

# ============ SCRAPER IMPORTS (4 working scrapers) ============
try:
    from scrapers.jomrun_scraper import JomRunScraper
    from scrapers.racexasia_scraper import RaceXasiaScraper
    from scrapers.ticket2u_scraper import Ticket2UScraper
    from scrapers.malaysiarunner_scraper import MalaysiaRunnerScraper
    logger.info("Imported scrapers from scrapers/ folder")
except ImportError as e:
    logger.error(f"Failed to import scrapers: {e}")
    from scrapers.jomrun_scraper import JomRunScraper
    from scrapers.racexasia_scraper import RaceXasiaScraper
    from scrapers.ticket2u_scraper import Ticket2UScraper
    from scrapers.malaysiarunner_scraper import MalaysiaRunnerScraper
    logger.info("Imported scrapers from current directory")

# ============ HELPER FUNCTIONS ============
import googlemaps
from groq import Groq

gmaps = googlemaps.Client(key=os.getenv('GOOGLE_GEOCODING_API_KEY', ''))
groq_api_key = os.getenv('GROQ_API_KEY', '')
try:
    groq_client = Groq(api_key=groq_api_key) if groq_api_key else None
except Exception as e:
    logger.error(f"Failed to init Groq: {e}")
    groq_client = None

# Simple in-memory cache to prevent duplicate AI calls
_location_cache = {}

def process_event_with_ai_json(event_data: Dict) -> Dict:
    """Use Groq Llama 3 to extract structured location and category data"""
    title = event_data.get('title', '')
    raw_loc = event_data.get('location', '')
    desc = event_data.get('description', '')
    raw_cat = event_data.get('category', '')
    
    cache_key = f"{title}_{raw_loc[:30]}"
    if cache_key in _location_cache:
        return _location_cache[cache_key]
        
    prompt = f"""
    Analyze this sporting event to extract precise details.
    
    Title: {title}
    Raw Location: {raw_loc}
    Category: {raw_cat}
    Description: {desc[:500]}
    
    Tasks:
    1. Identify the physical venue name. If the event is fully virtual with no physical location, set the venue to "VIRTUAL". If it's a HYBRID event (has a physical location AND virtual category), return the actual physical venue and set is_virtual to true.
    2. Determine the City and State in Malaysia.
    3. Determine if the event is hosted inside Malaysia. If it is clearly hosted in another country (like Singapore, Indonesia, Australia), set is_malaysia to false.
    4. Estimate the Latitude and Longitude for this venue accurately.
    5. Refine the category to STRICTLY one of these: ["running", "cycling", "hiking", "triathlon", "adventure"]. If unsure, default to "running".
    
    Respond ONLY with a valid JSON object matching this exact schema:
    {{
        "venue": "String",
        "city": "String",
        "state": "String",
        "is_malaysia": true,
        "is_virtual": false,
        "lat": 0.0,
        "lng": 0.0,
        "category": "String"
    }}
    """
    
    try:
        import time
        import json
        time.sleep(2.5) # Keep under Groq free tier limit
        if not groq_client:
            return None
            
        chat_completion = groq_client.chat.completions.create(
            messages=[
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
            model="llama-3.1-8b-instant",
            response_format={"type": "json_object"},
        )
        text = chat_completion.choices[0].message.content
        data = json.loads(text)
        _location_cache[cache_key] = data
        return data
    except Exception as e:
        logger.error(f"AI JSON extraction failed: {e}")
        return None

def geocode_location(location: str) -> tuple:
    """Convert address to lat/lng"""
    if not location or location == "Malaysia":
        return None, None
        
    loc_upper = location.upper()
    HARDCODED_OVERRIDES = {
        "DATARAN MERDEKA": (3.1466, 101.6958),
        "PUTRAJAYA": (2.9283, 101.6869),
    }
    
    for key, coords in HARDCODED_OVERRIDES.items():
        if key in loc_upper:
            return coords
    
    try:
        result = gmaps.geocode(f"{location}, Malaysia")
        if result:
            lat = result[0]['geometry']['location']['lat']
            lng = result[0]['geometry']['location']['lng']
            return lat, lng
    except Exception as e:
        logger.error(f"Geocoding failed for {location}: {e}")
    
    return None, None

def deduplicate_events(events: List[Dict]) -> List[Dict]:
    """Remove duplicate events by title + date"""
    seen = set()
    unique = []
    for event in events:
        key = f"{event.get('title', '').lower()}_{event.get('date', '')}"
        if key not in seen:
            seen.add(key)
            unique.append(event)
    return unique

async def upload_to_firestore(events: List[Dict], source: str) -> int:
    """Upload events to Firestore"""
    if not db:
        logger.warning("Firestore not available, skipping upload")
        return 0
    
    uploaded = 0
    for event in events:
        try:
            event_date = datetime.fromisoformat(event['date'])
            
            # Skip past events
            if event_date.date() < datetime.now().date():
                continue
            
            # Extract precise data with AI
            ai_data = process_event_with_ai_json(event)
            
            is_virtual = event.get('is_virtual', False)
            clean_location = event.get('location', 'Malaysia')
            category = event.get('category', 'running')
            ai_processed = False
            lat, lng = 0.0, 0.0
            
            if ai_data:
                if not ai_data.get('is_malaysia', True):
                    logger.info(f"Skipping event '{event.get('title')}' as it is outside Malaysia.")
                    continue
                    
                ai_processed = True
                category = ai_data.get('category', category).lower()
                venue = ai_data.get('venue', 'Malaysia')
                
                is_virtual = ai_data.get('is_virtual', event.get('is_virtual', False))
                
                if venue == 'VIRTUAL':
                    venue = 'Malaysia'
                    
                city = ai_data.get('city', '')
                state = ai_data.get('state', '')
                loc_parts = [p for p in [venue, city, state] if p and p != 'null' and p != 'None']
                clean_location = ", ".join(loc_parts) if loc_parts else 'Malaysia'
                
                lat, lng = geocode_location(clean_location)
                if not lat or not lng:
                    lat = ai_data.get('lat')
                    lng = ai_data.get('lng')
            else:
                # Fallback if AI fails completely
                if 'virtual' in event.get('title', '').lower() or 'virtual' in event.get('location', '').lower():
                    is_virtual = True
                lat, lng = geocode_location(clean_location)
                
            lat = float(lat) if lat else 0.0
            lng = float(lng) if lng else 0.0
                
            # If the only location known is 'Malaysia', it has no physical venue
            is_generic = clean_location.lower().replace(',', '').replace('malaysia', '').strip() == ''
            is_center = (abs(lat - 4.210) < 0.01 and abs(lng - 101.975) < 0.01)
            
            if is_generic or is_center or venue == 'VIRTUAL':
                lat = 0.0
                lng = 0.0
                clean_location = 'Virtual / Flexible Location'
                
            if lat == 0.0 and lng == 0.0:
                is_virtual = True
                
            import pygeohash
            lat = float(lat)
            lng = float(lng)
            
            # Check bounding box (roughly Malaysia: Lat 0.5 to 8.0, Lng 99.0 to 120.0)
            if lat != 0.0 or lng != 0.0:
                if not (0.5 <= lat <= 8.0) or not (99.0 <= lng <= 120.0):
                    logger.info(f"Skipping event outside Malaysia: {event.get('title')}")
                    continue
                    
            geohash_str = pygeohash.encode(lat, lng, precision=9)
            
            # Check for duplicate event (same title and date)
            existing = db.collection('events')\
                .where('title', '==', event['title'][:100])\
                .where('date', '==', event_date)\
                .limit(1)\
                .get()
            
            if existing:
                doc = existing[0]
                doc_data = doc.to_dict()
                updates = {}
                # Update image_url if it is different (handles expiring S3 URLs or missing images)
                if event.get('image_url') and doc_data.get('image_url') != event.get('image_url'):
                    updates['image_url'] = event['image_url']
                
                # Update category if the scraper found a new categorization
                if doc_data.get('category') != event.get('category') and event.get('category'):
                    updates['category'] = event['category']
                    
                # Force update location data to fix bad previous pins
                if abs(doc_data.get('lat', 0) - lat) > 0.001 or abs(doc_data.get('lng', 0) - lng) > 0.001 or ai_processed:
                    updates['lat'] = lat
                    updates['lng'] = lng
                    updates['location_geo'] = firestore.GeoPoint(lat, lng)
                    updates['geo'] = {
                        'geohash': geohash_str,
                        'geopoint': firestore.GeoPoint(lat, lng)
                    }
                    updates['is_virtual'] = is_virtual
                    updates['location'] = clean_location[:100]
                    if ai_processed:
                        updates['ai_processed'] = True
                    
                if updates:
                    db.collection('events').document(doc.id).update(updates)
                    logger.debug(f"Updated missing fields for: {event['title'][:50]}")
                else:
                    logger.debug(f"Duplicate skipped: {event['title'][:50]}")
                continue
            
            # Upload new event
            event_data = {
                'title': event['title'][:200],
                'description': event.get('description', '')[:500],
                'category': category,
                'date': event_date,
                'location': clean_location[:100],
                'lat': lat,
                'lng': lng,
                'location_geo': firestore.GeoPoint(lat, lng),
                'geo': {
                    'geohash': geohash_str,
                    'geopoint': firestore.GeoPoint(lat, lng)
                },
                'source': source,
                'original_url': event.get('original_url', ''),
                'image_url': event.get('image_url', ''),
                'price': event.get('price', 'Free'),
                'scraped_at': datetime.now(),
                'is_active': True,
                'is_virtual': is_virtual,
                'ai_processed': ai_processed
            }
            db.collection('events').add(event_data)
            uploaded += 1
            logger.info(f"Uploaded: {event['title'][:50]} - {event_date.date()}")
            
        except Exception as e:
            logger.error(f"Upload error for {event.get('title', 'unknown')}: {e}")
    
    return uploaded

# ============ SCRAPER WRAPPERS (Only 6) ============

def run_finishers() -> List[Dict]:
    """Run Finishers scraper - DEPRECATED"""
    logger.warning("Finishers scraper deprecated")
    return []

def run_heyjom() -> List[Dict]:
    """Run HeyJom scraper - DEPRECATED"""
    logger.warning("HeyJom scraper deprecated")
    return []

def run_jomrun() -> List[Dict]:
    """Run JomRun scraper"""
    try:
        from scrapers.jomrun_scraper import JomRunScraper
        scraper = JomRunScraper()
        return scraper.scrape()
    except Exception as e:
        logger.error(f"JomRun failed: {e}")
        return []

def run_racexasia() -> List[Dict]:
    """Run RaceXasia scraper"""
    try:
        from scrapers.racexasia_scraper import RaceXasiaScraper
        scraper = RaceXasiaScraper()
        return scraper.scrape()
    except Exception as e:
        logger.error(f"RaceXasia failed: {e}")
        return []

def run_ticket2u() -> List[Dict]:
    """Run Ticket2U scraper"""
    try:
        from scrapers.ticket2u_scraper import Ticket2UScraper
        scraper = Ticket2UScraper()
        return scraper.scrape()
    except Exception as e:
        logger.error(f"Ticket2U failed: {e}")
        return []

def run_malaysiarunner() -> List[Dict]:
    """Run Malaysia Runner scraper"""
    try:
        from scrapers.malaysiarunner_scraper import MalaysiaRunnerScraper
        scraper = MalaysiaRunnerScraper()
        return scraper.scrape()
    except Exception as e:
        logger.error(f"Malaysia Runner failed: {e}")
        return []

def run_howei() -> List[Dict]:
    """Run Howei scraper - DEPRECATED"""
    logger.warning("Howei scraper deprecated")
    return []

def run_runningmalaysia() -> List[Dict]:
    """Run RunningMalaysia scraper - DEPRECATED"""
    logger.warning("RunningMalaysia scraper deprecated")
    return []

# ============ MAIN SCRAPE FUNCTION ============

async def run_all_scrapers(triggered_by: str = "manual") -> Dict[str, Dict]:
    """Run all 4 scrapers and collect results"""
    results = {}
    
    scrapers = {
        'jomrun': run_jomrun,
        'racexasia': run_racexasia,
        'ticket2u': run_ticket2u,
        'malaysiarunner': run_malaysiarunner,
    }
    
    total_found = 0
    total_uploaded = 0
    start_time = datetime.now()
    
    for name, scraper_func in scrapers.items():
        try:
            logger.info(f"Running {name} scraper...")
            events = scraper_func()
            
            if events:
                unique_events = deduplicate_events(events)
                uploaded = await upload_to_firestore(unique_events, name)
                results[name] = {
                    'found': len(unique_events),
                    'uploaded': uploaded,
                    'status': 'success'
                }
                total_found += len(unique_events)
                total_uploaded += uploaded
                logger.info(f"OK {name}: Found {len(unique_events)}, Uploaded {uploaded}")
            else:
                results[name] = {
                    'found': 0,
                    'uploaded': 0,
                    'status': 'no_events'
                }
                logger.warning(f"WARN {name}: No events found")
                
        except Exception as e:
            logger.error(f"FAIL {name} failed: {e}")
            results[name] = {
                'found': 0,
                'uploaded': 0,
                'status': 'error',
                'error': str(e)
            }
            
    # Write log to Firestore
    if db:
        try:
            log_entry = {
                'timestamp': datetime.now(),
                'triggered_by': triggered_by,
                'status': 'success' if any(r.get('status') == 'success' for r in results.values()) else 'failed',
                'events_found': total_found,
                'events_uploaded': total_uploaded,
                'duration_seconds': (datetime.now() - start_time).total_seconds(),
                'details': results
            }
            db.collection('scraper_logs').add(log_entry)
            db.collection('scraper_settings').document('settings').set({
                'last_run': log_entry['timestamp'],
                'status': log_entry['status']
            }, merge=True)
            logger.info(f"Logged scrape run to Firestore and updated settings: {triggered_by}")
        except Exception as e:
            logger.error(f"Failed to write log to Firestore: {e}")
            
    # Trigger AI Recommendations if new events were uploaded
    if total_uploaded > 0:
        logger.info(f"Triggering recommendations because {total_uploaded} new events were found...")
        import threading
        from recommendation_engine import recommend_for_all_users
        threading.Thread(target=recommend_for_all_users).start()
            
    return results

# ============ FASTAPI APP ============

# Initialize scheduler
scheduler = BackgroundScheduler()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Start scheduler on startup"""
    scheduler.start()
    logger.info("Scheduler started - polling DB for schedule every 5m")
    yield
    scheduler.shutdown()
    logger.info("Scheduler shutdown")

app = FastAPI(
    title="ActiveMY Scraper API",
    description="Scrapes running, cycling, and hiking events from Malaysian platforms",
    version="2.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============ API ENDPOINTS ============

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "ActiveMY Scraper API",
        "version": "2.0.0",
        "scrapers": ["jomrun", "racexasia", "ticket2u", "malaysiarunner"],
        "status": "running"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "firestore": db is not None,
        "scheduler_running": scheduler.running
    }

import requests
from fastapi.responses import StreamingResponse
import io

@app.get("/proxy-image")
async def proxy_image(url: str):
    """Proxy image requests to bypass CORS on Flutter Web"""
    if not url:
        raise HTTPException(status_code=400, detail="Missing URL")
    
    try:
        # Use a real user-agent to bypass basic blocks
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
        resp = requests.get(url, headers=headers, timeout=10)
        resp.raise_for_status()
        
        # Return the image with CORS headers
        content_type = resp.headers.get("content-type", "image/jpeg")
        return StreamingResponse(
            io.BytesIO(resp.content), 
            media_type=content_type,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "public, max-age=86400"
            }
        )
    except Exception as e:
        logger.error(f"Image proxy failed for {url}: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch image")

@app.post("/scrape/all")
async def scrape_all():
    """Run all 4 scrapers"""
    logger.info("Manual scrape triggered - running all scrapers")
    results = await run_all_scrapers(triggered_by="manual_admin")
    return results

@app.post("/recommend/{uid}")
async def recommend(uid: str):
    """Generate recommendations and send notification for a user"""
    logger.info(f"Manual recommendation triggered for user {uid}")
    result = recommend_for_user(uid)
    if "error" in result:
        raise HTTPException(500, detail=result["error"])
    return result

@app.post("/recommend/all")
async def recommend_all():
    """Generate recommendations and send notifications for all users"""
    logger.info("Manual batch recommendation triggered for all users")
    result = recommend_for_all_users()
    if "error" in result:
        raise HTTPException(500, detail=result["error"])
    return result

@app.post("/scrape/{source}")
async def scrape_single(source: str):
    """Run a single scraper"""
    scrapers = {
        "jomrun": run_jomrun,
        "racexasia": run_racexasia,
        "ticket2u": run_ticket2u,
        "malaysiarunner": run_malaysiarunner,
    }
    
    if source not in scrapers:
        raise HTTPException(404, detail=f"Scraper '{source}' not found. Available: {list(scrapers.keys())}")
    
    logger.info(f"Manual scrape triggered - running {source}")
    events = scrapers[source]()
    
    if events:
        unique_events = deduplicate_events(events)
        uploaded = await upload_to_firestore(unique_events, source)
        return {
            "source": source,
            "found": len(unique_events),
            "uploaded": uploaded,
            "status": "success"
        }
    
    return {
        "source": source,
        "found": 0,
        "uploaded": 0,
        "status": "no_events"
    }

@app.get("/events")
async def get_events(limit: int = 100, category: str = None):
    """Get events from Firestore"""
    if not db:
        return {"error": "Firestore not available"}
    
    query = db.collection('events')\
        .where('is_active', '==', True)\
        .order_by('date')
    
    if category:
        query = query.where('category', '==', category)
    
    events = query.limit(limit).get()
    
    return [
        {
            'id': doc.id,
            **doc.to_dict(),
            'date': doc.to_dict().get('date').isoformat() if doc.to_dict().get('date') else None
        }
        for doc in events
    ]

@app.get("/stats")
async def get_stats():
    """Get statistics about events in Firestore"""
    if not db:
        return {"error": "Firestore not available"}
    
    events = db.collection('events').where('is_active', '==', True).get()
    
    stats = {
        'total_events': len(events),
        'by_category': {},
        'by_source': {},
        'upcoming_events': 0
    }
    
    now = datetime.now()
    
    for doc in events:
        data = doc.to_dict()
        category = data.get('category', 'unknown')
        source = data.get('source', 'unknown')
        event_date = data.get('date')
        
        stats['by_category'][category] = stats['by_category'].get(category, 0) + 1
        stats['by_source'][source] = stats['by_source'].get(source, 0) + 1
        
        if event_date and event_date > now:
            stats['upcoming_events'] += 1
    
    return stats

# ============ SCHEDULED TASKS ============

def deactivate_past_events():
    """Deactivate events where date is before today"""
    if not db:
        logger.error("DB not initialized, cannot deactivate past events")
        return 0
        
    try:
        from datetime import timezone
        logger.info("Running deactivation of past events...")
        events_ref = db.collection('events')
        active_events = events_ref.where('is_active', '==', True).stream()
        
        now = datetime.now(timezone.utc)
        
        deactivated_count = 0
        for doc in active_events:
            data = doc.to_dict()
            event_date = data.get('date')
            
            if event_date:
                # Firestore returns DatetimeWithNanoseconds which is UTC aware
                if hasattr(event_date, 'tzinfo') and event_date.tzinfo is None:
                    event_date = event_date.replace(tzinfo=timezone.utc)
                elif isinstance(event_date, str):
                    # In case some dates were saved as strings
                    continue
                    
                # Deactivate if the event is strictly in the past (yesterday or older)
                # Compare it directly. If event_date < now
                if event_date < now:
                    doc.reference.update({'is_active': False})
                    deactivated_count += 1
                    logger.info(f"Deactivated past event: {data.get('title')}")
                    
        logger.info(f"Deactivated {deactivated_count} past events.")
        return deactivated_count
    except Exception as e:
        logger.error(f"Error deactivating past events: {e}")
        return 0

def check_and_run_scheduled_scrape():
    """Polls Firestore every 5 minutes to see if auto-scrape should run."""
    if not db:
        return
        
    try:
        settings_doc = db.collection('scraper_settings').document('settings').get()
        if not settings_doc.exists:
            # Create default settings
            db.collection('scraper_settings').document('settings').set({
                'enabled': True,
                'run_hour': 2,
                'last_run': None,
                'status': 'idle'
            })
            return
            
        data = settings_doc.to_dict()
        enabled = data.get('enabled', True)
        run_hour = data.get('run_hour', 2)
        last_run = data.get('last_run')
        
        if not enabled:
            return
            
        now = datetime.now()
        
        # Check if we reached the run_hour today
        if now.hour == run_hour:
            # Check if already ran today
            if last_run:
                from datetime import timezone
                if hasattr(last_run, 'tzinfo') and last_run.tzinfo is None:
                    last_run = last_run.replace(tzinfo=timezone.utc)
                if last_run.date() == now.date():
                    return # Already ran today
                    
            logger.info(f"Auto-scrape triggered for schedule hour {run_hour}")
            
            # Update status to running
            db.collection('scraper_settings').document('settings').set({
                'status': 'running'
            }, merge=True)
            
            # Run the scraper
            import asyncio
            try:
                loop = asyncio.new_event_loop()
                asyncio.set_event_loop(loop)
                loop.run_until_complete(run_all_scrapers(triggered_by="auto"))
                loop.close()
                status = 'success'
            except Exception as e:
                logger.error(f"Auto-scrape failed: {e}")
                status = 'error'
            
            # Update last_run
            db.collection('scraper_settings').document('settings').set({
                'last_run': datetime.now(),
                'status': status
            }, merge=True)
            
    except Exception as e:
        logger.error(f"Error checking schedule: {e}")

def scheduled_recommendations():
    """Run daily at 8 AM"""
    logger.info("Running scheduled daily recommendations (8:00 AM)...")
    recommend_for_all_users()

# Schedule the dynamic checker every 5 minutes
scheduler.add_job(
    check_and_run_scheduled_scrape, 
    'interval', 
    minutes=5,
    id='dynamic_scrape_checker',
    replace_existing=True
)

# Schedule daily at 8 AM
scheduler.add_job(
    scheduled_recommendations,
    'cron',
    hour=8,
    minute=0,
    id='daily_recommendations',
    replace_existing=True
)

# Schedule daily past events cleanup at 12:05 AM
scheduler.add_job(
    deactivate_past_events,
    'cron',
    hour=0,
    minute=5,
    id='daily_deactivate_past_events',
    replace_existing=True
)

# ============ MANUAL RUN (for testing) ============

async def manual_run():
    """Run scrapers once and exit"""
    print("\n" + "=" * 70)
    print("ACTIVE MY - SCRAPER MANUAL RUN")
    print("=" * 70)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Scrapers: JomRun, RaceXasia, Ticket2U, Malaysia Runner")
    print("=" * 70 + "\n")
    
    results = await run_all_scrapers(triggered_by="manual_cli")
    
    print("\n" + "=" * 70)
    print("SCRAPING SUMMARY")
    print("=" * 70)
    
    total_found = 0
    total_uploaded = 0
    
    for source, data in results.items():
        status_icon = "OK" if data.get('uploaded', 0) > 0 else "WARN" if data.get('found', 0) > 0 else "FAIL"
        print(f"[{status_icon:4}] {source.upper():15} | Found: {data.get('found', 0):3} | Uploaded: {data.get('uploaded', 0):3}")
        total_found += data.get('found', 0)
        total_uploaded += data.get('uploaded', 0)
    
    print("=" * 70)
    print(f"TOTAL: {total_found} events found, {total_uploaded} new events uploaded")
    print("=" * 70)
    
    # Run past events deactivation at the end of manual run
    deactivated = deactivate_past_events()
    print(f"CLEANUP: Deactivated {deactivated} past events.")
    print("=" * 70)
    
    return results

# ============ MAIN ENTRY POINT ============

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='ActiveMY Scraper')
    parser.add_argument('--manual', action='store_true', help='Run once and exit (for testing)')
    parser.add_argument('--port', type=int, default=8000, help='Port for API server (default: 8000)')
    
    args = parser.parse_args()
    
    if args.manual:
        # Manual mode - run once then exit
        import asyncio
        asyncio.run(manual_run())
    else:
        # Server mode - start API
        import uvicorn
        port = int(os.getenv('PORT', args.port))
        
        print("\n" + "=" * 70)
        print("ACTIVE MY - SCRAPER API SERVER")
        print("=" * 70)
        print(f"Server running on: http://localhost:{port}")
        print(f"Health check: http://localhost:{port}/health")
        print(f"Stats: http://localhost:{port}/stats")
        print(f"Scrape all: POST http://localhost:{port}/scrape/all")
        print(f"Scheduler polls Database every 5 minutes to run")
        print("=" * 70)
        print("\nAPI is ready! Press Ctrl+C to stop\n")
        
        uvicorn.run(app, host="0.0.0.0", port=port)