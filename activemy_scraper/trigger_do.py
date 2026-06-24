import requests
import sys

print("Triggering DigitalOcean scraper...")
try:
    resp = requests.post("https://goldfish-app-n6w8a.ondigitalocean.app/scrape/all", timeout=120)
    print("Status:", resp.status_code)
    try:
        print("Response:", resp.json())
    except:
        print("Response text:", resp.text)
except Exception as e:
    print(f"Error: {e}")
