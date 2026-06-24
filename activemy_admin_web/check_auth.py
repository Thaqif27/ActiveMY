import firebase_admin
from firebase_admin import credentials, auth

try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('c:/Users/User/ActiveMY/activemy_scraper/activemy-a6bf1-firebase-adminsdk-fbsvc-2b2f6b5f8a.json')
    firebase_admin.initialize_app(cred)

user = auth.get_user_by_email('mrsns987@gmail.com')
print(f"UID: {user.uid}")
print(f"Provider Data: {[p.provider_id for p in user.provider_data]}")
