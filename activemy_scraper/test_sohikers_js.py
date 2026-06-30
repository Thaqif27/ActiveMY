import requests
from bs4 import BeautifulSoup
import re

url = "https://sohikers.com/trips"
resp = requests.get(url)
soup = BeautifulSoup(resp.text, 'html.parser')

scripts = soup.find_all('script')
js_urls = [s.get('src') for s in scripts if s.get('src')]

for js_url in js_urls:
    if not js_url.startswith('http'):
        js_url = "https://sohikers.com" + js_url
    print(f"Fetching {js_url}...")
    js_resp = requests.get(js_url)
    
    # Search for how storageKey is used
    matches = re.findall(r'.{0,50}storageKey.{0,50}', js_resp.text)
    if matches:
        print("Found storageKey logic:")
        for m in set(matches):
            print(m)
