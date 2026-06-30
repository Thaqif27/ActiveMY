import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role;
  final List<String> preferredCategories;
  final double preferredRadiusKm;
  final String fcmToken;
  final String phoneNumber;
  final String photoUrl;
  final String bio;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final double? lastKnownLat;
  final double? lastKnownLng;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.preferredCategories,
    required this.preferredRadiusKm,
    required this.fcmToken,
    this.phoneNumber = '',
    this.photoUrl = '',
    this.bio = '',
    this.emergencyContactName = '',
    this.emergencyContactPhone = '',
    this.lastKnownLat,
    this.lastKnownLng,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for user ${doc.id}');
    }

    return UserModel(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['display_name'] as String? ?? '',
      role: data['role'] as String? ?? 'user',
      preferredCategories: List<String>.from(
        (data['preferred_categories'] as List<dynamic>? ?? const []),
      ),
      preferredRadiusKm: (data['preferred_radius_km'] as num?)?.toDouble() ?? 50.0,
      fcmToken: data['fcm_token'] as String? ?? '',
      phoneNumber: data['phone_number'] as String? ?? '',
      photoUrl: data['photo_url'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      emergencyContactName: data['emergency_contact_name'] as String? ?? '',
      emergencyContactPhone: data['emergency_contact_phone'] as String? ?? '',
      lastKnownLat: (data['last_known_lat'] as num?)?.toDouble(),
      lastKnownLng: (data['last_known_lng'] as num?)?.toDouble(),
      createdAt: _parseTimestamp(data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'role': role,
      'preferred_categories': preferredCategories,
      'preferred_radius_km': preferredRadiusKm,
      'fcm_token': fcmToken,
      'phone_number': phoneNumber,
      'photo_url': photoUrl,
      'bio': bio,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      if (lastKnownLat != null) 'last_known_lat': lastKnownLat,
      if (lastKnownLng != null) 'last_known_lng': lastKnownLng,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
    List<String>? preferredCategories,
    double? preferredRadiusKm,
    String? fcmToken,
    String? phoneNumber,
    String? photoUrl,
    String? bio,
    String? emergencyContactName,
    String? emergencyContactPhone,
    double? lastKnownLat,
    double? lastKnownLng,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredRadiusKm: preferredRadiusKm ?? this.preferredRadiusKm,
      fcmToken: fcmToken ?? this.fcmToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      lastKnownLat: lastKnownLat ?? this.lastKnownLat,
      lastKnownLng: lastKnownLng ?? this.lastKnownLng,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.parse(value);
    }
    throw FormatException('Unsupported timestamp value: $value');
  }
}
