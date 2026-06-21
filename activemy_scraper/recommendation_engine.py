"""
AI-powered recommendation engine for ActiveMY using Google Gemini API.

This module provides functions to:
1. Fetch user behavior from Firestore (last 30 days)
2. Fetch upcoming active events
3. Generate recommendations using Gemini 2.0 Flash Lite (highest free-tier limits)
4. Send push notifications for top recommendations
"""

import time
import json
import logging
import os
from datetime import datetime, timedelta, timezone
from typing import Optional

import firebase_admin
from groq import Groq
from dotenv import load_dotenv
from firebase_admin import credentials, firestore, messaging

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("activemy-recommendation")

FIREBASE_CREDENTIALS_PATH = os.getenv("FIREBASE_CREDENTIALS_PATH")
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not FIREBASE_CREDENTIALS_PATH:
    raise RuntimeError("FIREBASE_CREDENTIALS_PATH is not set.")

if not GROQ_API_KEY:
    raise RuntimeError("GROQ_API_KEY is not set.")

# Initialize Groq client
_groq_client = Groq(api_key=GROQ_API_KEY)

# Model to use — llama-3.1-8b-instant
# - 30 RPM
AI_MODEL = "llama-3.1-8b-instant"

# Initialize Firebase Admin SDK if not already initialized
if not firebase_admin._apps:
    creds = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)
    firebase_admin.initialize_app(creds)


def _firebase_client():
    """Get Firestore client instance."""
    return firestore.client()


def get_user_behavior(uid: str, days: int = 30) -> dict:
    """
    Fetch user behavior data from Firestore (last N days).

    Args:
        uid: User ID
        days: Number of days to look back (default: 30)

    Returns:
        Dictionary with behavior summary: {
            'view_count': int,
            'save_count': int,
            'click_count': int,
            'categories': list of strings,
            'events_viewed': list of event IDs
        }
    """
    db = _firebase_client()
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)

    behavior_docs = (
        db.collection("user_behavior")
        .where("uid", "==", uid)
        .stream()
    )

    behavior_summary = {
        "view_count": 0,
        "save_count": 0,
        "click_count": 0,
        "categories": [],
        "events_viewed": [],
    }

    for doc in behavior_docs:
        data = doc.to_dict()
        
        # In-memory timestamp filter to avoid Firestore composite index requirement
        doc_time = data.get("timestamp")
        if doc_time and hasattr(doc_time, "timestamp"):
            if doc_time < cutoff_date:
                continue

        action = data.get("action", "")

        if action == "view":
            behavior_summary["view_count"] += 1
            event_id = data.get("event_id")
            if event_id:
                behavior_summary["events_viewed"].append(event_id)

        elif action == "save":
            behavior_summary["save_count"] += 1

        elif action == "click_url":
            behavior_summary["click_count"] += 1

        category = data.get("category", "")
        if category and category not in behavior_summary["categories"]:
            behavior_summary["categories"].append(category)

    logger.info(
        f"User {uid} behavior: {behavior_summary['view_count']} views, "
        f"{behavior_summary['save_count']} saves, "
        f"{behavior_summary['click_count']} clicks"
    )

    return behavior_summary


def get_upcoming_events(limit: int = 100, recent_days: int = None) -> list:
    """
    Fetch all upcoming active events from Firestore.

    Args:
        limit: Maximum number of events to fetch
        recent_days: If set, only returns events scraped within the last N days

    Returns:
        List of event dictionaries with keys:
        id, title, description, category, date, location, image_url, source
    """
    db = _firebase_client()
    now = datetime.now(timezone.utc)

    events_docs = (
        db.collection("events")
        .where("is_active", "==", True)
        .where("date", ">=", now)
        .order_by("date", direction=firestore.Query.ASCENDING)
        .limit(limit)
        .stream()
    )

    events = []
    recent_cutoff = now - timedelta(days=recent_days) if recent_days else None

    for doc in events_docs:
        event_data = doc.to_dict()
        
        # In-memory filter for recent events since Firestore only allows one inequality filter
        if recent_cutoff and event_data.get("scraped_at"):
            scraped_at = event_data["scraped_at"]
            if hasattr(scraped_at, "timestamp"):  # Handle Google Cloud Datetime/Timestamp
                if scraped_at < recent_cutoff:
                    continue
            
        event_data["id"] = doc.id
        events.append(event_data)

    logger.info(f"Fetched {len(events)} upcoming active events")
    return events


