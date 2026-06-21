import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // For scaffoldMessengerKey
import 'firestore_service.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirestoreService _firestoreService;

  NotificationService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  Future<void> initialize(String uid) async {
    // 1. Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
      
      // 2. Get the token
      String? token;
      try {
        if (!kIsWeb) {
          token = await _firebaseMessaging.getToken();
        }
      } catch (e) {
        debugPrint('Error getting FCM token: $e');
      }
      
      if (token != null) {
        debugPrint('FCM Token: $token');
        await _firestoreService.updateFcmToken(uid: uid, fcmToken: token);
      }

      // 3. Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
        _firestoreService.updateFcmToken(uid: uid, fcmToken: newToken);
      });
      
      // 4. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // Show local snackbar for foreground notifications
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('${message.notification?.title ?? "Notification"}: ${message.notification?.body ?? ""}'),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
      
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }
}
