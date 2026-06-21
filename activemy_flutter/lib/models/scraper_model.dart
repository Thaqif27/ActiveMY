import 'package:cloud_firestore/cloud_firestore.dart';

class ScraperSettingsModel {
  final bool enabled;
  final int runHour;
  final DateTime? lastRun;
  final String status;

  ScraperSettingsModel({
    required this.enabled,
    required this.runHour,
    this.lastRun,
    required this.status,
  });

  factory ScraperSettingsModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScraperSettingsModel(
      enabled: data['enabled'] ?? true,
      runHour: data['run_hour'] ?? 2,
      lastRun: (data['last_run'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'idle',
    );
  }
}

class ScraperLogModel {
  final String id;
  final DateTime timestamp;
  final String triggeredBy;
  final String status;
  final int eventsFound;
  final int eventsUploaded;
  final double durationSeconds;
  final Map<String, dynamic> details;

  ScraperLogModel({
    required this.id,
    required this.timestamp,
    required this.triggeredBy,
    required this.status,
    required this.eventsFound,
    required this.eventsUploaded,
    required this.durationSeconds,
    required this.details,
  });

  factory ScraperLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ScraperLogModel(
      id: doc.id,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      triggeredBy: data['triggered_by'] ?? 'unknown',
      status: data['status'] ?? 'unknown',
      eventsFound: data['events_found'] ?? 0,
      eventsUploaded: data['events_uploaded'] ?? 0,
      durationSeconds: (data['duration_seconds'] as num?)?.toDouble() ?? 0.0,
      details: data['details'] is Map<String, dynamic> 
          ? data['details'] as Map<String, dynamic> 
          : {},
    );
  }
}
