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

print("Reverting pending events...")
count = 0
docs = db.collection('events').where('status', '==', 'pending').stream()
for doc in docs:
    db.collection('events').document(doc.id).update({
        'status': firestore.DELETE_FIELD
    })
    count += 1
    print(f"Reverted {doc.id}")

print(f"Reverted {count} events.")
