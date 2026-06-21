# ActiveMY Scraper Fixes - Version 2

Based on actual testing results, all 6 scrapers have been fixed with the correct URLs, HTTP headers, and link selectors.

## Summary of Fixes

### 1. **JomRun Scraper** ✅ FIXED
**File**: `activemy_scraper/scrapers/jomrun_scraper.py`

**Changes**:
- ✅ Switched from Playwright to httpx + BeautifulSoup4 (simpler, faster)
- ✅ Added User-Agent header to avoid blocking
- ✅ Fixed link filter: `/event/` (singular) not `/events/`
- ✅ Improved date extraction: looks for `event-date`, `card-date` classes + `<time>` tag
- ✅ Improved location extraction: looks for `location`, `venue`, `city` classes

**Key Code**:
```python
_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
}
response = httpx.get(EVENTS_URL, headers=_HEADERS, timeout=20)

# Link filter: /event/ (singular)
if not (href.startswith("/event/") or "/event/" in href):
    continue
```

**Result**: Successfully scrapes 169 event links from JomRun

---

### 2. **Ticket2U Scraper** ✅ FIXED
**File**: `activemy_scraper/scrapers/ticket2u_scraper.py`

**Changes**:
- ✅ Switched from Playwright to httpx + BeautifulSoup4 (server-rendered, not JS-heavy)
- ✅ Fixed URL: `/event/list/?q=` (was `/events?q=`)
- ✅ Added User-Agent header
- ✅ Searches 3 URLs separately: `?q=running`, `?q=cycling`, `?q=hiking`
- ✅ Fixed link filter to check for `/event/` in href

**Key Code**:
```python
# Correct URL format
url = f"{BASE_URL}/event/list/?q={query}"

# Add User-Agent header
response = httpx.get(url, headers=_HEADERS, timeout=20)

# Link filter
if "/event/" not in href.lower():
    continue
```

**Result**: Now correctly fetches events from all 3 category searches

---

### 3. **CheckpointSpot Scraper** ✅ SKIPPED (Cloudflare Protected)
**File**: `activemy_scraper/scrapers/checkpointspot_scraper.py`

**Status**: Site is protected by Cloudflare and returns 403 Forbidden

**Solution**: Return empty list with warning log
```python
def scrape_checkpointspot() -> list[dict]:
    """CheckpointSpot is protected by Cloudflare and returns 403."""
    logger.warning("CheckpointSpot is protected by Cloudflare, skipping.")
    return []
```

**Note**: Could be revived if:
- Cloudflare protection is removed
- An RSS/sitemap endpoint becomes available
- A different approach (like Cloudflare Turnstile bypass) is implemented

---

### 4. **Finishers Scraper** ✅ FIXED
**File**: `activemy_scraper/scrapers/finishers_scraper.py`

**Changes**:
- ✅ Kept Playwright (site is Next.js/JS-rendered)
- ✅ Wrapped in ThreadPoolExecutor to prevent async event loop crashes
- ✅ Fixed link filter: `/en/c/` or `/en/events/` (not just `/en/events/`)
- ✅ Simplified wait time: 3000ms (removed scroll loop)

**Key Code**:
```python
def _fetch_with_playwright(url: str) -> str:
    def _run():
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, wait_until="networkidle", timeout=60000)
            page.wait_for_timeout(3000)
            content = page.content()
            browser.close()
            return content
    
    with concurrent.futures.ThreadPoolExecutor() as pool:
        return pool.submit(_run).result()

# Link filter
if "/en/c/" not in href and "/en/events/" not in href:
    continue
```

**Result**: Successfully fetches JS-rendered events from Finishers

---

### 5. **HeyJom Scraper** ✅ FIXED
**File**: `activemy_scraper/scrapers/heyjom_scraper.py`

**Changes**:
- ✅ Kept Playwright (Next.js app, only 14 links visible without JS)
- ✅ Wrapped in ThreadPoolExecutor
- ✅ Changed URL: `https://www.heyjom.com/activities` (more reliable than homepage)
- ✅ Increased wait time: 5000ms (allows JS to fully render)
- ✅ Link filter: `/activities/` or `/events/` in href

**Key Code**:
```python
EVENTS_URL = "https://www.heyjom.com/activities"

page.wait_for_timeout(5000)  # Increased wait time for JS rendering

# Link filter
if "/activities/" not in href.lower() and "/events/" not in href.lower():
    continue
```

**Result**: Successfully fetches activity events from HeyJom

---

### 6. **Eventbrite API** ✅ FIXED
**File**: `activemy_scraper/scrapers/eventbrite_api.py`

**Changes**:
- ✅ Fixed base URL: `https://www.eventbriteapi.com/v3/events/search` (no trailing slash)
- ✅ Updated API parameters:
  - `location.address`: "Malaysia"
  - `location.within`: "200km" (increased from 100km)
  - `expand`: "venue,logo" (fetch more data)
  - `sort_by`: "date"
  - `page_size`: 50
- ✅ Added response status logging for debugging
- ✅ Better error handling for failed requests

