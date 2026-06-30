import requests

api_key = "AIzaSyDrugn_Im_ee0trdZ5cu8kU06r_XjF0BJE"
project_id = "so-hikers-trip-builder"
url = f"https://firestore.googleapis.com/v1/projects/{project_id}/databases/(default)/documents:runQuery?key={api_key}"

payload = {
    "structuredQuery": {
        "from": [{"collectionId": "trips"}],
        "select": {
            "fields": [
                {"fieldPath": "tripName"},
                {"fieldPath": "storageKey"}
            ]
        },
        "limit": 5
    }
}

resp = requests.post(url, json=payload)
print(resp.json())
