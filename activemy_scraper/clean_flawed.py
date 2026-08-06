import main

db = main.db
docs = db.collection('events').stream()
deleted = 0

for d in docs:
    data = d.to_dict()
    src = data.get('source', '')
    lat = data.get('lat', 0.0)
    
    if lat == 0.0 or 'singapore' in src.lower() or 'singapore' in data.get('location', '').lower() or 'singapore' in data.get('title', '').lower():
        db.collection('events').document(d.id).delete()
        deleted += 1
        print(f"Deleted: {data.get('title')} (Lat: {lat})")

print(f"Total deleted: {deleted}")
