import requests
from bs4 import BeautifulSoup

url = "https://www.ticket2u.com.my/event/36000/kuala-lumpur-standard-chartered-marathon-2024"
headers = {'User-Agent': 'Mozilla/5.0'}
try:
    resp = requests.get(url, headers=headers, timeout=10)
    soup = BeautifulSoup(resp.content, 'html.parser')

    print("Title:", soup.title.string if soup.title else "N/A")

    venue_elem = soup.select_one('#eventVenue')
    if venue_elem:
        print("Venue ID:", venue_elem.get_text(" ", strip=True))

    print("Addresses:")
    for addr in soup.find_all('address'):
        print("-", addr.get_text(" ", strip=True))

    desc = soup.select_one('.event-description') or soup.select_one('#eventDescription') or soup.select_one('.description-content')
    if desc:
        print("Description:", desc.get_text(" ", strip=True)[:150])
except Exception as e:
    print("Error:", e)
