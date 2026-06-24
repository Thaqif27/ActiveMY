import firebase_admin
from firebase_admin import credentials, firestore

try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('c:/Users/User/ActiveMY/activemy_scraper/activemy-a6bf1-firebase-adminsdk-fbsvc-2b2f6b5f8a.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()
users = db.collection('users').where('email', '==', 'mrsns987@gmail.com').get()
for user in users:
    print(f"ID: {user.id}")
    print(user.to_dict())
