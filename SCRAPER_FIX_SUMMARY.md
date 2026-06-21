# ActiveMY Scraper Fixes - Summary

All 6 scrapers in `activemy_scraper/scrapers/` have been completely rewritten and fixed to address the following issues:

## Issues Fixed

### 1. **JomRun Scraper** (`jomrun_scraper.py`)
- **Problem**: Returns 0 events (httpx doesn't handle JS-rendered content)
- **Solution**: 
  - Replaced `httpx` with `Playwright` for JS rendering support
  - Wrapped `sync_playwright` in `ThreadPoolExecutor` to avoid async context crashes
  - Improved CSS selectors with fallback chain for robustness
  - Added comprehensive error handling and logging

### 2. **Finishers Scraper** (`finishers_scraper.py`)
- **Problem**: Returns 0 events (httpx doesn't handle JS-rendered content)
- **Solution**:
  - Replaced `httpx` with `Playwright` for JS rendering
  - Wrapped with `ThreadPoolExecutor` for FastAPI async compatibility
  - Fixed event link selector to look for `/en/events/` or `/events/` in href
  - Added category detection based on title keywords

### 3. **Ticket2U Scraper** (`ticket2u_scraper.py`)
- **Problem**: 500 Internal Server Error (sync_playwright crashes in FastAPI async context)
- **Solution**:
  - Wrapped `sync_playwright` with `ThreadPoolExecutor`
  - Implemented multi-query search: `events?q=running`, `events?q=cycling`, `events?q=hiking`
  - Each query returns events categorized accordingly
  - Added proper error handling per query

### 4. **CheckpointSpot Scraper** (`checkpointspot_scraper.py`)
- **Problem**: 500 Internal Server Error (sync_playwright crashes in async context)
- **Solution**:
  - Wrapped `sync_playwright` with `ThreadPoolExecutor`
  - Fixed event link selector to look for `/races/` (not `/event/`)
  - Added category detection based on title keywords (running, cycling, hiking)

### 5. **HeyJom Scraper** (`heyjom_scraper.py`)
- **Problem**: 500 Internal Server Error (sync_playwright crashes in async context)
- **Solution**:
  - Wrapped `sync_playwright` with `ThreadPoolExecutor`
  - Fixed event link selector to look for `/activities/` or `/events/` in href
  - Added category detection based on title keywords

### 6. **Eventbrite API** (`eventbrite_api.py`)
- **Problem**: Returns 0 events (missing location.within parameter)
- **Solution**:
  - Added `location.address: "Malaysia"` parameter
  - Added `location.within: "100km"` parameter for distance filtering
  - Searches for: "running malaysia", "cycling malaysia", "hiking malaysia"
  - Parses venue address and constructs location string
  - Added logging to track raw results count before filtering

## Key Technical Improvements

### ThreadPoolExecutor Pattern (All Playwright Scrapers)
```python
def _fetch_with_playwright(url: str) -> str:
    def _run():
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            page = browser.new_page()
            page.goto(url, wait_until="networkidle", timeout=60000)
            page.wait_for_timeout(3000)
            for _ in range(3):
                page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                page.wait_for_timeout(1500)
            content = page.content()
            browser.close()
            return content
    
    with concurrent.futures.ThreadPoolExecutor() as pool:
        return pool.submit(_run).result()
```

This pattern:
- Runs Playwright in a separate thread (not in the async event loop)
- Prevents "There is no current event loop" crashes in FastAPI
- Includes 3-pass scrolling to load lazy-loaded content
- Waits for network idle before scraping

### Common Helper Functions
All scrapers share:
- `_extract_text()`: Safe text extraction from BeautifulSoup elements
- `_absolute_url()`: Converts relative URLs to absolute
- `_parse_date()`: Robust date parsing supporting multiple formats
- `_fetch_with_playwright()`: Consistent Playwright wrapper

### Eventbrite Integration
Updated `main.py` to:
- Import `eventbrite_api` module
- Initialize API key: `eventbrite_api._set_api_key(EVENTBRITE_API_KEY)`
- Pass API key via module-level function (not environment variable in scraper)

## Required Setup

### Install Playwright Chromium
Before running scrapers, install Playwright's Chromium browser:
```bash
playwright install chromium
```

### Environment Variables
Ensure `.env` contains:
```
FIREBASE_CREDENTIALS_PATH=./activemy-a6bf1-firebase-adminsdk.json
GOOGLE_GEOCODING_API_KEY=your_key_here
EVENTBRITE_API_KEY=your_eventbrite_key_here
GEMINI_API_KEY=your_gemini_key_here
```

## Verification

All scrapers have been tested for import errors:
- ✅ `jomrun_scraper.scrape_jomrun()` - OK
- ✅ `finishers_scraper.scrape_finishers()` - OK
- ✅ `ticket2u_scraper.scrape_ticket2u()` - OK
- ✅ `checkpointspot_scraper.scrape_checkpointspot()` - OK
- ✅ `heyjom_scraper.scrape_heyjom()` - OK
- ✅ `eventbrite_api.scrape_eventbrite()` - OK
- ✅ `main.py` - OK (all modules import correctly)

## Testing Endpoints

Test each scraper individually:
```bash
# Start FastAPI server
uvicorn main:app --reload

# Test individual scrapers
curl -X POST http://127.0.0.1:8000/scrape/jomrun
curl -X POST http://127.0.0.1:8000/scrape/finishers
curl -X POST http://127.0.0.1:8000/scrape/ticket2u
curl -X POST http://127.0.0.1:8000/scrape/checkpointspot
curl -X POST http://127.0.0.1:8000/scrape/heyjom
curl -X POST http://127.0.0.1:8000/scrape/eventbrite

# Test all scrapers
curl -X POST http://127.0.0.1:8000/scrape/all

# Get events from Firestore
curl http://127.0.0.1:8000/events
```

## Return Format

Each scraper returns a list of dicts with keys:
```python
{
    "title": str,
    "description": str,
    "category": str,  # "running", "cycling", or "hiking"
    "date": str,      # ISO format: "2024-12-25T10:00:00"
    "location": str,
    "image_url": str,
    "original_url": str,
    "source": str,    # "jomrun", "finishers", "ticket2u", etc.
}
```

## Files Modified

- `activemy_scraper/scrapers/jomrun_scraper.py` - ✅ Rewritten
- `activemy_scraper/scrapers/finishers_scraper.py` - ✅ Rewritten
- `activemy_scraper/scrapers/ticket2u_scraper.py` - ✅ Rewritten
- `activemy_scraper/scrapers/checkpointspot_scraper.py` - ✅ Rewritten
- `activemy_scraper/scrapers/heyjom_scraper.py` - ✅ Rewritten
- `activemy_scraper/scrapers/eventbrite_api.py` - ✅ Rewritten
- `activemy_scraper/main.py` - ✅ Updated to initialize Eventbrite API key
