import logging
import requests
from bs4 import BeautifulSoup
from datetime import datetime, date
from typing import List, Dict, Optional
from .utils import categorize_event

logger = logging.getLogger(__name__)

class MalaysiaCyclistScraper:
    def __init__(self):
        self.today = date.today()
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        self.base_url = "https://malaysiacyclist.com"

    def _parse_date(self, date_str: str) -> Optional[datetime]:
        if not date_str:
            return None
        # Example: Sat, 3 Jan 2026
        # Strip off the day of week and comma
        parts = date_str.split(', ')
        if len(parts) > 1:
            clean_date_str = parts[1].strip()
        else:
            clean_date_str = date_str.strip()
            
        try:
            return datetime.strptime(clean_date_str, '%d %b %Y')
        except ValueError:
            # Fallback for full month
            try:
                return datetime.strptime(clean_date_str, '%d %B %Y')
            except ValueError:
                return None

    def scrape(self) -> List[Dict]:
        events = []
        url = f"{self.base_url}/events/"
        
        try:
            resp = self.session.get(url, timeout=20)
            resp.raise_for_status()
            soup = BeautifulSoup(resp.text, 'html.parser')
            
            cards = soup.find_all('a', class_='event-card')
            for card in cards:
                try:
                    event_url = card.get('href', '')
                    if event_url and not event_url.startswith('http'):
                        event_url = self.base_url + event_url
                        
                    title_elem = card.find('h3')
                    if not title_elem:
                        continue
                    title = title_elem.get_text(strip=True)
                    
                    # Next sibling p tags hold date, location
                    date_elem = title_elem.find_next_sibling('p')
                    if not date_elem:
                        continue
                    date_text = date_elem.get_text(strip=True)
                    event_date = self._parse_date(date_text)
                    
                    if not event_date or event_date.date() < self.today:
                        continue
                        
                    loc_elem = date_elem.find_next_sibling('p')
                    location = loc_elem.get_text(strip=True) if loc_elem else "Malaysia"
                    
                    # Tags
                    tags = []
                    tags_div = card.find('div', class_='flex-wrap')
                    if tags_div:
                        for span in tags_div.find_all('span'):
                            tags.append(span.get_text(strip=True))
                            
                    # Description
                    desc_elem = card.find('p', class_='text-slate-400')
                    description = desc_elem.get_text(strip=True) if desc_elem else ""
                    
                    # Categories usually in tags. E.g. 'road', 'mtb', 'gravel', 'triathlon'
                    raw_category = ", ".join(tags)
                    category = categorize_event(title + " " + raw_category)
                    if not category:
                        category = "cycling" # Default for this site
                        
                    # Check if virtual
                    is_virtual = 'virtual' in title.lower() or 'virtual' in raw_category.lower() or 'virtual' in description.lower()
                    
                    events.append({
                        'title': title,
                        'date': event_date.isoformat(),
                        'location': location,
                        'category': category,
                        'url': event_url,
                        'image_url': '',  # No image on the main list
                        'description': description,
                        'is_virtual': is_virtual
                    })
                except Exception as e:
                    logger.debug(f"MalaysiaCyclist: Failed to parse a card: {e}")
                    continue
                    
        except Exception as e:
            logger.error(f"MalaysiaCyclist Scraping Failed: {e}")
            
        logger.info(f"MalaysiaCyclist: Found {len(events)} upcoming events")
        return events
