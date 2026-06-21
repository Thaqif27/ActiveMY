import logging
import re
import concurrent.futures
from datetime import datetime, date, timedelta
from typing import List, Dict, Optional
from playwright.sync_api import sync_playwright
from .utils import categorize_event

logger = logging.getLogger(__name__)

class Ticket2UScraper:
    def __init__(self):
        self.today = date.today()

    def _parse_date(self, date_str: str) -> Optional[datetime]:
        if not date_str:
            return None
        date_str = date_str.replace('Date:', '').strip()
        try:
            return datetime.fromisoformat(date_str.replace('Z', '+00:00').split('T')[0])
        except:
            for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d %B %Y', '%B %d, %Y', '%d %b %Y', '%b %d, %Y'):
                try:
                    return datetime.strptime(date_str, fmt)
                except:
                    continue
            
            # Ticket2U formats like 'Jul 1 Wed' or 'Sep 26 Sat'
            try:
                m = re.match(r'([A-Za-z]{3})\s+(\d{1,2})', date_str)
                if m:
                    d_str = f"{m.group(2)} {m.group(1)} {self.today.year}"
                    d = datetime.strptime(d_str, '%d %b %Y')
                    if d.date() < self.today:
                        d = datetime.strptime(f"{m.group(2)} {m.group(1)} {self.today.year + 1}", '%d %b %Y')
                    return d
            except:
                pass
        return None

    def _fetch_with_playwright(self, url: str) -> str:
        """Fetch page content using Playwright for JavaScript rendering"""
        def _run():
            with sync_playwright() as p:
                browser = p.chromium.launch(headless=True)
                page = browser.new_page()
                page.goto(url, wait_until="networkidle", timeout=60000)
                
                # Scroll down slowly to trigger all lazy loaded images
                for i in range(5):
                    page.evaluate(f"window.scrollTo(0, document.body.scrollHeight * {(i+1)/5});")
                    page.wait_for_timeout(1000)
                    
                content = page.content()
                browser.close()
                return content
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            return pool.submit(_run).result()

    def scrape(self) -> List[Dict]:
        """Scrape Ticket2U Sports events"""
        events = []
        
        # Ticket2U sports category URL
        url = "https://www.ticket2u.com.my/event/list/?cc=sport"
        
        try:
            logger.debug(f"Ticket2U: fetching {url} with Playwright")
            html = self._fetch_with_playwright(url)
            
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(html, 'html.parser')
            
            # Find all event cards in the rendered DOM
            cards = soup.select('figure.fig')
            logger.debug(f"Ticket2U: found {len(cards)} event cards after rendering")
            
            for card in cards:
                try:
                    title_elem = card.select_one('h3 a')
                    if not title_elem:
                        continue
                    
                    title = title_elem.get_text(strip=True)
                    if not title or len(title) < 3 or '{{' in title:
                        continue
                        
                    href = title_elem.get('href', '')
                    if not href:
                        continue
                    
                    # Image URL
                    image_url = ''
                    img_bg = card.select_one('.fig__image-bg')
                    if img_bg:
                        style = img_bg.get('style', '')
                        m = re.search(r'url\([\'"]?(.*?)[\'"]?\)', style)
                        if m:
                            image_url = m.group(1)
                            
                        # If still no image url, try fallback to img tag
                        if not image_url:
                            img = card.select_one('img')
                            if img:
                                image_url = img.get('src', '')

                    if image_url and not image_url.startswith('http'):
                        if image_url.startswith('//'):
                            image_url = 'https:' + image_url
                        else:
                            image_url = 'https://www.ticket2u.com.my' + ('' if image_url.startswith('/') else '/') + image_url

                    # Extract Date
                    date_text = ''
                    calendar = card.select_one('.fig__calendar')
                    if calendar:
                        date_text = calendar.get_text(" ", strip=True)
                    else:
                        time_elem = card.select_one('time')
                        if time_elem:
                            date_text = time_elem.get_text(strip=True)
                            
                    event_date = self._parse_date(date_text) if date_text else None
                    if not event_date:
                        # Try finding a year in the title to help parser, or fallback
                        logger.debug(f"Ticket2U: no date for '{title}', skipping")
                        continue
                        
                    if event_date.date() < self.today:
                        continue
                        
                    # Extract Location
                    location = 'Malaysia'
                    addr = card.select_one('address.fig__pre') or card.select_one('address.fig__meta')
                    if addr:
                        location = addr.get_text(strip=True)
                        
                    # Extract Price
                    price = 'Free'
                    price_meta = card.select_one('.fig__price')
                    if price_meta:
                        price = price_meta.get_text(strip=True)
                        
                    # Get full URL
                    url_val = href
                    if not url_val.startswith('http'):
                        url_val = 'https://www.ticket2u.com.my' + url_val
                        
                    is_virtual = 'virtual' in title.lower() or 'virtual' in location.lower()
                    
                    events.append({
                        'title': title[:200],
                        'description': '',
                        'category': categorize_event(title),
                        'date': event_date.isoformat(),
                        'location': location,
                        'image_url': image_url,
                        'original_url': url_val,
                        'price': price,
                        'source': 'ticket2u',
                        'is_virtual': is_virtual
                    })
                    
                except Exception as e:
                    logger.debug(f"Ticket2U: error parsing card: {e}")
                    continue
            
            logger.info(f"Ticket2U: scraped {len(events)} real events")
            
        except Exception as e:
            logger.error(f"Ticket2U error: {e}")
        
        return events
