import requests
from bs4 import BeautifulSoup
import logging
from datetime import datetime, date
import re
from typing import Optional
from .utils import categorize_event

logger = logging.getLogger(__name__)

class MalaysiaRunnerScraper:
    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        })
        self.today = date.today()
        self.base_urls = [
            "https://www.malaysiarunner.com/events",
            "https://www.malaysiarunner.com"
        ]

    def _parse_date(self, date_str: str) -> Optional[datetime]:
        if not date_str:
            return None
        try:
            for fmt in ('%d %b %Y', '%Y-%m-%d', '%d/%m/%Y', '%d %B %Y'):
                try:
                    return datetime.strptime(date_str.strip(), fmt)
                except:
                    pass
        except:
            pass
        return None
        
    def scrape(self):
        events = []
        
        for base_url in self.base_urls:
            try:
                resp = self.session.get(base_url, timeout=15)
                soup = BeautifulSoup(resp.content, 'html.parser')
                
                for card in soup.select('.card'):
                    try:
                        title_elem = card.select_one('.card-title') or card.select_one('.event-title') or card.select_one('h3') or card.select_one('h4')
                        title = title_elem.get_text(strip=True) if title_elem else ''
                        if not title or len(title) < 3:
                            continue
                            
                        link = card.select_one('a[href*="/event/"]')
                        if not link:
                            continue
                            
                        url_val = link.get('href', '')
                        if url_val and not url_val.startswith('http'):
                            url_val = 'https://www.malaysiarunner.com' + url_val
                            
                        date_elem = card.select_one('.date-h4')
                        date_text = date_elem.get_text(strip=True) if date_elem else ''
                        event_date = self._parse_date(date_text) if date_text else None
                        
                        if not event_date:
                            logger.debug(f"Malaysia Runner: no date for '{title}', skipping")
                            continue
                            
                        if event_date.date() < self.today:
                            continue
                            
                        # Image URL
                        image_url = ''
                        img_elem = card.select_one('img')
                        if img_elem and img_elem.has_attr('src'):
                            image_url = img_elem['src']
                            
                        if image_url and not image_url.startswith('http'):
                            if image_url.startswith('//'):
                                image_url = 'https:' + image_url
                            else:
                                image_url = 'https://www.malaysiarunner.com' + ('' if image_url.startswith('/') else '/') + image_url
                            
                        # Deep Scrape for location
                        location_text = 'Malaysia'
                        description_text = ''
                        if url_val:
                            try:
                                resp = self.session.get(url_val, timeout=10)
                                detail_soup = BeautifulSoup(resp.content, 'html.parser')
                                
                                desc_elem = detail_soup.find('div', class_='event-description') or detail_soup.find('div', class_='content')
                                if desc_elem:
                                    description_text = desc_elem.get_text(" ", strip=True)
                                    
                                loc_elem = detail_soup.find(string=re.compile(r'Location|Venue', re.I))
                                if loc_elem and loc_elem.parent and loc_elem.parent.parent:
                                    location_text = loc_elem.parent.parent.get_text(" ", strip=True).replace('Location', '').replace('Venue', '').strip()
                                elif description_text and 'virtual' not in title.lower():
                                    location_text = description_text[:200]
                                    
                            except Exception as e:
                                logger.debug(f"Deep scrape failed for {url_val}: {e}")
                                
                        # Virtual Run check
                        is_virtual = 'virtual' in title.lower() or 'virtual' in location_text.lower()

                        events.append({
                            'title': title[:200],
                            'description': description_text[:500],
                            'category': categorize_event(title),
                            'date': event_date.isoformat(),
                            'location': location_text,
                            'image_url': image_url,
                            'original_url': url_val,
                            'price': 'Free',
                            'source': 'malaysiarunner',
                            'is_virtual': is_virtual
                        })
                        
                    except Exception as e:
                        logger.debug(f"Malaysia Runner: error parsing card: {e}")
                        continue
                
                if events:
                    break  # Success, stop trying other URLs
                    
            except Exception as e:
                logger.debug(f"Malaysia Runner: failed on {base_url}: {e}")
                continue
        
        # Deduplicate by URL
        seen_urls = set()
        unique_events = []
        for e in events:
            if e['original_url'] not in seen_urls:
                seen_urls.add(e['original_url'])
                unique_events.append(e)
        
        logger.info(f"Malaysia Runner: scraped {len(unique_events)} real events")
        return unique_events
