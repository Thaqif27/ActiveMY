import logging
import json
import re
import requests
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional
from bs4 import BeautifulSoup
from .utils import categorize_event

logger = logging.getLogger(__name__)

class JomRunScraper:
    def __init__(self):
        self.today = date.today()
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})

    def _parse_date(self, date_str: str) -> Optional[datetime]:
        if not date_str:
            return None
        try:
            return datetime.fromisoformat(date_str.replace('Z', '+00:00').split('T')[0])
        except:
            for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d %B %Y', '%B %d, %Y', '%d %b %Y'):
                try:
                    return datetime.strptime(date_str, fmt)
                except:
                    continue
        return None

    def scrape(self) -> List[Dict]:
        events = []
        url = "https://www.jomrun.com/events"
        try:
            resp = self.session.get(url, timeout=20)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, 'html.parser')
            
            # 1) JSON-LD
            for script in soup.find_all('script', type='application/ld+json'):
                try:
                    data = json.loads(script.string)
                    if isinstance(data, dict) and data.get('@type') == 'Event':
                        self._add_event(data, events)
                    elif isinstance(data, list):
                        for item in data:
                            if isinstance(item, dict) and item.get('@type') == 'Event':
                                self._add_event(item, events)
                except:
                    continue
            
            # 2) HTML fallback
            for card in soup.select('.events_count'):
                a_tag = card.find('a')
                if not a_tag:
                    continue
                    
                url_event = a_tag.get('href', '')
                if url_event and not url_event.startswith('http'):
                    url_event = 'https://www.jomrun.com' + url_event

                title = a_tag.get_text(strip=True)
                if not title or len(title) < 3:
                    continue

                # Extract image
                image_url = ''
                img = card.find('img')
                if img:
                    # Often lazy loaded images use data-src or lazy-src
                    image_url = img.get('data-src') or img.get('lazy-src') or img.get('src', '')
                    if image_url and not image_url.startswith('http'):
                        if image_url.startswith('//'):
                            image_url = 'https:' + image_url
                        else:
                            image_url = 'https://www.jomrun.com' + ('' if image_url.startswith('/') else '/') + image_url

                # Extract date
                date_text = ''
                parent_text = card.get_text(" ", strip=True)
                date_match = re.search(r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\s+(\d{4})', parent_text)
                if date_match:
                    date_text = f"{date_match.group(1)} {date_match.group(2)} {date_match.group(3)}"
                
                event_date = self._parse_date(date_text)
                
                if not event_date:
                    logger.debug(f"JomRun: no date found for '{title}', skipping")
                    continue
                
                if event_date.date() < self.today:
                    continue
                    
                # Deep Scrape for location
                location_text = 'Malaysia'
                description_text = ''
                if url_event:
                    try:
                        resp = self.session.get(url_event, timeout=10)
                        detail_soup = BeautifulSoup(resp.content, 'html.parser')
                        
                        # Try to find a specific location element if it exists
                        # If not, use description
                        desc_elem = detail_soup.select_one('.description-content') or detail_soup.find('div', class_='event-description')
                        if desc_elem:
                            description_text = desc_elem.get_text("\n\n", strip=True)
                            
                        # Try to find location by looking for "Location" text
                        loc_elem = detail_soup.find(string=re.compile(r'Location|Venue', re.I))
                        if loc_elem and loc_elem.parent and loc_elem.parent.parent:
                            location_text = loc_elem.parent.parent.get_text(" ", strip=True).replace('Location', '').replace('Venue', '').strip()
                        
                        if not location_text or len(location_text) < 3:
                            location_text = 'Malaysia'
                            
                    except Exception as e:
                        logger.debug(f"Deep scrape failed for {url_event}: {e}")
                        
                # Virtual Run check
                is_virtual = 'virtual' in title.lower() or 'virtual' in description_text.lower()

                events.append({
                    'title': title,
                    'description': description_text,
                    'category': categorize_event(title),
                    'date': event_date.isoformat(),
                    'location': location_text,
                    'image_url': image_url,
                    'original_url': url_event,
                    'price': 'Free',
                    'is_virtual': is_virtual
                })
            logger.info(f"JomRun: scraped {len(events)} real events")
        except Exception as e:
            logger.error(f"JomRun error: {e}")
        return events

    def _add_event(self, data: dict, events: list):
        title = data.get('name')
        if not title:
            return
        start_date = data.get('startDate')
        if not start_date:
            return
        event_date = self._parse_date(start_date)
        if not event_date or event_date.date() < self.today:
            return
        location = data.get('location', {})
        loc_name = location.get('name', 'Malaysia') if isinstance(location, dict) else 'Malaysia'
        
        image_data = data.get('image', '')
        image_url = ''
        if isinstance(image_data, list) and len(image_data) > 0:
            image_url = image_data[0]
        elif isinstance(image_data, str):
            image_url = image_data
            
        if image_url and not image_url.startswith('http'):
            if image_url.startswith('//'):
                image_url = 'https:' + image_url
            else:
                image_url = 'https://www.jomrun.com' + ('' if image_url.startswith('/') else '/') + image_url

        events.append({
            'title': title,
            'description': data.get('description', '')[:500],
            'category': categorize_event(title),
            'date': event_date.isoformat(),
            'location': loc_name,
            'image_url': image_url,
            'original_url': data.get('url', ''),
            'price': data.get('offers', {}).get('price', 'Free') if isinstance(data.get('offers'), dict) else 'Free'
        })