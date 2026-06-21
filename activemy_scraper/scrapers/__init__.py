"""ActiveMY Scrapers Package"""
from .jomrun_scraper import JomRunScraper
from .racexasia_scraper import RaceXasiaScraper
from .ticket2u_scraper import Ticket2UScraper
from .malaysiarunner_scraper import MalaysiaRunnerScraper

__all__ = [
    'JomRunScraper',
    'RaceXasiaScraper',
    'Ticket2UScraper',
    'MalaysiaRunnerScraper'
]