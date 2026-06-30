import requests
import json

api_key = "AIzaSyDrugn_Im_ee0trdZ5cu8kU06r_XjF0BJE"
project_id = "so-hikers-trip-builder"
trip_id = "trip_2d1n_kuala_rompin____20260808_2jbpf"
url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents/trips/{trip_id}?key={api_key}"

resp = requests.get(url)
print(json.dumps(resp.json(), indent=2)[:2000])
print("\nKEYS:")
if 'fields' in resp.json():
    print(resp.json()['fields'].keys())
