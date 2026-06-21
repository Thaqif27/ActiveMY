# DATABASE & FIRESTORE SETUP GUIDE

## ✅ Current Status

### **Firestore Collections** ✅ READY
All collections are configured in the app and scraper:

```
Firestore Database (activemy-a6bf1)
├── events/              ✅ Active events from scrapers
│   ├── id (auto)
│   ├── title
│   ├── description
│   ├── category (running/cycling/hiking)
│   ├── date (timestamp)
│   ├── location (string address)
│   ├── lat (number)
│   ├── lng (number)
│   ├── source (jomrun/ticket2u/racexasia/malaysiarunner)
│   ├── original_url
│   ├── image_url
│   ├── price (string)
│   ├── scraped_at (timestamp)
│   ├── is_active (boolean)
│   └── created_at (timestamp)
│
├── users/               ✅ User profiles & preferences
│   ├── uid (email)
│   ├── email
│   ├── display_name
│   ├── role (user/admin)
│   ├── preferred_categories (array: running/cycling/hiking)
│   ├── preferred_radius_km (number, default: 50)
│   ├── fcm_token (string)
│   ├── created_at (timestamp)
│   └── updated_at (timestamp)
│
├── user_behavior/       ✅ Track user interactions
│   ├── uid
│   ├── event_id
│   ├── action (view/save/click_url)
│   ├── category
│   └── timestamp
│
└── notifications/       ✅ Push notification logs
    ├── uid
    ├── title
    ├── body
    ├── event_id (optional)
    ├── sent_at (timestamp)
    ├── is_read (boolean)
    └── type (recommendation/update/alert)
```

---

## 🔒 Security Rules Setup

### **Current Security Rules Status**: ⚠️ NEED TO CONFIGURE

Create these Firestore Security Rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============ USERS COLLECTION ============
    match /users/{uid} {
      // Users can read their own profile
      allow read: if request.auth.uid == uid;
      
      // Users can update their own preferences
      allow update: if request.auth.uid == uid && 
        request.resource.data.role == resource.data.role; // Prevent role escalation
      
      // Admin can read all users
      allow read: if isAdmin(uid);
      
      // Admin can update user roles
      allow update: if isAdmin(request.auth.uid);
    }
    
    // ============ EVENTS COLLECTION ============
    match /events/{eventId} {
      // Anyone can read active events
      allow read: if resource.data.is_active == true;
      
      // Only scraper (service account) can write events
      allow write: if isScraperAccount();
      
      // Admin can update event status
      allow update: if isAdmin(request.auth.uid);
    }
    
    // ============ USER BEHAVIOR COLLECTION ============
    match /user_behavior/{docId} {
      // Users can create their own behavior records
      allow create: if request.auth.uid == request.resource.data.uid;
      
      // Users can read their own behavior
      allow read: if request.auth.uid == resource.data.uid;
      
      // Admin can read all behavior data (analytics)
      allow read: if isAdmin(request.auth.uid);
    }
    
    // ============ NOTIFICATIONS COLLECTION ============
    match /notifications/{notifId} {
      // Users can read their own notifications
      allow read: if request.auth.uid == resource.data.uid;
      
      // Users can update read status of their notifications
      allow update: if request.auth.uid == resource.data.uid &&
        only(['is_read'], request.resource.data.diff(resource.data).affectedKeys());
      
      // Only FCM service can write notifications
      allow write: if isScraperAccount();
    }
    
    // ============ SCRAPER LOGS COLLECTION ============
    match /scraper_logs/{logId} {
      // Admin can read logs
      allow read: if isAdmin(request.auth.uid);
      // Scraper backend writes using Admin SDK (bypasses rules)
    }
    
    // ============ SETTINGS COLLECTION ============
    match /settings/{docId} {
      // Admin can read and update settings
      allow read, write: if isAdmin(request.auth.uid);
    }
    
    // ============ HELPER FUNCTIONS ============
    function isAdmin(uid) {
      return get(/databases/$(database)/documents/users/$(uid)).data.role == 'admin';
    }
    
    function isScraperAccount() {
      // Only service account from scraper backend
      return request.auth.token.firebase.identities['service-account'] != null;
    }
    
    function only(fields, diff) {
      return diff.affectedKeys().hasOnly(fields);
    }
  }
}
```

### **Setup Instructions:**
1. Go to **Firebase Console** → **activemy-a6bf1**
2. Navigate to **Firestore Database** → **Rules**
3. Click **Edit Rules**
4. Replace with the rules above
5. Click **Publish**

---

## 📍 Firestore Indexes for Geo-Queries

### **Current Status**: ⚠️ INDEXES NEED CONFIGURATION

Create these composite indexes in Firebase Console:

#### **Index 1: Events by Category & Date**
```
Collection: events
Fields:
  1. category (Ascending)
  2. date (Ascending)
  3. is_active (Ascending)
