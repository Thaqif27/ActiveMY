import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

@immutable
class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final DateTime date;
  final String location;
  final double lat;
  final double lng;
  final String source;
  final String originalUrl;
  final String imageUrl;
  final String price;
  final DateTime scrapedAt;
  final bool isActive;
  final bool isVirtual;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    required this.location,
    required this.lat,
    required this.lng,
    required this.source,
    required this.originalUrl,
    required this.imageUrl,
    required this.price,
    required this.scrapedAt,
    required this.isActive,
    required this.isVirtual,
  });

  bool get isHybrid => isVirtual && lat != 0.0 && lng != 0.0;

  factory EventModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for event ${doc.id}');
    }

    return EventModel(
      id: doc.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      date: _parseTimestamp(data['date']),
      location: data['location'] as String? ?? '',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      source: data['source'] as String? ?? '',
      originalUrl: data['original_url'] as String? ?? '',
      imageUrl: _processImageUrl(data['image_url'] as String? ?? ''),
      price: data['price'] as String? ?? 'Free',
      scrapedAt: _parseTimestamp(data['scraped_at']),
      isActive: data['is_active'] as bool? ?? true,
      isVirtual: data['is_virtual'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'date': Timestamp.fromDate(date),
      'location': location,
      'lat': lat,
      'lng': lng,
      'source': source,
      'original_url': originalUrl,
      'image_url': imageUrl,
      'price': price,
      'scraped_at': Timestamp.fromDate(scrapedAt),
      'is_active': isActive,
      'is_virtual': isVirtual,
    };
  }

  static DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    } else if (timestamp is String) {
      return DateTime.tryParse(timestamp) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static String _processImageUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('data:image')) return '';
    if (kIsWeb && url.startsWith('http')) {
      // Use our local backend proxy to bypass CanvasKit CORS errors
      return '${AppConstants.scraperUrl}/proxy-image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
