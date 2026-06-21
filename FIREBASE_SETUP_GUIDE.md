# Firebase Console Setup Guide - Phase 4 & 5

## 🎯 OBJECTIVE
Complete Firestore security rules deployment and create indexes in Firebase Console (15 minutes).

---

## PART 1: DEPLOY FIRESTORE SECURITY RULES (5 minutes)

### Step 1: Open Firebase Console
1. Go to https://console.firebase.google.com/
2. Select your project: **activemy-a6bf1**
3. Left sidebar → Click **Firestore Database**

### Step 2: Navigate to Security Rules
1. Click the **Rules** tab (top of Firestore page)
2. You'll see a text editor with existing rules

### Step 3: Clear & Replace Rules
1. **Select ALL** current text (Ctrl+A)
2. **DELETE** all existing rules
3. **Copy-paste** the security rules below:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isAdmin() {
      return isSignedIn() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    function isUser(uid) {
      return isSignedIn() && request.auth.uid == uid;
    }

    // Events collection - readable by all, writable by admin
    match /events/{eventId} {
      allow read: if isSignedIn();
      allow create, update, delete: if isAdmin();
    }

    // Users collection - user can read/write own, admin can read all
    match /users/{userId} {
      allow read, write: if isUser(userId);
      allow read: if isAdmin();
    }

    // User behavior tracking - user can write own, admin can read all
    match /user_behavior/{docId} {
      allow create: if isSignedIn() && request.resource.data.uid == request.auth.uid;
      allow read: if isAdmin();
    }

    // Notifications - user can read own, admin can write to any
    match /notifications/{notificationId} {
      allow read: if isSignedIn() && resource.data.uid == request.auth.uid;
      allow create, update, delete: if isAdmin();
    }

    // Allow signed-in users to access any collection for authorized reads
    match /{document=**} {
      allow read: if isSignedIn() && (
        resource.data.uid == request.auth.uid ||
        exists(/databases/$(database)/documents/users/$(request.auth.uid)) && 
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin'
      );
    }
  }
}
```

### Step 4: Publish Rules
1. Click **Publish** button (blue button)
2. Confirm in the dialog
3. Wait for confirmation message: "Rules published successfully"

---

## PART 2: CREATE FIRESTORE INDEXES (10 minutes)

### Index 1: Events by Category, Date, and Active Status
1. Go to **Firestore → Indexes** tab
2. Click **Create Index**
3. Collection: **events**
4. Fields to index:
   - Field 1: **category** (Ascending)
   - Field 2: **date** (Descending)
   - Field 3: **is_active** (Ascending)
5. Click **Create Index**
6. **Wait for build** (~5-10 minutes)

### Index 2: Events by Active Status and Date
1. Click **Create Index** again
2. Collection: **events**
3. Fields to index:
   - Field 1: **is_active** (Ascending)
   - Field 2: **date** (Descending)
4. Click **Create Index**
5. **Wait for build** (~5-10 minutes)

### Index 3: User Behavior by User ID and Timestamp
1. Click **Create Index** again
2. Collection: **user_behavior**
3. Fields to index:
   - Field 1: **uid** (Ascending)
   - Field 2: **timestamp** (Descending)
4. Click **Create Index**
5. **Wait for build** (~5-10 minutes)

### Index 4: Notifications by User ID, Status, and Timestamp
1. Click **Create Index** again
2. Collection: **notifications**
3. Fields to index:
   - Field 1: **uid** (Ascending)
   - Field 2: **is_read** (Ascending)
   - Field 3: **sent_at** (Descending)
4. Click **Create Index**
5. **Wait for build** (~5-10 minutes)

### Check Index Status
- Go to **Firestore → Indexes** tab
- You should see all 4 indexes listed
- Status should show "Enabled" when ready

---

## PART 3: GET FIREBASE CREDENTIALS

### Get Android Firebase Config
1. Go to **Firebase Console → Project Settings** (⚙️ icon, top right)
2. Click **Your apps** section
3. Select **Android** app (activemy)
4. Copy the `google-services.json` file content
5. Verify it's in: `activemy_flutter/android/app/google-services.json`

### Test Firestore Connection
1. Open `activemy_flutter`
2. Run:
```bash
flutter clean
flutter pub get
```
3. If no errors, Firestore is connected ✅

---

## PART 4: VERIFY RULES WITH RULES SIMULATOR (Optional but Recommended)

### Test Write Permission (Should Fail)
1. In Firebase Console, Firestore → Rules tab
2. Scroll down to **Rules Simulator** section
3. Click **Simulate read/write** button

#### Test Case 1: Unauthorized Write
- Request type: **Write**
- Document path: `events/test-event`
- Authenticated as: **[Leave blank - unauthenticated]**
- Click **Run**
- Result: **Should DENY** ✅

#### Test Case 2: Admin Read
- Request type: **Read**
- Document path: `users/admin-uid`
- Authenticated as: **admin-uid**
- User data: 
```json
{
  "role": "admin",
  "email": "admin@example.com"
}
```
- Click **Run**
- Result: **Should ALLOW** ✅

---

## CHECKLIST ✅

- [ ] Firestore security rules deployed
- [ ] 4 indexes created and building
- [ ] Indexes showing as "Enabled" in console
- [ ] Flutter app still compiles without errors
- [ ] firebase_options.dart has Android config

---

## TROUBLESHOOTING

### Issue: "Rules Simulator shows DENY when it should ALLOW"
**Solution**: Verify user role in Firestore. Go to `users/{uid}` document and check `role` field equals "admin"

### Issue: "Indexes stuck on 'Building'"
**Solution**: Normal behavior. Can take 5-10 minutes. Refresh page after 5 minutes.

### Issue: "Firestore rules rejected all writes"
**Solution**: Check if your auth user exists in `users/` collection with proper `role` field

---

## NEXT STEPS

After completing:
1. ✅ Security rules deployed
2. ✅ Indexes created
3. ✅ Move to **Phase 5: API Setup**
   - [ ] Set GOOGLE_GEMINI_API_KEY
   - [ ] Configure FCM
   - [ ] Test notifications

---

**Time Remaining: ~30 minutes** (for API setup)
