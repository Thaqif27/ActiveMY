import os
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore

load_dotenv()

try:
    if not firebase_admin._apps:
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH')
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        
    db = firestore.client()
    users = db.collection('users').get()
    
    for user in users:
        data = user.to_dict()
        print(f"User: {data.get('display_name', 'Unknown')}")
        print(f"Categories: {data.get('preferred_categories', [])}")
        print("-" * 20)
        
except Exception as e:
    print(f"Error: {e}")
