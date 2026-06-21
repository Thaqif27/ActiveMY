import logging
import re
import requests
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional
from bs4 import BeautifulSoup
from .utils import categorize_event

logger = logging.getLogger(__name__)

class RaceXasiaScraper:
    def __init__(self):
        self.today = date.today()
        self.session = requests.Session()
        self.session.headers.update({'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'})

    def _parse_date(self, date_str: str) -> Optional[datetime]:
        if not date_str:
            return None
        date_str = date_str.replace('Date:', '').strip()
        # RaceXasia often uses ranges like "3 Aug 2026 - 4 Aug 2026" or "10 Aug 2026", "2025-12-25"
        patterns = [
            r'(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)\s+(\d{4})',
            r'([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})',
            r'(\d{4})-(\d{2})-(\d{2})'
        ]
        for pat in patterns:
            m = re.search(pat, date_str)
            if m:
                if len(m.groups()) == 3:
                    try:
                        if m.group(1).isdigit() and len(m.group(1)) == 4:  # YYYY-MM-DD
                            return datetime.strptime(f"{m.group(1)}-{m.group(2)}-{m.group(3)}", '%Y-%m-%d')
                        elif m.group(1).isdigit():  # DD Month YYYY
                            return datetime.strptime(f"{m.group(1)} {m.group(2)} {m.group(3)}", '%d %B %Y')
                        else:  # Month DD, YYYY
                            return datetime.strptime(f"{m.group(1)} {m.group(2)} {m.group(3)}", '%B %d %Y')
                    except:
                        try:
                            if m.group(1).isdigit():
                                return datetime.strptime(f"{m.group(1)} {m.group(2)} {m.group(3)}", '%d %b %Y')
                            else:
                                return datetime.strptime(f"{m.group(1)} {m.group(2)} {m.group(3)}", '%b %d %Y')
                        except:
                            pass
        return None

    def scrape(self) -> List[Dict]:
        events = []
        url = "https://racexasia.com/events"
        try:
            resp = self.session.get(url, timeout=20)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, 'html.parser')
            
            # Target specific event cards
            cards = soup.select('.event-wrapper')
            
            for card in cards:
                title_elem = card.select_one('.event-content .title')
                if not title_elem:
                    continue
                
                title = title_elem.get_text(strip=True)
                if not title or len(title) < 4:
                    continue
                
                # Find date
                date_text = ''
                date_elem = card.select_one('.event-meta .date')
                if date_elem:
                    date_text = date_elem.get_text(strip=True)
                
                event_date = self._parse_date(date_text)
                
                if not event_date:
                    logger.debug(f"RaceXasia: no date parsed for '{title}', skipping")
                    continue
                
                if event_date.date() < self.today:
                    continue
                
                # Location
                location = 'Malaysia'
                loc_elem = card.select_one('.location')
                if loc_elem:
                    location = loc_elem.get_text(strip=True)
                
                # URL
                url_event = title_elem.get('href', '')
                if url_event and not url_event.startswith('http'):
                    url_event = 'https://racexasia.com' + url_event
                    
                # Image
                image_url = ''
                img_elem = card.select_one('.event-image .image.lazy')
                if img_elem and img_elem.has_attr('data-src'):
                    image_url = img_elem['data-src']
                elif img_elem and img_elem.has_attr('src'):
                    image_url = img_elem['src']
                elif card.select_one('img'):
                    img = card.select_one('img')
                    if img and img.has_attr('src'):
                        image_url = img['src']

                if image_url and not image_url.startswith('http'):
                    if image_url.startswith('//'):
                        image_url = 'https:' + image_url
                    else:
                        image_url = 'https://racexasia.com' + ('' if image_url.startswith('/') else '/') + image_url
                
                is_virtual = 'virtual' in title.lower() or 'virtual' in location.lower()

                events.append({
                    'title': title[:200],
                    'description': '',
                    'category': categorize_event(title),
                    'date': event_date.isoformat(),
                    'location': location,
                    'image_url': image_url,
                    'original_url': url_event,
                    'price': 'Free',
                    'source': 'racexasia',
                    'is_virtual': is_virtual
                })
                if len(events) >= 50:
                    break
            logger.info(f"RaceXasia: scraped {len(events)} real events")
        except Exception as e:
            logger.error(f"RaceXasia error: {e}")
        return events

# The _categorize function was removed