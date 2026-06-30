import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
cred = credentials.Certificate(cred_path)
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)
db = firestore.client()

print("Patching events...")
count = 0
docs = db.collection('events').stream()
for doc in docs:
    data = doc.to_dict()
    if 'status' not in data or data['status'] is None:
        db.collection('events').document(doc.id).update({'status': 'pending'})
        count += 1
        print(f"Patched {data.get('title')}")

print(f"Patched {count} events.")