def generate_recommendations_with_ai(
    uid: str, behavior_summary: dict, events: list, user_location: dict
) -> dict | None:
    """
    Use Groq AI API to generate personalized recommendations and custom notification text.

    Args:
        uid: User ID (for context)
        behavior_summary: User behavior summary from get_user_behavior()
        events: List of upcoming events from get_upcoming_events()
        user_location: Dictionary with 'lat' and 'lng' of the user

    Returns:
        Dictionary with:
            event_id: str
            title: str
            body: str
        Or None if no recommendation is generated.
    """
    if not events:
        logger.warning("No upcoming events available for recommendations")
        return []

    # Calculate distance for each event and sort
    import math
    def calc_dist(lat1, lon1, lat2, lon2):
        if lat1 is None or lon1 is None or lat2 is None or lon2 is None:
            return float('inf')
        try:
            R = 6371
            dLat = math.radians(lat2 - lat1)
            dLon = math.radians(lon2 - lon1)
            a = math.sin(dLat/2) * math.sin(dLat/2) + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dLon/2) * math.sin(dLon/2)
            return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
        except:
            return float('inf')
            
    user_lat = user_location.get('lat')
    user_lng = user_location.get('lng')
    
    for e in events:
        e['_distance_km'] = calc_dist(user_lat, user_lng, e.get('lat'), e.get('lng'))
        
    # Sort events by distance (closest first)
    events.sort(key=lambda x: x['_distance_km'])

    # Format events for the prompt
    events_text = "\n".join(
        [
            f"- Event ID: {e.get('id', 'N/A')}, "
            f"Title: {e.get('title', 'N/A')}, "
            f"Category: {e.get('category', 'N/A')}, "
            f"Date: {e.get('date', 'N/A')}, "
            f"Location: {e.get('location', 'N/A')}, "
            f"Distance: {e['_distance_km'] if e['_distance_km'] != float('inf') else 'Unknown'} km away, "
            f"Description: {str(e.get('description', ''))[:100]}"
            for e in events[:50]  # Limit to prevent token overflow
        ]
    )

    # Create recommendation prompt
    location_rule = (
        '4. CRITICAL: Always prioritize the event with the shortest distance (in km) to the user, provided it somewhat matches their preferred categories. Do NOT recommend an event hundreds of km away if a closer one exists!'
        if user_lat is not None and user_lng is not None
        else '4. Recommend the best overall event that matches their categories, ignoring distance since the user location is unknown.'
    )

    prompt = f"""
Based on this user's activity history and current location, find the SINGLE best event for them to attend from the available list, and write a personalized push notification to excite them.

USER PROFILE:
- Events viewed: {behavior_summary.get('view_count', 0)} times
- Events saved: {behavior_summary.get('save_count', 0)} times
- Preferred categories: {', '.join(behavior_summary.get('categories', []))}
- Recently viewed event IDs: {', '.join(behavior_summary.get('events_viewed', [])[:10])}

AVAILABLE NEW EVENTS (Sorted by nearest distance if location known):
{events_text}

TASK:
Return ONLY a valid JSON object (no markdown, no extra text) with this structure:
{{
    "event_id": "...",
    "notification_title": "...",
    "notification_body": "..."
}}

RULES:
1. "notification_title" must be short (max 40 chars) and catchy (e.g. "New Hiking Trail Near Shah Alam! 🥾").
2. "notification_body" must be a personalized message (max 100 chars) explaining why it matches their behavior and location (e.g. "Since you love hiking, check out this new event just 10km away!").
3. Only pick ONE event. If no events match their behavior, return an empty JSON {{}}.
{location_rule}
"""

    try:
        # Retry logic: up to 3 attempts with exponential backoff (handles 429s)
        last_error = None
        for attempt in range(3):
            try:
                chat_completion = _groq_client.chat.completions.create(
                    messages=[
                        {
                            "role": "user",
                            "content": prompt,
                        }
                    ],
                    model=AI_MODEL,
                    response_format={"type": "json_object"},
                )
                response_text = chat_completion.choices[0].message.content
                break  # Success — exit retry loop
            except Exception as e:
                last_error = e
                if "429" in str(e) or "rate limit" in str(e).lower():
                    wait = 2 ** attempt * 5  # 5s, 10s, 20s
                    logger.warning(f"Rate limited (attempt {attempt+1}/3), waiting {wait}s...")
                    time.sleep(wait)
                else:
                    raise  # Non-rate-limit error — don't retry
        else:
            logger.error(f"All retry attempts failed: {last_error}")
            return None

        # Parse JSON response
        try:
            result = json.loads(response_text.strip())
            
            if not result or not result.get("event_id"):
                return None

            logger.info(f"Generated custom recommendation for user {uid}")
            return {
                "event_id": result.get("event_id"),
                "title": result.get("notification_title"),
                "body": result.get("notification_body")
            }

        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse AI response JSON: {e}")
            logger.error(f"Response text: {response_text}")
            return None

    except Exception as e:
        logger.error(f"Groq API call failed: {e}")
        return None


