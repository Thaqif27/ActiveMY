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

docs = db.collection('scraper_logs').order_by('timestamp', direction=firestore.Query.DESCENDING).limit(5).stream()
for doc in docs:
    print(doc.to_dict())
