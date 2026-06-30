import logging
logging.basicConfig(level=logging.DEBUG)
from scrapers.ticket2u_scraper import Ticket2UScraper

scraper = Ticket2UScraper()
events = scraper.scrape()
print(f"Scraped {len(events)} events")
if events:
    print(events[0])
