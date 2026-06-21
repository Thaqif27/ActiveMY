import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'admin_layout.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  bool _updating = false;
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppAdminColors.cardDark,
        title: const Text('Delete Event', style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to permanently delete this event? This action cannot be undone.',
            style: TextStyle(color: AppAdminColors.textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppAdminColors.textSub)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _updating = true);
      try {
        final firestore = context.read<FirestoreService>();
        await firestore.deleteEvent(eventId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete event: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _updating = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return _buildAccessDenied(context);
    }

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(currentUser.uid),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting && !authSnapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppAdminColors.bgDark,
            body: Center(child: CircularProgressIndicator(color: AppAdminColors.primaryNeon)),
          );
        }

        final userProfile = authSnapshot.data;
        if (userProfile == null || !userProfile.isAdmin) {
          return _buildAccessDenied(context);
        }

        return StreamBuilder<List<EventModel>>(
          stream: firestore.streamAllEvents(),
          builder: (context, eventsSnapshot) {
            if (eventsSnapshot.hasError) {
              return Scaffold(
                backgroundColor: AppAdminColors.bgDark,
                body: Center(
                  child: Text('Error loading events: ${eventsSnapshot.error}', style: const TextStyle(color: Colors.red)),
                ),
              );
            }
            if (eventsSnapshot.connectionState == ConnectionState.waiting && !eventsSnapshot.hasData) {
              return const Scaffold(
                backgroundColor: AppAdminColors.bgDark,
                body: Center(child: CircularProgressIndicator(color: AppAdminColors.primaryNeon)),
              );
            }

            var events = eventsSnapshot.data ?? [];
            if (_selectedCategory != 'All') {
              events = events.where((e) => e.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);

            if (_selectedStatus != 'All') {
              events = events.where((e) {
                final eventDate = DateTime(e.date.year, e.date.month, e.date.day);
                final isPast = eventDate.isBefore(today);
                if (_selectedStatus == 'Active') return !isPast;
                if (_selectedStatus == 'Past') return isPast;
                return true;
              }).toList();
            }

            events.sort((a, b) => a.date.compareTo(b.date));

            return AdminLayout(
              activeRoute: RoutePaths.adminEvents,
              title: 'Manage Aggregated Events',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_updating)
                    const LinearProgressIndicator(
                        color: AppAdminColors.primaryNeon,
                        backgroundColor: Colors.transparent),

                  // Filters
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text('Category: ', style: GoogleFonts.inter(color: AppAdminColors.textSub, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 12),
                              ...['All', 'Running', 'Cycling', 'Hiking', 'Triathlon'].map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: FilterChip(
                                    label: Text(
                                      cat,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? AppAdminColors.primaryNeon : AppAdminColors.textSub,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _selectedCategory = cat);
                                    },
                                    backgroundColor: AppAdminColors.cardDark,
                                    selectedColor: AppAdminColors.primaryNeon.withValues(alpha: 0.15),
                                    side: BorderSide(
                                      color: isSelected 
                                        ? AppAdminColors.primaryNeon.withValues(alpha: 0.5) 
                                        : AppAdminColors.border,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Text('Status:     ', style: GoogleFonts.inter(color: AppAdminColors.textSub, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 12),
                              ...['All', 'Active', 'Past'].map((status) {
                                final isSelected = _selectedStatus == status;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: FilterChip(
                                    label: Text(
                                      status,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? AppAdminColors.primaryNeon : AppAdminColors.textSub,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) setState(() => _selectedStatus = status);
                                    },
                                    backgroundColor: AppAdminColors.cardDark,
                                    selectedColor: AppAdminColors.primaryNeon.withValues(alpha: 0.15),
                                    side: BorderSide(
                                      color: isSelected 
                                        ? AppAdminColors.primaryNeon.withValues(alpha: 0.5) 
                                        : AppAdminColors.border,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Events Grid
                  Expanded(
                    child: events.isEmpty 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.event_busy, size: 64, color: AppAdminColors.border),
                              const SizedBox(height: 16),
                              Text(
                                'No events found for this category',
                                style: GoogleFonts.inter(fontSize: 16, color: AppAdminColors.textSub),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            return _buildEventCard(context, events[index]);
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

  Widget _buildEventCard(BuildContext context, EventModel event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
    final isPast = eventDate.isBefore(today);
    
    return Container(
      decoration: BoxDecoration(
        color: AppAdminColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppAdminColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          Expanded(
            flex: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                event.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.black26),
                        errorWidget: (context, url, error) => Container(
                          color: AppAdminColors.bgDark,
                          child: const Icon(Icons.broken_image, color: AppAdminColors.textSub, size: 48),
                        ),
                      )
                    : Container(
                        color: AppAdminColors.bgDark,
                        child: const Icon(Icons.event, color: AppAdminColors.textSub, size: 48),
                      ),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppAdminColors.primaryNeon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppAdminColors.primaryNeon.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      event.category.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppAdminColors.primaryNeon,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Status / Source badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPast ? Colors.grey.withValues(alpha: 0.2) : Colors.greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isPast ? Colors.grey.withValues(alpha: 0.4) : Colors.greenAccent.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      isPast ? 'PAST' : 'ACTIVE',
                      style: GoogleFonts.inter(
                        color: isPast ? Colors.white70 : Colors.greenAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppAdminColors.textMain,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildIconText(Icons.calendar_today, dateFormat.format(event.date)),
                  const SizedBox(height: 8),
                  _buildIconText(Icons.location_on, event.location),
                  const Spacer(),
                  const Divider(color: AppAdminColors.border, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.source, size: 14, color: AppAdminColors.textSub),
                          const SizedBox(width: 6),
                          Text(
                            event.source.toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppAdminColors.textSub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Delete Action
                      InkWell(
                        onTap: () => _deleteEvent(event.id),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(
                                'DELETE',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppAdminColors.textSub),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppAdminColors.textSub,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdminColors.bgDark,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppAdminColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppAdminColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, color: Colors.redAccent, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'You do not have administrative privileges to access this panel. Only admin roles are allowed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go(RoutePaths.login),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
