import requests
import json

api_key = "AIzaSyDrugn_Im_ee0trdZ5cu8kU06r_XjF0BJE"
project_id = "so-hikers-trip-builder"
url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/trips?key={api_key}&pageSize=1"

resp = requests.get(url)
print(json.dumps(resp.json(), indent=2))
