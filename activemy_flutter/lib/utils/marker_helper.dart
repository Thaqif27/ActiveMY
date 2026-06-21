import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'theme.dart';

class MarkerHelper {
  // Cache to prevent re-drawing the same markers repeatedly
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> getCustomMarker(String category, {bool isMultiple = false}) async {
    final String cacheKey = '${category.toLowerCase()}_$isMultiple';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    Color color;
    IconData icon;

    if (isMultiple) {
      color = Colors.purpleAccent;
      icon = Icons.layers;
    } else {
      switch (category.toLowerCase()) {
        case 'running':
          color = AppColors.running;
          icon = Icons.directions_run;
          break;
        case 'cycling':
          color = AppColors.cycling;
          icon = Icons.pedal_bike;
          break;
        case 'hiking':
          color = AppColors.hiking;
          icon = Icons.terrain;
          break;
        default:
          color = Colors.grey;
          icon = Icons.place;
      }
    }

    const int size = 100;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Drop shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(const Offset(size / 2, size / 2 + 4), size / 2.2, shadowPaint);

    // Background circle
    final Paint bgPaint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, bgPaint);

    // White border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.2, borderPaint);

    // Material Icon Text
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final ui.Image img = await pictureRecorder.endRecording().toImage(size, size);
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);
    
    if (data == null) {
      return BitmapDescriptor.defaultMarker;
    }

    final descriptor = BitmapDescriptor.bytes(data.buffer.asUint8List(), width: 36, height: 36);
    _cache[cacheKey] = descriptor;
    return descriptor;
  }
}
