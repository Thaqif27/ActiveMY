import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/marker_helper.dart';
import 'admin_layout.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  static const LatLng _centerMalaysia = LatLng(4.2105, 101.9758); // Center of Peninsular Malaysia

  void _showGroupedEventsSheet(List<EventModel> groupedEvents) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${groupedEvents.length} Events at this location',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: groupedEvents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final event = groupedEvents[index];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            leading: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: event.imageUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: Colors.white10,
                                    child: const Icon(Icons.image_not_supported, color: Colors.white54),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              event.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${event.lat.toStringAsFixed(4)}, ${event.lng.toStringAsFixed(4)}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<Set<Marker>> _buildMarkers(Map<String, List<EventModel>> locationGroups) async {
    Set<Marker> markers = {};
    for (var entry in locationGroups.entries) {
      final group = entry.value;
      final firstEvent = group.first;
      
      final icon = await MarkerHelper.getCustomMarker(
        firstEvent.category,
        isMultiple: group.length > 1,
      );

      markers.add(Marker(
        markerId: MarkerId('group_${entry.key}'),
        position: LatLng(firstEvent.lat, firstEvent.lng),
        icon: icon,
        infoWindow: InfoWindow(
          title: group.length > 1 ? '${group.length} Events Here' : firstEvent.title,
          snippet: firstEvent.location,
        ),
        onTap: () {
          _showGroupedEventsSheet(group);
        },
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return AdminLayout(
      activeRoute: RoutePaths.adminMap,
      title: 'Geocoding Monitor',
      child: StreamBuilder<List<EventModel>>(
        stream: firestore.streamAllEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
          }

          final events = snapshot.data ?? [];
          final validEvents = events.where((e) => !e.isVirtual && e.lat != 0.0 && e.lng != 0.0).toList();
          
          // Group events by location to prevent overlapping pins
          final Map<String, List<EventModel>> locationGroups = {};
          for (var event in validEvents) {
            final key = '${event.lat.toStringAsFixed(4)}_${event.lng.toStringAsFixed(4)}';
            if (!locationGroups.containsKey(key)) {
              locationGroups[key] = [];
            }
            locationGroups[key]!.add(event);
          }

          return FutureBuilder<Set<Marker>>(
            future: _buildMarkers(locationGroups),
            builder: (context, markerSnapshot) {
              final markers = markerSnapshot.data ?? {};

              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _centerMalaysia,
                        zoom: 6.0,
                      ),
                      markers: markers,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                  ),
              Positioned(
                top: 24,
                left: 24,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${validEvents.length} Physical Events Mapped',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                              ),
                              Text(
                                'Filtered out of ${events.length} total aggregated events',
                                style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  ),
    );
  }
}
