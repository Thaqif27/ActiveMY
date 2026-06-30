import os
import base64
import uuid
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, firestore, storage

load_dotenv()
cred = credentials.Certificate(os.getenv('FIREBASE_CREDENTIALS_PATH'))
if not firebase_admin._apps:
    firebase_admin.initialize_app(cred, {'storageBucket': 'activemy-a6bf1.firebasestorage.app'})
db = firestore.client()

def upload_base64_image(b64_str: str) -> str:
    try:
        if ',' not in b64_str:
            return ""
        header, encoded = b64_str.split(",", 1)
        mime_type = header.split(";")[0].replace("data:", "")
        ext = mime_type.split("/")[1] if "/" in mime_type else "jpg"
        
        bucket = storage.bucket()
        blob = bucket.blob(f"scraped_images/{uuid.uuid4()}.{ext}")
        blob.upload_from_string(base64.b64decode(encoded), content_type=mime_type)
        blob.make_public()
        return blob.public_url
    except Exception as e:
        print(f"Failed to upload base64 image: {e}")
        return ""

print("Updating Firestore base64 images for sohikers...")
docs = db.collection('events').where('source', '==', 'sohikers').get()
count = 0
for doc in docs:
    data = doc.to_dict()
    img_url = data.get('image_url', '')
    if img_url.startswith('data:image'):
        title = data.get('title', 'Unknown')
        print(f"Uploading image for {title}")
        new_url = upload_base64_image(img_url)
        if new_url:
            db.collection('events').document(doc.id).update({'image_url': new_url})
            print(f"Updated URL for {title}")
            count += 1

print(f"Fixed {count} base64 images.")
