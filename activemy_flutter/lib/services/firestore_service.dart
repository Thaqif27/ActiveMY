
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../models/scraper_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection(FirestoreCollections.events);

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection(FirestoreCollections.users);

  CollectionReference<Map<String, dynamic>> get _userBehavior =>
      _db.collection(FirestoreCollections.userBehavior);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection(FirestoreCollections.notifications);

  CollectionReference<Map<String, dynamic>> get _scraperLogs =>
      _db.collection('scraper_logs');

  DocumentReference<Map<String, dynamic>> get _scraperSettings =>
      _db.collection('settings').doc('scraper_settings');

  Future<void> createUserIfMissing(UserModel user) async {
    final doc = await _users.doc(user.uid).get();
    if (!doc.exists) {
      await _users.doc(user.uid).set(user.toMap());
    }
  }

  Stream<UserModel?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return null;
      }
      return UserModel.fromFirestore(snapshot);
    });
  }

  Future<void> updateUserPreferences({
    required String uid,
    required List<String> categories,
    required double radiusKm,
  }) {
    return _users.doc(uid).update({
      'preferred_categories': categories,
      'preferred_radius_km': radiusKm,
    });
  }

  Future<void> updateUserRole({
    required String uid,
    required String role,
  }) {
    return _users.doc(uid).update({
      'role': role,
    });
  }

  Future<void> updateProfileDetails({
    required String uid,
    required String displayName,
    required String phoneNumber,
    required String photoUrl,
    required String bio,
    required String emergencyContactName,
    required String emergencyContactPhone,
  }) {
    return _users.doc(uid).update({
      'display_name': displayName,
      'phone_number': phoneNumber,
      'photo_url': photoUrl,
      'bio': bio,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
    });
  }

  Future<void> deleteUser(String uid) {
    return _users.doc(uid).delete();
  }

  Future<void> updateUserLocation({
    required String uid,
    required double lat,
    required double lng,
  }) async {
    try {
      final doc = await _users.doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final oldLat = data['last_known_lat'] as double?;
          final oldLng = data['last_known_lng'] as double?;
          
          if (oldLat != null && oldLng != null) {
            final distance = Geolocator.distanceBetween(oldLat, oldLng, lat, lng);
            if (distance > 10000) { // 10km
              debugPrint('User moved ${distance/1000}km, triggering recommendations...');
              http.post(Uri.parse('${AppConstants.scraperUrl}/recommend/$uid')).catchError((e) {
                debugPrint('Failed to trigger recommendations: $e');
                return http.Response('', 500); // Dummy return to satisfy catchError type
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking location distance: $e');
    }

    return _users.doc(uid).update({
      'last_known_lat': lat,
      'last_known_lng': lng,
      'last_location_update': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateFcmToken({required String uid, required String fcmToken}) async {
    await _db.collection('users').doc(uid).set({
      'fcm_tokens': FieldValue.arrayUnion([fcmToken]),
      'fcm_token': fcmToken, // Keep legacy field just in case
    }, SetOptions(merge: true));
  }

  Stream<List<EventModel>> streamAllEvents() {
    return _events.snapshots().map(_mapEvents);
  }

  Stream<List<UserModel>> streamAllUsers() {
    return _users.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList());
  }

  Stream<List<EventModel>> streamUpcomingEvents({
    List<String>? categories,
  }) {
    Query<Map<String, dynamic>> query = _events
        .where('is_active', isEqualTo: true)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
        .orderBy('date');

    if (categories != null && categories.isNotEmpty) {
      query = query.where('category', whereIn: categories);
    }

    return query.snapshots().map(_mapEvents);
  }

  Stream<List<EventModel>> streamNearbyEvents({
    required double lat,
    required double lng,
    required double radiusKm,
  }) {
    final geoCollectionReference = GeoCollectionReference<Map<String, dynamic>>(_events);
    
    return geoCollectionReference.subscribeWithin(
      center: GeoFirePoint(GeoPoint(lat, lng)),
      radiusInKm: radiusKm,
      field: 'geo',
      geopointFrom: (data) => (data['geo'] as Map<String, dynamic>)['geopoint'] as GeoPoint,
      strictMode: true,
    ).map((snapshots) {
      final allEvents = snapshots.map((doc) => EventModel.fromFirestore(doc)).toList();
      final now = DateTime.now();
      return allEvents.where((e) => e.isActive && e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
    });
  }

  // Stream ALL active upcoming events (bypassing geolocation filtering)
  Stream<List<EventModel>> streamAllUpcomingEvents() {
    // We cannot use multiple inequalities in Firestore without composite indexes,
    // so we fetch all events that are active and filter dates locally.
    // If the database grows huge, we can paginate, but for < 1000 events this is fine.
    return _events
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final allEvents = snapshot.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
      final now = DateTime.now();
      return allEvents.where((e) => e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
    });
  }

  Stream<List<EventModel>> streamNewlyScrapedEvents({int limit = 100}) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _events
        .where('scraped_at', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterday))
        .orderBy('scraped_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapEvents);
  }


  Future<List<EventModel>> searchEvents({
    required String query,
    List<String>? categories,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query<Map<String, dynamic>> dbQuery =
        _events.where('is_active', isEqualTo: true);

    if (startDate != null) {
      dbQuery = dbQuery.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }

    if (endDate != null) {
      dbQuery = dbQuery.where('date',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    final snapshot = await dbQuery.get();
    var events = snapshot.docs.map(EventModel.fromFirestore).toList();

    // Client-side category filtering to support 'Virtual' and 'Hybrid'
    if (categories != null && categories.isNotEmpty) {
      final lowerCategories = categories.map((c) => c.toLowerCase()).toList();
      final wantsVirtual = lowerCategories.contains('virtual');
      final wantsHybrid = lowerCategories.contains('hybrid');
      
      events = events.where((e) {
        if (wantsVirtual && e.isVirtual && !e.isHybrid) return true;
        if (wantsHybrid && e.isHybrid) return true;
        if (lowerCategories.contains(e.category.toLowerCase())) return true;
        return false;
      }).toList();
    }

    final queryLower = query.toLowerCase();
    return events
        .where((event) =>
            event.title.toLowerCase().contains(queryLower) ||
            event.location.toLowerCase().contains(queryLower) ||
            event.description.toLowerCase().contains(queryLower))
        .toList();
  }

  Future<EventModel?> getEvent(String eventId) async {
    try {
      final doc = await _events.doc(eventId).get();
      if (!doc.exists) return null;
      return EventModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateEventActiveStatus({
    required String eventId,
    required bool isActive,
  }) {
    return _events.doc(eventId).update({'is_active': isActive});
  }

  Future<void> addEvent(EventModel event) async {
    final data = event.toMap();
    final geoFirePoint = GeoFirePoint(GeoPoint(event.lat, event.lng));
    data['geo'] = {
      'geohash': geoFirePoint.geohash,
      'geopoint': geoFirePoint.geopoint,
    };
    data['location_geo'] = geoFirePoint.geopoint;
    await _events.doc(event.id).set(data);
  }

  Future<void> deleteEvent(String eventId) {
    return _events.doc(eventId).delete();
  }

  Future<void> logUserBehavior({
    required String uid,
    required String eventId,
    required String action,
    required String category,
  }) {
    return _userBehavior.add({
      'uid': uid,
      'event_id': eventId,
      'action': action,
      'category': category,
      'timestamp': Timestamp.fromDate(DateTime.now()),
    });
  }

  Stream<List<NotificationModel>> streamNotifications(String uid) {
    return _notifications
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList();
          list.sort((a, b) => b.sentAt.compareTo(a.sentAt));
          return list;
        });
  }

  Future<void> markNotificationAsRead(String id) {
    return _notifications.doc(id).update({'is_read': true});
  }

  Future<void> deleteNotification(String id) {
    return _notifications.doc(id).delete();
  }

  Future<void> saveFavoriteEvent({
    required String uid,
    required String eventId,
  }) {
    return _users
        .doc(uid)
        .collection(FirestoreCollections.favorites)
        .doc(eventId)
        .set({
      'event_id': eventId,
      'saved_at': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> removeFavoriteEvent({
    required String uid,
    required String eventId,
  }) {
    return _users
        .doc(uid)
        .collection(FirestoreCollections.favorites)
        .doc(eventId)
        .delete();
  }

  Stream<List<EventModel>> streamFavoriteEvents(String uid) {
    final favoritesRef =
        _users.doc(uid).collection(FirestoreCollections.favorites);

    return favoritesRef.snapshots().asyncMap((snapshot) async {
      final eventIds = snapshot.docs
          .map((doc) => doc.data()['event_id'] as String?)
          .whereType<String>()
          .toList();
      if (eventIds.isEmpty) {
        return <EventModel>[];
      }

      final chunks = <List<String>>[];
      for (var i = 0; i < eventIds.length; i += 10) {
        final end = i + 10 > eventIds.length ? eventIds.length : i + 10;
        chunks.add(eventIds.sublist(i, end));
      }

      final results = <EventModel>[];
      for (final chunk in chunks) {
        final query =
            await _events.where(FieldPath.documentId, whereIn: chunk).get();
        results.addAll(query.docs.map(EventModel.fromFirestore));
      }
      return results;
    });
  }

  List<EventModel> _mapEvents(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs
        .map((doc) {
          try {
            return EventModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Skipping bad event doc ${doc.id}: $e');
            return null;
          }
        })
        .whereType<EventModel>()
        .toList();
  }

  Stream<ScraperSettingsModel> streamScraperSettings() {
    return _scraperSettings.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return ScraperSettingsModel(enabled: true, runHour: 2, status: 'idle');
      }
      return ScraperSettingsModel.fromFirestore(snapshot);
    });
  }

  Future<void> updateScraperSettings({required bool enabled, required int runHour}) {
    return _scraperSettings.set({
      'enabled': enabled,
      'run_hour': runHour,
    }, SetOptions(merge: true));
  }

  Stream<List<ScraperLogModel>> streamScraperLogs() {
    return _scraperLogs
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ScraperLogModel.fromFirestore(doc)).toList();
    });
  }
}
