# Phase 5: FCM & Gemini AI Setup Guide

## 🎯 OBJECTIVE
Setup Firebase Cloud Messaging (FCM) and Google Gemini API for notifications and AI recommendations (15 minutes).

---

## PART 1: GET GOOGLE GEMINI API KEY (5 minutes)

### Step 1: Create Google Cloud Account
1. Go to https://cloud.google.com/console
2. Sign in with your Google account
3. Click **Create Project**
4. Name: **activemy-gemini**
5. Click **Create**
6. Wait for project to initialize (~30 seconds)

### Step 2: Enable Generative AI API
1. Search for **Generative Language API** in the search bar
2. Click the result
3. Click **Enable**
4. Wait for API to enable (~10 seconds)

### Step 3: Create API Key
1. Go to **Credentials** (left sidebar)
2. Click **Create Credentials** → **API Key**
3. Copy the API key
4. **Save it somewhere safe** - you'll need it

### Step 4: Restrict API Key (Security Best Practice)
1. Click on your newly created API key
2. Under **API restrictions**:
   - Select **Restrict key**
   - Choose **Generative Language API**
   - Click **Save**

---

## PART 2: SET ENVIRONMENT VARIABLES

### Option 1: Windows (PowerShell)
```powershell
# Set environment variable
[Environment]::SetEnvironmentVariable("GOOGLE_GEMINI_API_KEY", "YOUR_API_KEY_HERE", "User")

# Verify
$env:GOOGLE_GEMINI_API_KEY
```

### Option 2: Windows (Command Prompt)
```cmd
setx GOOGLE_GEMINI_API_KEY "YOUR_API_KEY_HERE"
```

### Option 3: Flutter Build Command
```bash
cd activemy_flutter
flutter run -d <device_id> --dart-define=GOOGLE_GEMINI_API_KEY=YOUR_API_KEY_HERE
```

### Option 4: iOS/Android Build
Add to `activemy_flutter/android/local.properties`:
```
flutter.defines=GOOGLE_GEMINI_API_KEY=YOUR_API_KEY_HERE
```

**Choose ONE option above based on your environment.**

---

## PART 3: SETUP FIREBASE CLOUD MESSAGING (FCM) (5 minutes)

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com/
2. Select project: **activemy-a6bf1**

### Step 2: Get FCM Server Key
1. Click **⚙️ (Settings)** icon → **Project Settings**
2. Click **Cloud Messaging** tab
3. Under "Server API Key", copy the key (labeled as "Server key")
4. Save this - you'll need it for backend notifications

### Step 3: Verify Android Configuration
1. Go to **Project Settings** → **Your apps** → Select **Android app**
2. Download `google-services.json` (if not already done)
3. Verify it's in: `activemy_flutter/android/app/google-services.json`

### Step 4: Check FCM Initialization in Code
Your Flutter app already has FCM configured in:
- `lib/services/fcm_service.dart` ✅
- `lib/main.dart` (FCM initialization) ✅

No additional code changes needed for basic FCM!

---

## PART 4: CONFIGURE NOTIFICATION TOPICS (Optional but Recommended)

### Test Topic Subscriptions
After running the app, verify users are subscribed to topics:

1. **Open Firebase Console** → **Cloud Messaging**
2. Click **Send message** button
3. Enter:
   - **Notification title**: "Test Running Event"
   - **Notification body**: "Great 5K near you!"
   - **Topic name**: `running` (or `cycling`/`hiking`)
   - Click **Send**

4. **On your Android device**:
   - You should see a notification pop-up
   - Tap to view the event recommendation

### Test Single User Notification
1. **In Firebase Console** → **Cloud Messaging**
2. Click **Send message**
3. Instead of "Topic", select **FCM registration token**
4. Copy a user's FCM token from Firestore `users/{uid}/fcm_token`
5. Paste it and send
6. Verify notification arrives on that specific user's device

---

## PART 5: TEST GEMINI API INTEGRATION

### Test 1: Verify API Key Setup
Run this command to test if API key is set:
```bash
cd activemy_flutter
flutter run --dart-define=GOOGLE_GEMINI_API_KEY=YOUR_API_KEY_HERE
```

