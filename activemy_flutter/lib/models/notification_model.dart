import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class NotificationModel {
  final String id;
  final String uid;
  final String title;
  final String body;
  final String? eventId;
  final DateTime sentAt;
  final bool isRead;

  const NotificationModel({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    this.eventId,
    required this.sentAt,
    required this.isRead,
  });

  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for notification ${doc.id}');
    }

    return NotificationModel(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      eventId: data['event_id'] as String?,
      sentAt: _parseTimestamp(data['sent_at']),
      isRead: data['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'title': title,
      'body': body,
      if (eventId != null) 'event_id': eventId,
      'sent_at': Timestamp.fromDate(sentAt),
      'is_read': isRead,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? uid,
    String? title,
    String? body,
    String? eventId,
    DateTime? sentAt,
    bool? isRead,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      title: title ?? this.title,
      body: body ?? this.body,
      eventId: eventId ?? this.eventId,
      sentAt: sentAt ?? this.sentAt,
      isRead: isRead ?? this.isRead,
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
