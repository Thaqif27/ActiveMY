# ActiveMY AI Recommendation Engine - Implementation Summary

## Overview
Created a comprehensive AI recommendation engine for ActiveMY using Google Gemini API (1.5 Flash model) with Firebase integration and FCM push notifications.

---

## Files Created/Modified

### 1. `activemy_scraper/recommendation_engine.py` (NEW)
**Purpose**: Dedicated module for all recommendation logic  
**Size**: ~380 lines

#### Core Functions:

1. **`get_user_behavior(uid: str, days: int = 30) -> dict`**
   - Fetches user's behavior from Firestore (last 30 days)
   - Returns: view_count, save_count, click_count, categories, events_viewed
   - Used to build context for Gemini API

2. **`get_upcoming_events(limit: int = 100) -> list`**
   - Fetches all upcoming active events from Firestore
   - Filters by: is_active==True, date >= now, sorted by date
   - Limited to 50 events in Gemini prompt to avoid token overflow

3. **`generate_recommendations_with_gemini(uid: str, behavior_summary: dict, events: list) -> list`**
   - Sends behavior summary + event list to Gemini 1.5 Flash
   - Parses JSON response
   - Returns list of recommended event IDs (top 5)
   - Handles markdown code block stripping and JSON parsing

4. **`send_recommendation_notification(uid: str, event_id: str) -> None`**
   - Fetches user's FCM token from Firestore
   - Sends FCM V1 notification via firebase_admin.messaging
   - Notification title: "Event you might like 🏃"
   - Notification body: event title
   - Saves notification to Firestore notifications/ collection
   - Raises ValueError if user/event not found

