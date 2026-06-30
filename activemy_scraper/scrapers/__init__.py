"""ActiveMY Scrapers Package"""
from .jomrun_scraper import JomRunScraper
from .ticket2u_scraper import Ticket2UScraper
from .malaysiacyclist_scraper import MalaysiaCyclistScraper
from .sohikers_scraper import SoHikersScraper

__all__ = [
    'JomRunScraper',
    'Ticket2UScraper',
    'MalaysiaCyclistScraper',
    'SoHikersScraper'
]