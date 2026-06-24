import logging
import requests
from datetime import datetime, date
from typing import List, Dict, Optional
from .utils import categorize_event

logger = logging.getLogger(__name__)

class SoHikersScraper:
    def __init__(self):
        self.today = date.today()
        self.session = requests.Session()
        self.api_key = "AIzaSyDrugn_Im_ee0trdZ5cu8kU06r_XjF0BJE"
        self.project_id = "so-hikers-trip-builder"
        self.url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents:runQuery?key={self.api_key}"

    def _extract_value(self, field_data: dict) -> any:
        if not field_data:
            return None
        if 'stringValue' in field_data:
            return field_data['stringValue']
        if 'booleanValue' in field_data:
            return field_data['booleanValue']
        if 'integerValue' in field_data:
            return int(field_data['integerValue'])
        if 'doubleValue' in field_data:
            return float(field_data['doubleValue'])
        if 'timestampValue' in field_data:
            return field_data['timestampValue']
        return None

    def scrape(self) -> List[Dict]:
        events = []
        
        payload = {
            "structuredQuery": {
                "from": [{"collectionId": "trips"}],
                "select": {
                    "fields": [
                        {"fieldPath": "tripName"},
                        {"fieldPath": "tripDate"},
                        {"fieldPath": "tripLocation"},
                        {"fieldPath": "tripDifficulty"},
                        {"fieldPath": "tripFee"},
                        {"fieldPath": "storageKey"},
                        {"fieldPath": "deleted"},
                        {"fieldPath": "archived"},
                        {"fieldPath": "closed"},
                        {"fieldPath": "draft"},
                        {"fieldPath": "posterB64"},
                        {"fieldPath": "cardThumbB64"}
                    ]
                },
                "orderBy": [{"field": {"fieldPath": "tripDate"}, "direction": "ASCENDING"}],
                "limit": 100
            }
        }
        
        try:
            resp = self.session.post(self.url, json=payload, timeout=20)
            resp.raise_for_status()
            data = resp.json()
            
            for item in data:
                if 'document' not in item:
                    continue
                doc = item['document']
                fields = doc.get('fields', {})
                
                # Extract values
                raw_data = {k: self._extract_value(v) for k, v in fields.items()}
                
                # Check flags
                if raw_data.get('deleted') or raw_data.get('archived') or raw_data.get('closed') or raw_data.get('draft'):
                    continue
                
                date_str = raw_data.get('tripDate')
                if not date_str:
                    continue
                    
                # Parse date "YYYY-MM-DD"
                try:
                    event_date = datetime.strptime(date_str, '%Y-%m-%d')
                except ValueError:
                    continue
                    
                if event_date.date() < self.today:
                    continue
                    
                # Build event
                title = raw_data.get('tripName', 'SoHikers Trip')
                location = raw_data.get('tripLocation', 'Malaysia')
                difficulty = raw_data.get('tripDifficulty', '')
                fee = raw_data.get('tripFee', '')
                storage_key = raw_data.get('storageKey', '')
                
                description = f"Difficulty: {difficulty}" if difficulty else ""
                if fee:
                    description += f" | Fee: {fee}"
                
                url_event = f"https://sohikers.com/trip/?id={storage_key}" if storage_key else "https://sohikers.com/"
                
                category = "hiking" # Hardcode to hiking for SoHikers
                
                # Handle base64 image
                image_b64 = raw_data.get('posterB64') or raw_data.get('cardThumbB64') or ''
                image_url = ''
                if image_b64:
                    if image_b64.startswith('data:image'):
                        image_url = image_b64
                    else:
                        image_url = f"data:image/jpeg;base64,{image_b64}"
                
                events.append({
                    'title': title,
                    'date': event_date.isoformat(),
                    'location': location,
                    'category': category,
                    'url': url_event,
                    'image_url': image_url,
                    'description': description,
                    'is_virtual': False
                })
                
        except Exception as e:
            logger.error(f"SoHikers Scraping Failed: {e}")
            
        logger.info(f"SoHikers: Found {len(events)} upcoming events")
        return events