5. **`recommend_for_user(uid: str) -> dict`**
   - End-to-end recommendation pipeline for single user
   - Fetches behavior → Gets events → Generates recommendations → Sends notification
   - Returns: { uid, recommendations, notification_sent, error (if any) }
   - Safe error handling (doesn't crash if FCM fails)

6. **`recommend_for_all_users() -> dict`**
   - Batch recommendation job for all users
   - Iterates through all users in Firestore
   - Returns: { processed_users, successful, failed, results }
   - Used by scheduler (daily at 8:00 AM)

#### Firebase Collections Used:
- `user_behavior` - read (queries last 30 days)
- `events` - read (queries upcoming active events)
- `users` - read (fetches FCM token)
- `notifications` - write (saves notification history)

---

### 2. `activemy_scraper/main.py` (UPDATED)
**Purpose**: FastAPI backend with integrated recommendations  
**Key Changes**:

#### Imports Added:
```python
from firebase_admin import credentials, firestore, initialize_app, messaging
from recommendation_engine import recommend_for_all_users, recommend_for_user
```

#### New Endpoints:

1. **`POST /recommend/{uid}`**
   - Generates personalized recommendations for single user
   - Calls: `recommend_for_user(uid)`
   - Returns: { uid, recommendations, notification_sent, error (if any) }

2. **`POST /recommend/all`**
   - Batch recommendation job for all users
   - Calls: `recommend_for_all_users()`
   - Returns: { processed_users, successful, failed, results }
   - Can be triggered manually or by scheduler

#### Scheduler Setup:

Added in `startup_event()`:
```python
# Daily scraping job at 2:00 AM (Asia/Kuala_Lumpur)
scheduler.add_job(
    run_all_scrapers,
    "cron",
    hour=2,
    minute=0,
    id="scrape_job",
    name="Daily event scraping",
)

# Daily recommendation job at 8:00 AM (Asia/Kuala_Lumpur)
scheduler.add_job(
    recommend_for_all_users,
    "cron",
    hour=8,
    minute=0,
    id="recommend_job",
    name="Daily recommendations for all users",
)

scheduler.start()
```

#### Cleanup:
- Removed old `_build_behavior_summary()` function
- Removed old `_fetch_upcoming_events()` function
- Removed old `_recommend_events()` function
- Removed old `_send_recommendation_notification()` function (replaced with version in recommendation_engine.py)
- These are now in recommendation_engine.py with improved logic

---

## Gemini API Integration

### Model Configuration:
- **Model**: `gemini-1.5-flash` (fast, cost-effective for real-time recommendations)
- **Prompt Strategy**: 
  - Includes user behavior summary (view/save/click counts, category preferences)
  - Includes list of upcoming events (up to 50 to avoid token limits)
  - Requests JSON response with event IDs and reasons
  - Handles markdown code blocks in response

### Example Prompt Structure:
```
USER ACTIVITY:
- Events viewed: 5 times
- Events saved: 2 times
- Links clicked: 8 times
- Preferred categories: running, cycling
- Recently viewed event IDs: [event_id_1, event_id_2, ...]

AVAILABLE EVENTS:
- Event ID: abc123, Title: Marathon 2026, Category: running, ...
- Event ID: def456, Title: Mountain Bike Tour, Category: cycling, ...
...

TASK: Return top 5 recommendations with reasons
```

### Response Format:
```json
{
    "recommendations": [
        {"event_id": "abc123", "reason": "Matches running preference"},
        {"event_id": "def456", "reason": "Similar to past events"}
    ]
}
```

---

## FCM V1 API Integration

### Notification Flow:
1. Get user FCM token from `users/{uid}` document
2. Fetch event details from `events/{event_id}`
3. Create `messaging.Message` with:
   - Notification title: "Event you might like 🏃"
   - Notification body: event title
   - Data: { event_id }
   - Token: user's FCM token
4. Send via `messaging.send(message)`
5. Save to `notifications/{doc}` collection with:
   - uid, title, body, event_id, sent_at, is_read

### Error Handling:
- If user has no FCM token: logs warning, skips notification
- If FCM send fails: raises RuntimeError with details
- If user/event not found: raises ValueError

---

## Scheduler Jobs

### Configuration:
- **Timezone**: Asia/Kuala_Lumpur
- **Daily Scraping**: 2:00 AM
- **Daily Recommendations**: 8:00 AM
- **Auto-start**: Runs on FastAPI startup

### Manual Triggers:
- `POST /scrape/all` - Run scraping immediately
- `POST /recommend/all` - Run recommendations immediately

---

## Environment Variables

### Required (for recommendations):
- `FIREBASE_CREDENTIALS_PATH` - Path to Firebase service account JSON
- `GEMINI_API_KEY` - Google Gemini API key (from ai.google.dev)
- `GOOGLE_GEOCODING_API_KEY` - Google Maps Geocoding API key

### Optional:
- `EVENTBRITE_API_KEY` - For Eventbrite scraping (warns if not set)

### Removed:
- `FCM_SERVER_KEY` - No longer needed (using Firebase Admin SDK V1)

---

## Data Flow Diagram

```
User Activity (user_behavior collection)
         ↓
  get_user_behavior()
         ↓
  Behavior Summary {views, saves, clicks, categories, events}
         ↓
Upcoming Events (events collection, is_active=true)
         ↓
  generate_recommendations_with_gemini()
         ↓
  Gemini API (1.5 Flash)
         ↓
  Recommended Event IDs [id1, id2, id3, id4, id5]
         ↓
  send_recommendation_notification()
         ↓
  FCM Message → User Device
  Notification Saved → Firestore
```

---

## Testing

### Manual Testing:

1. **Single User Recommendation**:
   ```bash
   curl -X POST http://localhost:8000/recommend/user_id_123
   ```

2. **All Users Recommendations**:
   ```bash
   curl -X POST http://localhost:8000/recommend/all
   ```

3. **Health Check**:
   ```bash
   curl http://localhost:8000/health
   ```

### Python CLI Test:
```bash
python recommendation_engine.py user_id_123
```

---

## Performance Considerations

### Token Limits:
- Gemini 1.5 Flash: 1M input tokens
- Limited event list to 50 events per call to stay under limits

### Firestore Queries:
- `user_behavior` query: 30-day lookback (indexed by uid + timestamp)
- `events` query: upcoming + is_active (indexed by is_active + date)
- User document: single fetch by uid

### Batch Processing:
- `recommend_for_all_users()` processes sequentially (not parallel)
- ~1 API call per user for behavior summary
- ~1 Gemini API call per user for recommendations
- Consider async processing for scalability

---

## Future Enhancements

1. **Caching**: Cache user behavior summaries (TTL: 1 hour)
2. **Batching**: Process recommendations in batches using Gemini batch API
3. **Feedback Loop**: Store user feedback on recommendations to improve quality
4. **A/B Testing**: Compare different prompts/models
5. **Real-time**: Send recommendations on new matching events (not just daily)
6. **Personalization**: Adjust recommendation frequency per user preferences

---

## Files Summary

| File | Size | Lines | Purpose |
|------|------|-------|---------|
| `recommendation_engine.py` | 12.5 KB | ~380 | AI recommendation core logic |
| `main.py` | 15.3 KB | ~530 | FastAPI backend with scheduler |

**Total Implementation**: ~910 lines of production-ready code

---

## Dependencies

All required in `requirements.txt`:
- `firebase-admin==6.5.0` - Firebase Admin SDK with V1 FCM
- `google-generativeai==0.7.2` - Gemini API client
- `fastapi==0.111.0` - REST API framework
- `apscheduler==3.10.4` - Scheduler for daily jobs
- `python-dotenv==1.0.1` - Environment variable loading

---

**Generated**: 2026-05-28  
**Status**: ✅ Complete and ready for deployment
