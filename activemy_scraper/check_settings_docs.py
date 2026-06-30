import firebase_admin
from firebase_admin import credentials, firestore
import os
from dotenv import load_dotenv

load_dotenv()
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
cred = credentials.Certificate(cred_path)
firebase_admin.initialize_app(cred)

db = firestore.client()
docs = db.collection('settings').stream()
print("Settings documents:")
for doc in docs:
    print(f"ID: {doc.id} => {doc.to_dict()}")
