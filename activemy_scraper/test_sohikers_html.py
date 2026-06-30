import requests
from bs4 import BeautifulSoup

url = "https://sohikers.com/trip/?id=trip_2d1n_kuala_rompin____20260808_2jbpf"
resp = requests.get(url)
soup = BeautifulSoup(resp.text, 'html.parser')

images = soup.find_all('img')
for img in images:
    print(img.get('src'))
    
meta_imgs = soup.find_all('meta', property="og:image")
for m in meta_imgs:
    print("OG:", m.get('content'))
