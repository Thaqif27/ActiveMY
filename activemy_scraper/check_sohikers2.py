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

docs = db.collection('events').where('source', '==', 'So Hikers').limit(10).stream()
for doc in docs:
    data = doc.to_dict()
    print(f"Title: {data.get('title')}, Status: {data.get('status')}")