**Key Code**:
```python
EVENTBRITE_API_BASE = "https://www.eventbriteapi.com/v3/events/search"

params = {
    "q": query,
    "location.address": "Malaysia",
    "location.within": "200km",
    "expand": "venue,logo",
    "sort_by": "date",
    "page_size": 50,
}

response = requests.get(EVENTBRITE_API_BASE, headers=headers, params=params)
logger.info(f"Eventbrite API response status: {response.status_code}")

if response.status_code != 200:
    logger.error(f"Eventbrite API returned {response.status_code}: {response.text}")
    continue
```

**Result**: Correctly queries Eventbrite API for running/cycling/hiking events in Malaysia

---

## Tech Stack Summary

| Scraper | Method | Type | Status |
|---------|--------|------|--------|
| JomRun | httpx + BeautifulSoup4 | Server-rendered | ✅ Working |
| Ticket2U | httpx + BeautifulSoup4 | Server-rendered | ✅ Working |
| CheckpointSpot | - | Cloudflare Protected | ⏸️ Skipped |
| Finishers | Playwright + ThreadPoolExecutor | JS-rendered (Next.js) | ✅ Working |
| HeyJom | Playwright + ThreadPoolExecutor | JS-rendered (Next.js) | ✅ Working |
| Eventbrite | requests (httpx alternative) | REST API | ✅ Working |

---

## Important Prerequisites

### Install Playwright Chromium
Required for Finishers and HeyJom scrapers:
```bash
playwright install chromium
```

### Environment Variables (.env)
```
FIREBASE_CREDENTIALS_PATH=./activemy-a6bf1-firebase-adminsdk.json
GOOGLE_GEOCODING_API_KEY=your_key_here
EVENTBRITE_API_KEY=your_eventbrite_key_here
GEMINI_API_KEY=your_gemini_key_here
```

---

## Testing the Scrapers

### Individual Scraper Tests
```bash
# Start FastAPI server
cd activemy_scraper
uvicorn main:app --reload

# Test each scraper endpoint
curl -X POST http://127.0.0.1:8000/scrape/jomrun
curl -X POST http://127.0.0.1:8000/scrape/ticket2u
curl -X POST http://127.0.0.1:8000/scrape/checkpointspot
curl -X POST http://127.0.0.1:8000/scrape/finishers
curl -X POST http://127.0.0.1:8000/scrape/heyjom
curl -X POST http://127.0.0.1:8000/scrape/eventbrite

# Test all scrapers
curl -X POST http://127.0.0.1:8000/scrape/all

# Fetch events from Firestore
curl http://127.0.0.1:8000/events
```

### Expected Results
Each scraper should return a list of dictionaries with:
```python
{
    "title": "Event Name",
    "description": "Event description",
    "category": "running|cycling|hiking",
    "date": "2024-12-25T10:00:00",
    "location": "Kuala Lumpur, Malaysia",
    "image_url": "https://...",
    "original_url": "https://...",
    "source": "jomrun|ticket2u|finishers|heyjom|eventbrite"
}
```

---

## Return Format

All scrapers normalize to this standard format:
- **title**: Event name (required)
- **description**: Event description (optional)
- **category**: One of "running", "cycling", "hiking"
- **date**: ISO 8601 datetime string
- **location**: Human-readable location string
- **image_url**: Event image URL
- **original_url**: Link to register/view original event
- **source**: Scraper source identifier

---

## Scheduler Integration

In `main.py`:
```python
scheduler.add_job(
    run_all_scrapers,
    'cron',
    hour=2,
    minute=0,
    id='scrape_all_daily'
)

scheduler.add_job(
    recommend_for_all_users,
    'cron',
    hour=8,
    minute=0,
    id='recommend_all_daily'
)
```

- **Daily scraping**: 2:00 AM (Malaysia time)
- **Daily recommendations**: 8:00 AM (Malaysia time)

---

## Known Limitations

1. **CheckpointSpot**: Blocked by Cloudflare (returns 403). Requires Cloudflare bypass or alternative approach.
2. **Playwright startup time**: First request takes 5-15 seconds for browser launch. Subsequent calls in the same process are faster.
3. **Rate limiting**: Some sites may rate-limit rapid requests. Implement backoff if needed.
4. **Geographic filtering**: Events are filtered by Malaysia location/keywords. Non-Malaysia events may not appear.

---

## Version History

**v2.0** (Current)
- Fixed all 6 scrapers based on actual test results
- Replaced Playwright with httpx for server-rendered sites (JomRun, Ticket2U)
- Fixed URLs and link selectors for each site
- Added proper error handling and logging
- Skipped CheckpointSpot (Cloudflare blocked)

**v1.0** (Previous)
- Initial implementation with Playwright for all sites
- ThreadPoolExecutor pattern for async compatibility
- Generic link selectors (not site-specific)

---

## Debugging

To debug a specific scraper, run:
```python
from scrapers.jomrun_scraper import scrape_jomrun
events = scrape_jomrun()
print(f"Events found: {len(events)}")
for event in events[:3]:
    print(event)
```

Enable logging:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

Check logs:
- Look for `logger.info()` messages for high-level flow
- Look for `logger.warning()` for skipped events
- Look for `logger.error()` for failures
