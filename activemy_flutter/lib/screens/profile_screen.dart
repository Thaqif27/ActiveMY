import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _updating = false;
  final GlobalKey _savedEventsKey = GlobalKey();

  late AnimationController _headerController;
  late Animation<double> _headerAnim;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _headerAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  Future<void> _toggleCategoryPreference(
    UserModel user,
    String category,
    bool select,
  ) async {
    final newCategories = List<String>.from(user.preferredCategories);
    if (select) {
      newCategories.add(category);
    } else {
      if (newCategories.length <= 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must select at least one preferred category.')),
        );
        return;
      }
      newCategories.remove(category);
    }

    setState(() => _updating = true);
    try {
      final firestore = context.read<FirestoreService>();
      await firestore.updateUserPreferences(
        uid: user.uid,
        categories: newCategories,
        radiusKm: user.preferredRadiusKm,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update categories: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _updateRadiusPreference(UserModel user, double radius) async {
    setState(() => _updating = true);
    try {
      final firestore = context.read<FirestoreService>();
      await firestore.updateUserPreferences(
        uid: user.uid,
        categories: user.preferredCategories,
        radiusKm: radius,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update search radius: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _pickAndUploadAvatar(UserModel user) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      
      if (image == null) return;
      
      setState(() => _updating = true);
      
      if (!mounted) return;
      final firestore = context.read<FirestoreService>();
      final File file = File(image.path);
      final String fileName = '${user.uid}_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('avatars').child(fileName);
      
      await storageRef.putFile(file);
      final String downloadUrl = await storageRef.getDownloadURL();
      
      await firestore.updateProfileDetails(
        uid: user.uid,
        displayName: user.displayName,
        phoneNumber: user.phoneNumber,
        photoUrl: downloadUrl,
        bio: user.bio,
        emergencyContactName: user.emergencyContactName,
        emergencyContactPhone: user.emergencyContactPhone,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out?',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out of ActiveMY?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'Sign Out',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<AuthService>().signOut();
        if (mounted) context.go(RoutePaths.login);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
        }
      }
    }
  }

  Future<void> _removeBookmark(String eventId) async {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await firestore.removeFavoriteEvent(uid: user.uid, eventId: eventId);
      await firestore.logUserBehavior(
        uid: user.uid,
        eventId: eventId,
        action: 'unsave',
        category: 'unknown',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Removed from bookmarks.'),
            backgroundColor: AppColors.darkSurface,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove bookmark: $e')),
        );
      }
    }
  }

  void _showEditProfileSheet(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditProfileSheet(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final firestore = context.read<FirestoreService>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(currentUser.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userProfile = snapshot.data;
        if (userProfile == null) {
          return const Scaffold(
            body: Center(child: Text('Profile not found.')),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: _buildBottomNav(context, 4),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Animated Gradient Hero Header ──────────────────────
              SliverToBoxAdapter(
                child: _ProfileHero(
                  userProfile: userProfile,
                  animation: _headerAnim,
                  onLogout: _handleLogout,
                  onEditProfile: () => _showEditProfileSheet(userProfile),
                  onPickAvatar: () => _pickAndUploadAvatar(userProfile),
                ),
              ),

              // ─── Updating Progress Bar ───────────────────────────────
              if (_updating)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    color: AppColors.primary,
                    backgroundColor: Colors.white,
                    minHeight: 2,
                  ),
                ),

              // ─── Sports Preferences Card ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _PreferencesCard(
                    userProfile: userProfile,
                    onCategoryToggle: (cat, selected) =>
                        _toggleCategoryPreference(userProfile, cat, selected),
                    onRadiusChange: (r) =>
                        _updateRadiusPreference(userProfile, r),
                  ),
                ),
              ),

              // ─── Athlete Stats ─────────────────────────────
              StreamBuilder<List<EventModel>>(
                stream: firestore.streamFavoriteEvents(currentUser.uid),
                builder: (context, favSnapshot) {
                  final favoritesCount = favSnapshot.data?.length ?? 0;
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: _AthleteStatsCard(
                        savedCount: favoritesCount,
                        categoriesCount: userProfile.preferredCategories.length,
                        onSavedEventsTap: () {
                          if (_savedEventsKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              _savedEventsKey.currentContext!,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              // ─── Emergency Contact Card ─────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _EmergencyContactCard(
                    userProfile: userProfile,
                    onEdit: () => _showEditProfileSheet(userProfile),
                  ),
                ),
              ),

              // ─── Saved Events Section ────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  key: _savedEventsKey,
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Saved Events',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Favorite Events Stream ─────────────────────────────
              StreamBuilder<List<EventModel>>(
                stream: firestore.streamFavoriteEvents(currentUser.uid),
                builder: (context, favSnapshot) {
                  if (favSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  final favorites = favSnapshot.data ?? [];
                  if (favorites.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptySavedEvents(
                        onExplore: () => context.go(RoutePaths.home),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SavedEventCard(
                            event: favorites[i],
                            index: i,
                            onRemove: () => _removeBookmark(favorites[i].id),
                          ),
                        ),
                        childCount: favorites.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav(BuildContext context, int currentIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Home', isActive: currentIndex == 0, onTap: () => context.go(RoutePaths.home)),
              _NavItem(icon: Icons.map_rounded, label: 'Map', isActive: currentIndex == 1, onTap: () => context.go(RoutePaths.map)),
              _NavItem(icon: Icons.search_rounded, label: 'Search', isActive: currentIndex == 2, onTap: () => context.go(RoutePaths.search)),
              _NavItem(icon: Icons.notifications_rounded, label: 'Alerts', isActive: currentIndex == 3, onTap: () => context.go(RoutePaths.notifications)),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', isActive: currentIndex == 4, onTap: () => context.go(RoutePaths.profile)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile Hero Header ──────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final UserModel userProfile;
  final Animation<double> animation;
  final VoidCallback onLogout;
  final VoidCallback onEditProfile;
  final VoidCallback onPickAvatar;

  const _ProfileHero({
    required this.userProfile,
    required this.animation,
    required this.onLogout,
    required this.onEditProfile,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final initials = userProfile.displayName.isNotEmpty
        ? userProfile.displayName[0].toUpperCase()
        : userProfile.email.isNotEmpty
            ? userProfile.email[0].toUpperCase()
            : 'U';

    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final c1 = Color.lerp(
          const Color(0xFF1A0500),
          const Color(0xFF2D0A00),
          animation.value,
        )!;
        final c2 = Color.lerp(
          const Color(0xFF8B2500),
          const Color(0xFFCC3D00),
          animation.value,
        )!;
        final c3 = Color.lerp(
          const Color(0xFFFF6B35),
          const Color(0xFFFF8C35),
          animation.value,
        )!;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c1, c2, c3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Top row: title + logout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onEditProfile,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: onLogout,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(Icons.logout_rounded,
                              color: Colors.white70, size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Avatar + info
              Row(
                children: [
                  // Glowing Avatar
                  GestureDetector(
                    onTap: onPickAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: userProfile.photoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: userProfile.photoUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      initials,
                                      style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 18),

                  // Name + email + badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile.displayName.isNotEmpty
                              ? userProfile.displayName
                              : 'ActiveMY Athlete',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userProfile.email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        if (userProfile.bio.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            userProfile.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: userProfile.isAdmin
                                ? Colors.amber.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: userProfile.isAdmin
                                  ? Colors.amber.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            userProfile.isAdmin ? '⭐ ADMIN' : '🏃 ATHLETE',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: userProfile.isAdmin
                                  ? Colors.amber[300]
                                  : Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Preferences Card ────────────────────────────────────────────────────

class _PreferencesCard extends StatelessWidget {
  final UserModel userProfile;
  final void Function(String, bool) onCategoryToggle;
  final void Function(double) onRadiusChange;

  const _PreferencesCard({
    required this.userProfile,
    required this.onCategoryToggle,
    required this.onRadiusChange,
  });

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'running':
        return AppColors.running;
      case 'cycling':
        return AppColors.cycling;
      case 'hiking':
        return AppColors.hiking;
      case 'adventure':
        return AppColors.adventure;
      case 'triathlon':
        return AppColors.triathlon;
      default:
        return AppColors.primary;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'running':
        return Icons.directions_run_rounded;
      case 'cycling':
        return Icons.directions_bike_rounded;
      case 'hiking':
        return Icons.terrain_rounded;
      case 'adventure':
        return Icons.explore_rounded;
      case 'triathlon':
        return Icons.pool_rounded;
      default:
        return Icons.sports;
    }
  }

  /// Returns a display label for a radius value, handling double.infinity.
  String _radiusLabel(double v) {
    if (!v.isFinite) return '∞';
    if (v <= 0) return '${AppConstants.defaultRadiusKm.toInt()}';
    return v.toInt().toString();
  }


  @override
  Widget build(BuildContext context) {
    const radiusOptions = AppConstants.radiusOptionsKm;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppGradients.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tune_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Sports Preferences',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 20),

          // Categories
          Text(
            'Preferred Sports',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMid,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.categories.map((cat) {
              final isSelected =
                  userProfile.preferredCategories.contains(cat);
              final color = _catColor(cat);
              return GestureDetector(
                onTap: () => onCategoryToggle(cat, !isSelected),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isSelected
                          ? color.withValues(alpha: 0.4)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_catIcon(cat),
                          size: 14,
                          color: isSelected ? color : AppColors.textLight),
                      const SizedBox(width: 6),
                      Text(
                        cat,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? color : AppColors.textLight,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded,
                            size: 13, color: color),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 20),

          // Radius
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Search Radius',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMid,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_radiusLabel(userProfile.preferredRadiusKm)} km',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: radiusOptions.map((radius) {
              final isSelected = userProfile.preferredRadiusKm == radius;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => onRadiusChange(radius),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppGradients.primary : null,
                        color: isSelected ? null : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${_radiusLabel(radius)}${radius.isFinite ? ' km' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textMid,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Saved Events ───────────────────────────────────────────────────

class _EmptySavedEvents extends StatelessWidget {
  final VoidCallback onExplore;

  const _EmptySavedEvents({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: AppDecorations.surfaceCard,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bookmark_border_rounded,
                  size: 36, color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              'No Saved Events Yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the bookmark icon on any event page\nto save it for later.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            _AnimatedScaleButton(
              onTap: onExplore,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55FF6B35),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Explore Events',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Saved Event Card ─────────────────────────────────────────────────────

class _SavedEventCard extends StatefulWidget {
  final EventModel event;
  final int index;
  final VoidCallback onRemove;

  const _SavedEventCard({
    required this.event,
    required this.index,
    required this.onRemove,
  });

  @override
  State<_SavedEventCard> createState() => _SavedEventCardState();
}

class _SavedEventCardState extends State<_SavedEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
            CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 80),
        () { if (mounted) _c.forward(); });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color _catColor(String cat) => AppTheme.getCategoryColor(cat);

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final catColor = _catColor(event.category);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () => context.push(RoutePaths.eventDetail, extra: event),
          child: Container(
            decoration: AppDecorations.surfaceCard,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  // Image strip with gradient overlay
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        color: catColor.withValues(alpha: 0.12),
                        child: event.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: event.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: catColor.withValues(alpha: 0.12),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  AppTheme.getCategoryIcon(event.category),
                                  color: catColor,
                                  size: 36,
                                ),
                              )
                            : Icon(AppTheme.getCategoryIcon(event.category),
                                color: catColor, size: 36),
                      ),
                      // Category colour strip on the left
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(color: catColor),
                        ),
                      ),
                    ],
                  ),

                  // Text content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  event.category.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: catColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 11, color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Text(
                                AppTheme.formatDate(event.date),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: AppColors.textLight),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Remove bookmark button
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: widget.onRemove,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bookmark_remove_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated Scale Button ────────────────────────────────────────────────

class _AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _AnimatedScaleButton({required this.onTap, required this.child});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _sc;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _sc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 130));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _sc, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _sc.forward(),
      onTapUp: (_) {
        _sc.reverse();
        widget.onTap();
      },
      onTapCancel: () => _sc.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}

// ─── Nav Item ─────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: isActive ? AppColors.primary : const Color(0xFF94A3B8)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Athlete Stats Card ───────────────────────────────────────────────────

class _AthleteStatsCard extends StatelessWidget {
  final int savedCount;
  final int categoriesCount;
  final VoidCallback? onSavedEventsTap;

  const _AthleteStatsCard({
    required this.savedCount, 
    required this.categoriesCount,
    this.onSavedEventsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Athlete Stats',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatItem(
                label: 'Saved Events', 
                value: savedCount.toString(), 
                icon: Icons.bookmark_rounded,
                onTap: onSavedEventsTap,
              ),
              const SizedBox(width: 16),
              _StatItem(label: 'Categories', value: categoriesCount.toString(), icon: Icons.sports),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatItem({
    required this.label, 
    required this.value, 
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMid)),
          ],
        ),
        ),
      ),
    );
  }
}

// ─── Emergency Contact Card ───────────────────────────────────────────────

class _EmergencyContactCard extends StatelessWidget {
  final UserModel userProfile;
  final VoidCallback onEdit;

  const _EmergencyContactCard({required this.userProfile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasContact = userProfile.emergencyContactName.isNotEmpty || userProfile.emergencyContactPhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Emergency Contact',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onEdit,
                child: Text('EDIT', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasContact)
            Text('No emergency contact added yet. Please add one in case of an emergency.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight))
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.contact_phone_rounded, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userProfile.emergencyContactName, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        Text(userProfile.emergencyContactPhone, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMid)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  final UserModel user;

  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _iceNameController;
  late TextEditingController _icePhoneController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _phoneController = TextEditingController(text: widget.user.phoneNumber);
    _bioController = TextEditingController(text: widget.user.bio);
    _iceNameController = TextEditingController(text: widget.user.emergencyContactName);
    _icePhoneController = TextEditingController(text: widget.user.emergencyContactPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _iceNameController.dispose();
    _icePhoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final firestore = context.read<FirestoreService>();
      final authService = context.read<AuthService>();
      await firestore.updateProfileDetails(
        uid: widget.user.uid,
        displayName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        photoUrl: widget.user.photoUrl,
        bio: _bioController.text.trim(),
        emergencyContactName: _iceNameController.text.trim(),
        emergencyContactPhone: _icePhoneController.text.trim(),
      );
      
      // Update FirebaseAuth display name
      final currentUser = authService.currentUser;
      if (currentUser != null && _nameController.text.trim().isNotEmpty) {
        await currentUser.updateDisplayName(_nameController.text.trim());
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update: \$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            _buildField('Display Name', _nameController, Icons.person_outline),
            _buildField('Phone Number', _phoneController, Icons.phone_outlined, keyboardType: TextInputType.phone),
            _buildField('Bio', _bioController, Icons.text_snippet_outlined, maxLines: 3),
            
            const SizedBox(height: 16),
            Text('Emergency Contact (ICE)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildField('ICE Contact Name', _iceNameController, Icons.health_and_safety_outlined),
            _buildField('ICE Contact Phone', _icePhoneController, Icons.contact_phone_outlined, keyboardType: TextInputType.phone),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _save,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Save Changes', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textMid)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(fontSize: 15, color: AppColors.textDark),
            decoration: InputDecoration(
              prefixIcon: maxLines == 1 ? Icon(icon, size: 20, color: AppColors.textLight) : null,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

