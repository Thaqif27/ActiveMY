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
        cats = data.get('preferred_categories', [])
        
        # We only want to keep the Title Cased categories, or convert lowercase to Title Case and remove duplicates.
        new_cats = []
        for c in cats:
            title_c = c.title() # "running" -> "Running"
            if title_c not in new_cats:
                new_cats.append(title_c)
                
        if sorted(cats) != sorted(new_cats):
            print(f"Updating {data.get('display_name')} from {cats} to {new_cats}")
            db.collection('users').document(user.id).update({
                'preferred_categories': new_cats
            })
            
    print("Cleanup complete.")
        
except Exception as e:
    print(f"Error: {e}")