### Test 2: Force Recommendations Load
1. Launch app on Android device
2. Go to **Home Screen**
3. Scroll to **"Recommended for You"** section
4. You should see 5 event recommendations
5. Check app logs:
```bash
flutter logs | grep "RecommendationService"
```

### Test 3: Test API Call Directly (Optional)
```bash
curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "contents": [{
      "parts": [{
        "text": "Recommend 3 events for a runner interested in marathons"
      }]
    }]
  }'
```

Expected response: Should return AI-generated text

---

## PART 6: BACKEND SETUP (Python Scraper) - Optional

### If Using Gemini API for Backend Recommendations

1. Update `activemy_scraper/requirements.txt`:
```
google-generativeai==0.3.0
```

2. Install dependency:
```bash
cd activemy_scraper
pip install -r requirements.txt
```

3. Update backend to use Gemini API (example in `main.py`):
```python
import google.generativeai as genai

genai.configure(api_key=os.getenv('GOOGLE_GEMINI_API_KEY'))
model = genai.GenerativeModel('gemini-1.5-flash')

response = model.generate_content(prompt)
```

---

## PART 7: SEND TEST NOTIFICATION FROM FLUTTER

### Add Test Notification Button (In your app)
The app already has notification sending capability through:
- `lib/services/fcm_service.dart` handles receiving
- Admin panel can trigger manual notifications

### To Manually Send Notification:
1. Go to **Admin Dashboard** (if you're admin)
2. (Optional: Add a "Send Test Notification" button to admin panel)
3. Or use Firebase Console → Cloud Messaging

---

## VERIFICATION CHECKLIST ✅

- [ ] Google Gemini API key created and restricted
- [ ] API key set as environment variable `GOOGLE_GEMINI_API_KEY`
- [ ] FCM Server Key obtained from Firebase Console
- [ ] `google-services.json` in `android/app/`
- [ ] Flutter app compiles without errors
- [ ] App can fetch recommendations on home screen
- [ ] Topic subscriptions working (running/cycling/hiking)
- [ ] Test notification received on device
- [ ] Admin can send notifications via Firebase Console

---

## TROUBLESHOOTING

### Issue: "Gemini API Key is empty" or Recommendations not loading
**Solution**:
```bash
# Verify env variable is set
echo $env:GOOGLE_GEMINI_API_KEY  # Windows PowerShell
echo $GOOGLE_GEMINI_API_KEY      # Mac/Linux

# Or rebuild with --dart-define
flutter clean
flutter pub get
flutter run --dart-define=GOOGLE_GEMINI_API_KEY=YOUR_KEY
```

### Issue: "Invalid API key" error in logs
**Solution**:
1. Verify API key is correct (copy from Google Cloud Console)
2. Verify API key has Generative Language API enabled
3. Try regenerating a new API key

### Issue: "FCM registration token is null"
**Solution**:
1. Check Firebase is initialized: `firebase_core` package
2. Check Android permissions (already in `AndroidManifest.xml`)
3. Try reinstalling app: `flutter clean && flutter pub get`

### Issue: "Notifications not showing on device"
**Solution**:
1. Check if app has permission: Settings → Apps → ActiveMY → Notifications → Enable
2. Check notification channel: Already created as "activemy_channel"
3. Check if device is in "Do Not Disturb" mode

---

## CREDENTIALS SUMMARY

| Item | Value | Status |
|------|-------|--------|
| **Gemini API Key** | `sk-...` | ✅ Set as `GOOGLE_GEMINI_API_KEY` |
| **FCM Server Key** | From Firebase Console | ✅ Saved in notes |
| **Firebase Project** | activemy-a6bf1 | ✅ Connected |
| **Android Package** | com.example.activemy | ✅ In android/app/build.gradle |

---

## NEXT STEPS

After completing:
1. ✅ Gemini API key configured
2. ✅ FCM Server Key obtained
3. ✅ Notifications tested
4. **Proceed to**: Build APK and test on real device

```bash
cd activemy_flutter
flutter clean
flutter pub get
flutter build apk --release --dart-define=GOOGLE_GEMINI_API_KEY=YOUR_KEY
```

Generated APK will be at:
```
build/app/outputs/apk/release/app-release.apk
```

---

**Time Remaining: Testing Phase** ⏱️
