# Quick Setup Checklist - Phase 4 & 5 (30 Minutes Total)

## ⏱️ Phase 4: Firestore Setup (15 minutes)

### Step 1: Deploy Security Rules (5 minutes)
```
1. Firebase Console → activemy-a6bf1 → Firestore → Rules tab
2. Clear existing rules (Ctrl+A, Delete)
3. Copy-paste new rules from FIREBASE_SETUP_GUIDE.md
4. Click "Publish"
5. Wait for confirmation ✅
```

### Step 2: Create 4 Indexes (10 minutes - automated, you wait)
```
1. Firebase Console → Firestore → Indexes tab
2. Click "Create Index" (4 times total)

Index 1: events (category↑, date↓, is_active↑)
Index 2: events (is_active↑, date↓)
Index 3: user_behavior (uid↑, timestamp↓)
Index 4: notifications (uid↑, is_read↑, sent_at↓)

3. Each takes ~2-5 minutes to build
4. Status will show "Enabled" when ready ✅
```

---

## ⏱️ Phase 5: Gemini AI + FCM Setup (15 minutes)

### Step 1: Get Gemini API Key (5 minutes)
```
1. Google Cloud Console (cloud.google.com/console)
2. Create new project: "activemy-gemini"
3. Search for "Generative Language API" → Enable
4. Go to Credentials → Create API Key
5. Copy the key
6. Restrict to "Generative Language API" only (security)
```

### Step 2: Set Environment Variable (2 minutes)
```powershell
# Windows PowerShell (as Administrator)
[Environment]::SetEnvironmentVariable("GOOGLE_GEMINI_API_KEY", "YOUR_KEY_HERE", "User")

# Verify
$env:GOOGLE_GEMINI_API_KEY
```

### Step 3: Get FCM Server Key (3 minutes)
```
1. Firebase Console → activemy-a6bf1 → Settings (⚙️) → Project Settings
2. Cloud Messaging tab
3. Copy "Server API Key"
4. Save for later (optional - for backend use)
```

### Step 4: Test Everything (5 minutes)
```bash
cd activemy_flutter
flutter clean
flutter pub get
flutter analyze  # Should show: No issues found!
```

---

## ✅ VERIFICATION CHECKLIST

| Task | Status | Time |
|------|--------|------|
| ✅ Security rules deployed | [ ] | 5 min |
| ✅ 4 indexes created | [ ] | 10 min |
| ✅ Gemini API key obtained | [ ] | 5 min |
| ✅ API key set as env var | [ ] | 2 min |
| ✅ FCM Server Key obtained | [ ] | 3 min |
| ✅ App compiles (flutter analyze) | [ ] | 2 min |

**Total Time: ~30-35 minutes**

---

## 📝 REFERENCE GUIDES

- **Full Firestore Setup**: See `FIREBASE_SETUP_GUIDE.md`
- **Full Gemini/FCM Setup**: See `PHASE_5_GEMINI_SETUP.md`
- **Code Updated**: `recommendation_service.dart` (Claude → Gemini) ✅

---

## 🎯 WHAT'S NEXT AFTER SETUP?

Once all setup is complete:

```bash
# Build APK for Android
cd activemy_flutter
flutter build apk --release --dart-define=GOOGLE_GEMINI_API_KEY=YOUR_KEY

# Install on device
flutter install

# Or install APK manually
adb install build/app/outputs/apk/release/app-release.apk
```

---

## 🚨 IMPORTANT REMINDERS

1. **API Key Security**: Never commit API key to git
2. **Firestore Indexes**: Wait for all 4 to complete (status = "Enabled")
3. **Environment Variable**: Must be set BEFORE running flutter
4. **Android Device**: Enable Developer Mode + USB Debugging to test

---

## 📞 QUICK TROUBLESHOOTING

| Issue | Fix |
|-------|-----|
| "No issues found" not appearing | Run `flutter clean && flutter pub get` |
| Gemini API key empty | Check env var: `echo $env:GOOGLE_GEMINI_API_KEY` |
| Indexes stuck building | Normal. Refresh page after 5 minutes. |
| Rules not publishing | Check for syntax errors. Use Rules Simulator to test. |

---

## 🎉 YOU'RE ALMOST DONE!

After completing all steps above:
- ✅ Firestore security configured
- ✅ Gemini AI recommendations ready
- ✅ FCM notifications ready
- ✅ App ready to deploy on Android

**Next: Build APK and test on device!**
