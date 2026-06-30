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

docs = db.collection('events').where('status', '==', 'pending').limit(10).stream()
print("Pending events:")
count = 0
for doc in docs:
    data = doc.to_dict()
    count += 1
    print(f"Title: {data.get('title')}, Source: {data.get('source')}")
print(f"Total shown: {count}")