def send_recommendation_notification(uid: str, event_id: str, title: str, body: str) -> None:
    """
    Send FCM push notification for a recommended event.

    Args:
        uid: User ID
        event_id: Event ID to recommend
        title: Notification title
        body: Notification body

    Raises:
        ValueError: If user or event not found
        RuntimeError: If FCM send fails
    """
    db = _firebase_client()

    # Save notification to Firestore FIRST so it appears in the Alerts tab
    db.collection("notifications").add(
        {
            "uid": uid,
            "title": title,
            "body": body,
            "event_id": event_id,
            "sent_at": datetime.now(timezone.utc),
            "is_read": False,
        }
    )

    # Fetch user FCM token for Push Notification
    user_doc = db.collection("users").document(uid).get()
    if not user_doc.exists:
        logger.warning(f"User {uid} not found for FCM push")
        return

    user_data = user_doc.to_dict() or {}
    fcm_token = user_data.get("fcm_token")
    if not fcm_token:
        logger.warning(f"User {uid} has no FCM token, skipped Push Notification (Saved to DB only)")
        return

    # Fetch event details
    event_doc = db.collection("events").document(event_id).get()
    if not event_doc.exists:
        logger.warning(f"Event {event_id} not found for FCM push")
        return

    # Send FCM notification using V1 API
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=fcm_token,
            data={"event_id": event_id},
        )
        messaging.send(message)
        logger.info(f"Sent recommendation notification to user {uid} for event {event_id}")

    except Exception as exc:
        logger.error(f"FCM V1 send failed: {exc}")


def recommend_for_user(uid: str) -> dict:
    """
    Generate and send recommendations for a single user.

    Args:
        uid: User ID

    Returns:
        Dictionary with:
        - recommendations: list of recommended event IDs
        - notification_sent: whether top event was notified
        - error: error message if any
    """
    try:
        # Fetch user behavior
        behavior_summary = get_user_behavior(uid)

        # Fetch user details (including location)
        db = _firebase_client()
        user_doc = db.collection("users").document(uid).get()
        user_data = user_doc.to_dict() or {}
        user_location = {
            "lat": user_data.get("last_known_lat"),
            "lng": user_data.get("last_known_lng")
        }

        # Fetch previously recommended event IDs to prevent duplicates
        from google.cloud.firestore_v1.base_query import FieldFilter
        notif_docs = db.collection("notifications").where(filter=FieldFilter("uid", "==", uid)).get()
        notified_event_ids = {doc.to_dict().get("event_id") for doc in notif_docs}

        # Fetch upcoming events (only ones scraped in the last 2 days)
        events = get_upcoming_events(limit=50, recent_days=2)
        
        # Filter out events already recommended
        events = [e for e in events if e.get("id") not in notified_event_ids]

        # 4. Generate recommendation with AI
        recommendation = generate_recommendations_with_ai(uid, behavior_summary, events, user_location)

        # Send notification for the recommendation
        notification_sent = False
        if recommendation and recommendation.get("event_id"):
            try:
                send_recommendation_notification(
                    uid, 
                    recommendation["event_id"],
                    recommendation["title"],
                    recommendation["body"]
                )
                notification_sent = True
            except (ValueError, RuntimeError) as e:
                logger.warning(f"Failed to send notification for user {uid}: {e}")

        return {
            "uid": uid,
            "recommendation": recommendation,
            "notification_sent": notification_sent,
        }

    except Exception as e:
        logger.error(f"Recommendation generation failed for user {uid}: {e}")
        return {
            "uid": uid,
            "recommendations": [],
            "notification_sent": False,
            "error": str(e),
        }


def recommend_for_all_users() -> dict:
    """
    Generate and send recommendations for all active users.

    Returns:
        Dictionary with:
        - processed_users: count
        - successful: count
        - failed: count
        - results: list of per-user results
    """
    db = _firebase_client()

    try:
        # Fetch all users
        users_docs = db.collection("users").stream()
        user_ids = [doc.id for doc in users_docs]

        logger.info(f"Processing recommendations for {len(user_ids)} users")

        results = []
        successful = 0
        failed = 0

        for uid in user_ids:
            result = recommend_for_user(uid)
            results.append(result)

            if "error" not in result:
                successful += 1
            else:
                failed += 1

        logger.info(
            f"Recommendation job complete: {successful} successful, {failed} failed"
        )

        return {
            "processed_users": len(user_ids),
            "successful": successful,
            "failed": failed,
            "results": results,
        }

    except Exception as e:
        logger.error(f"Batch recommendation job failed: {e}")
        return {
            "processed_users": 0,
            "successful": 0,
            "failed": 0,
            "error": str(e),
        }


if __name__ == "__main__":
    # Test the recommendation engine
    import sys

    if len(sys.argv) > 1:
        test_uid = sys.argv[1]
        result = recommend_for_user(test_uid)
        print(json.dumps(result, indent=2, default=str))
    else:
        print("Usage: python recommendation_engine.py <uid>")
