import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/event_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_layout.dart';

class AdminScrapedEventsScreen extends StatelessWidget {
  const AdminScrapedEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      activeRoute: RoutePaths.adminScrapedEvents,
      title: 'Newly Scraped',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Newly Scraped Events',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppAdminColors.textMain,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review the latest events gathered by the automated scrapers',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppAdminColors.textSub,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Expanded(
          child: StreamBuilder<List<EventModel>>(
            stream: context.read<FirestoreService>().streamNewlyScrapedEvents(limit: 100),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppAdminColors.primaryNeon));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading events: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }

              final events = snapshot.data ?? [];

              if (events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_busy, size: 64, color: AppAdminColors.border),
                      const SizedBox(height: 16),
                      Text(
                        'No scraped events found',
                        style: GoogleFonts.inter(fontSize: 16, color: AppAdminColors.textSub),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.only(bottom: 24),
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
              );
            },
          ),
        ),
        ],
      ),
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
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
                // Source badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      event.source.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white,
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
                      color: Colors.white,
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
                    children: [
                      const Icon(Icons.sync, size: 14, color: AppAdminColors.textSub),
                      const SizedBox(width: 6),
                      Text(
                        'Scraped ${timeago.format(event.scrapedAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppAdminColors.textSub,
                          fontStyle: FontStyle.italic,
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
}
