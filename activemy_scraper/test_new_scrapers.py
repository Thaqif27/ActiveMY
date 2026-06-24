import sys
import os
import json

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from scrapers.malaysiacyclist_scraper import MalaysiaCyclistScraper
from scrapers.sohikers_scraper import SoHikersScraper

def test_scrapers():
    print("Testing MalaysiaCyclist Scraper...")
    mc_scraper = MalaysiaCyclistScraper()
    mc_events = mc_scraper.scrape()
    print(f"Found {len(mc_events)} events.")
    if mc_events:
        print(json.dumps(mc_events[0], indent=2))
        
    print("\n" + "="*50 + "\n")
    
    print("Testing SoHikers Scraper...")
    sh_scraper = SoHikersScraper()
    sh_events = sh_scraper.scrape()
    print(f"Found {len(sh_events)} events.")
    if sh_events:
        print(json.dumps(sh_events[0], indent=2))

if __name__ == "__main__":
    test_scrapers()
