import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/event_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/marker_helper.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<Position?> _locationFuture;
  double _radiusKm = AppConstants.defaultRadiusKm;
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _locationFuture = _resolveLocation();
  }

  Future<Position?> _resolveLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition();
  }

  void _showRadiusSelector() {
    const options = AppConstants.radiusOptionsKm;
    final currentIndex = options.indexOf(_radiusKm).clamp(0, options.length - 1);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        double sliderValue = currentIndex.toDouble();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    options[sliderValue.toInt()] == double.infinity
                        ? 'Search radius (All Malaysia)'
                        : 'Search radius (${options[sliderValue.toInt()].toInt()} km)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Slider(
                    value: sliderValue,
                    min: 0,
                    max: (options.length - 1).toDouble(),
                    divisions: options.length - 1,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                    label: options[sliderValue.toInt()] == double.infinity
                        ? 'All'
                        : '${options[sliderValue.toInt()].toInt()} km',
                    onChanged: (value) {
                      setSheetState(() => sliderValue = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _radiusKm = options[sliderValue.toInt()];
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Apply Radius'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEventSheet(EventModel event) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(event.category).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getCategoryColor(event.category),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textLight),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textLight),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.eventDetail, extra: event);
                  },
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGroupedEventsSheet(List<EventModel> events) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${events.length} Events at this location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getCategoryColor(event.category).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      event.category.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getCategoryColor(event.category),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(context);
                              context.push(RoutePaths.eventDetail, extra: event);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'running':
        return AppColors.running;
      case 'cycling':
        return AppColors.cycling;
      case 'hiking':
        return AppColors.hiking;
      default:
        return Colors.grey;
    }
  }

  Future<Set<Marker>> _buildMarkers(Map<String, List<EventModel>> locationGroups) async {
    Set<Marker> markers = {};
    for (var entry in locationGroups.entries) {
      final locKey = entry.key;
      final eventsAtLoc = entry.value;
      final firstEvent = eventsAtLoc.first;

      final icon = await MarkerHelper.getCustomMarker(
        firstEvent.category,
        isMultiple: eventsAtLoc.length > 1,
      );

      markers.add(Marker(
        markerId: MarkerId(locKey),
        position: LatLng(firstEvent.lat, firstEvent.lng),
        icon: icon,
        infoWindow: InfoWindow(
          title: eventsAtLoc.length > 1 ? '${eventsAtLoc.length} Events Here' : firstEvent.title,
          snippet: firstEvent.location,
        ),
        onTap: () {
          if (eventsAtLoc.length == 1) {
            _showEventSheet(eventsAtLoc.first);
          } else {
            _showGroupedEventsSheet(eventsAtLoc);
          }
        },
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Explore Events Map',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _showRadiusSelector,
            tooltip: 'Adjust search radius',
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(context, 1),
      body: FutureBuilder<Position?>(
        future: _locationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final position = snapshot.data;
          if (position == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_disabled, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    const Text(
                      'Location access required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please enable location services to view sports events near your current position.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textLight),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Geolocator.openAppSettings();
                            await Geolocator.openLocationSettings();
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _locationFuture = _resolveLocation();
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<EventModel>>(
            stream: _radiusKm == double.infinity
                ? firestore.streamAllUpcomingEvents()
                : firestore.streamNearbyEvents(
                    lat: position.latitude,
                    lng: position.longitude,
                    radiusKm: _radiusKm,
                  ),
            builder: (context, eventsSnapshot) {
              if (eventsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = eventsSnapshot.data ?? [];

              final validEvents = events.where((e) {
                if (e.isVirtual || e.lat == 0.0 || e.lng == 0.0) return false;
                if (_selectedCategory != 'All' && e.category.toLowerCase() != _selectedCategory.toLowerCase()) return false;
                return true;
              }).toList();
              
              final Map<String, List<EventModel>> locationGroups = {};
              for (final event in validEvents) {
                final locKey = '${event.lat},${event.lng}';
                if (!locationGroups.containsKey(locKey)) {
                  locationGroups[locKey] = [];
                }
                locationGroups[locKey]!.add(event);
              }
              
              return FutureBuilder<Set<Marker>>(
                future: _buildMarkers(locationGroups),
                builder: (context, markerSnapshot) {
                  final markers = markerSnapshot.data ?? {};

                  return Stack(
                    children: [
                      GoogleMap(
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: false,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(position.latitude, position.longitude),
                          zoom: 11,
                        ),
                        markers: markers,
                      ),
                      Positioned(
                        top: 16,
                        left: 0,
                        right: 0,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: ['All', 'Running', 'Cycling', 'Hiking'].map((category) {
                              final isSelected = _selectedCategory == category;
                              IconData? catIcon;
                              if (category == 'Running') catIcon = Icons.directions_run;
                              if (category == 'Cycling') catIcon = Icons.directions_bike;
                              if (category == 'Hiking') catIcon = Icons.terrain;

                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  showCheckmark: false,
                                  avatar: catIcon != null 
                                      ? Icon(catIcon, color: isSelected ? Colors.white : AppColors.primary, size: 18) 
                                      : null,
                                  label: Text(category),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  backgroundColor: Colors.white,
                                  elevation: 4,
                                  pressElevation: 6,
                                  shadowColor: Colors.black26,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : AppColors.textDark,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedCategory = category;
                                      });
                                      
                                      // Calculate local count
                                      final count = events.where((e) {
                                        if (e.isVirtual || e.lat == 0.0 || e.lng == 0.0) return false;
                                        if (category != 'All' && e.category.toLowerCase() != category.toLowerCase()) return false;
                                        return true;
                                      }).length;

                                      ScaffoldMessenger.of(context).clearSnackBars();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.check_circle_outline, color: Colors.white),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Showing $count ${category == 'All' ? 'physical' : category} events',
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          backgroundColor: AppColors.textDark.withValues(alpha: 0.9),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  );
                }
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
        BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      onTap: (index) {
        switch (index) {
          case 0:
            context.go(RoutePaths.home);
            break;
          case 1:
            context.go(RoutePaths.map);
            break;
          case 2:
            context.go(RoutePaths.search);
            break;
          case 3:
            context.go(RoutePaths.notifications);
            break;
          case 4:
            context.go(RoutePaths.profile);
            break;
        }
      },
    );
  }
}