```

**Setup:**
1. Firestore Dashboard → **Indexes** tab
2. Click **Create Index**
3. Collection: `events`
4. Fields: `category` (Asc), `date` (Asc), `is_active` (Asc)
5. Create

#### **Index 2: Events by Status & Date**
```
Collection: events
Fields:
  1. is_active (Ascending)
  2. date (Ascending)
```

#### **Index 3: User Behavior Analytics**
```
Collection: user_behavior
Fields:
  1. uid (Ascending)
  2. timestamp (Descending)
```

#### **Index 4: Notifications by User**
```
Collection: notifications
Fields:
  1. uid (Ascending)
  2. sent_at (Descending)
  3. is_read (Ascending)
```

### **Why Geo-Queries Are Disabled:**
- `geoflutterfire_plus` package has compatibility issues
- **Better Approach**: Use Firestore filtering with `lat` & `lng` fields
- Can implement bounding box queries for location filtering

**Alternative Geo-Query Implementation:**
```dart
// Instead of using GeoFlutterFirePlus
Stream<List<EventModel>> streamNearbyEvents({
  required double lat,
  required double lng,
  required double radiusKm,
}) {
  // Use Firestore document snapshots and filter client-side
  return _events
    .where('is_active', isEqualTo: true)
    .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
    .snapshots()
    .map((snapshot) {
      return snapshot.docs
        .map((doc) => EventModel.fromFirestore(doc))
        .where((event) {
          // Haversine distance calculation
          return _distanceBetween(lat, lng, event.lat, event.lng) <= radiusKm;
        })
        .toList();
    });
}

double _distanceBetween(double lat1, double lng1, double lat2, double lng2) {
  // Haversine formula implementation
  // Returns distance in kilometers
}
```

---

## 🔧 Firestore Setup Checklist

- [ ] Create/verify `events` collection
- [ ] Create/verify `users` collection
- [ ] Create/verify `user_behavior` collection
- [ ] Create/verify `notifications` collection
- [ ] Copy & paste security rules from above
- [ ] Publish security rules
- [ ] Create Index 1 (category, date, is_active)
- [ ] Create Index 2 (is_active, date)
- [ ] Create Index 3 (user_behavior: uid, timestamp)
- [ ] Create Index 4 (notifications: uid, sent_at, is_read)
- [ ] Test write permissions with scraper
- [ ] Test read permissions from Flutter app
- [ ] Verify Firebase Console shows no permission errors

---

## 📊 Sample Firestore Documents

### **Sample Event Document**
```json
{
  "id": "evt_123456",
  "title": "KL Marathon 2026",
  "description": "Annual marathon in Kuala Lumpur",
  "category": "running",
  "date": "2026-09-15T06:00:00Z",
  "location": "Kuala Lumpur, Malaysia",
  "lat": 3.1390,
  "lng": 101.6869,
  "source": "ticket2u",
  "original_url": "https://ticket2u.com.my/event/kl-marathon-2026",
  "image_url": "https://...",
  "price": "RM 120",
  "scraped_at": "2026-06-02T15:30:00Z",
  "is_active": true,
  "created_at": "2026-06-02T15:30:00Z"
}
```

### **Sample User Document**
```json
{
  "uid": "user_abc123",
  "email": "john@example.com",
  "display_name": "John Doe",
  "role": "user",
  "preferred_categories": ["running", "cycling"],
  "preferred_radius_km": 50,
  "fcm_token": "eO7...xyz",
  "created_at": "2026-05-01T10:00:00Z",
  "updated_at": "2026-06-02T14:30:00Z"
}
```

### **Sample Notification Document**
```json
{
  "uid": "user_abc123",
  "title": "New Event Near You!",
  "body": "KL Cycling Club Meetup starting in 3 hours",
  "event_id": "evt_123456",
  "sent_at": "2026-06-02T15:30:00Z",
  "is_read": false,
  "type": "recommendation"
}
```

---

## 🚀 Next: Enable Firestore Features

After setting up security rules and indexes:

1. **Enable Cloud Functions** (optional) for automated triggers
2. **Configure Backups** for data protection
3. **Set up Firestore Monitoring** for performance tracking
4. **Test with sample data** from scraper

---

## 📝 Notes

- All timestamps use UTC
- Firestore automatically creates collections on first write
- Indexes take 5-10 minutes to build
- Security rules apply immediately upon publish
- Test rules in "Simulator" tab before publishing
