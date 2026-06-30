import sys
import os
import asyncio
from scrapers.sohikers_scraper import SoHikersScraper
from main import upload_to_firestore

async def main():
    scraper = SoHikersScraper()
    print("Scraping So Hikers...")
    events = scraper.scrape()
    print(f"Scraped {len(events)} events.")
    
    print("Saving to Firebase...")
    uploaded, newly = await upload_to_firestore(events, "sohikers")
    print(f"Uploaded {uploaded} events. New events: {len(newly)}")

if __name__ == "__main__":
    asyncio.run(main())
