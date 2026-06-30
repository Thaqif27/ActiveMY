import requests
from bs4 import BeautifulSoup

url = "https://sohikers.com/trips"
resp = requests.get(url)
soup = BeautifulSoup(resp.text, 'html.parser')

scripts = soup.find_all('script')
for s in scripts:
    if s.string and ('__NEXT_DATA__' in s.string or '__NUXT__' in s.string):
        print("Found data blob!")
        # Print first 500 chars
        print(s.string[:500])
        import re
        # Find any URLs inside it that look like images
        urls = re.findall(r'https?://[^\s<>"]+?(?:jpg|jpeg|png|webp|gif)', s.string)
        print("Found image URLs:", set(urls))
