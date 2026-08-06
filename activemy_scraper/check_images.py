import main
db = main.db
docs = db.collection('events').stream()
for d in docs:
    data = d.to_dict()
    if 'Goceli' in data.get('title', '') or 'Ora Et Labora' in data.get('title', '') or 'Canada Hill' in data.get('title', ''):
        print(f"Title: {data.get('title')}")
        print(f"Image: {data.get('image_url')}")
        print(f"Source: {data.get('source')}")
        print("---")
