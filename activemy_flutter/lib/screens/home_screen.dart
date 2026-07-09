import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/event_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/recommendation_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late Future<Position?> _locationFuture;
  Future<List<EventModel>>? _recommendationsFuture;
  String _selectedCategory = 'All';

  late AnimationController _heroController;
  late Animation<double> _heroAnim;

  final List<String> _categories = [
    'All',
    'Running',
    'Hiking',
    'Cycling',
  ];

  @override
  void initState() {
    super.initState();
    _locationFuture = _resolveLocation();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _heroAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getGreetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️';
    if (h < 17) return '⚡';
    return '🌙';
  }

  Future<Position?> _resolveLocation() async {
    if (mounted) {
      final uid = context.read<AuthService>().currentUser?.uid;
      if (uid != null) {
        await context.read<NotificationService>().initialize(uid);
      }
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      final uid = context.read<AuthService>().currentUser?.uid;
      if (uid != null) {
        context.read<FirestoreService>().updateUserLocation(
              uid: uid,
              lat: position.latitude,
              lng: position.longitude,
            );
      }
    }
    return position;
  }

  Future<List<EventModel>> _fetchRecommendations(
    FirestoreService firestore,
    String uid,
    List<String> userCategories,
  ) async {
    try {
      final behaviorSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.userBehavior)
          .where('uid', isEqualTo: uid)
          .limit(50)
          .get();

      final docs = behaviorSnap.docs.toList()
        ..sort((a, b) {
          final aT = a.data()['timestamp'] as Timestamp?;
          final bT = b.data()['timestamp'] as Timestamp?;
          if (aT == null || bT == null) return 0;
          return bT.compareTo(aT);
        });

      final viewedCategories = docs
          .where((d) =>
              d.data()['action'] == 'view' || d.data()['action'] == 'click_url')
          .map((d) => d.data()['category'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();

      final savedCategories = docs
          .where((d) => d.data()['action'] == 'save')
          .map((d) => d.data()['category'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toList();

      final upcomingEvents = await firestore.streamUpcomingEvents().first;
      if (upcomingEvents.isEmpty) return [];

      final recService = RecommendationService();
      final recommendedIds = recService.getRecommendedEventIds(
        userViewedCategories: viewedCategories,
        userSavedCategories: savedCategories,
        userCategories: userCategories,
        availableEvents: upcomingEvents,
      );

      // Return events in the exact order recommended by the service
      return recommendedIds
          .map((id) => upcomingEvents.firstWhere((e) => e.id == id))
          .toList();
    } catch (e) {
      debugPrint('Recommendations error: $e');
      return [];
    }
  }

  List<String>? _getCategoryFilter() {
    if (_selectedCategory == 'All' ||
        _selectedCategory == 'Virtual' ||
        _selectedCategory == 'Hybrid') {
      return null;
    }
    return [_selectedCategory.toLowerCase()];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final firestore = context.read<FirestoreService>();
    final firebaseUser = auth.currentUser;

    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in.')),
      );
    }

    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(firebaseUser.uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final radiusKm = user.preferredRadiusKm;

        _recommendationsFuture ??= _fetchRecommendations(
          firestore,
          user.uid,
          user.preferredCategories,
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 0,
          ),
          bottomNavigationBar: _buildBottomNav(context, 0),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ─── Wave Hero ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _WaveHero(
                  greeting: _getGreeting(),
                  emoji: _getGreetingEmoji(),
                  userName: user.displayName.isNotEmpty
                      ? user.displayName.split(' ').first
                      : 'Explorer',
                  animation: _heroAnim,
                  onNotification: () => context.push(RoutePaths.notifications),
                  onInbox: () => context.push(RoutePaths.inbox),
                  onSearch: () => context.push(RoutePaths.search),
                  onMap: () => context.push(RoutePaths.map),
                ),
              ),

              // ─── Recommended (AI Picks) ───────────────────────────
              const SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'AI Picks ✨',
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<List<EventModel>>(
                  future: _recommendationsFuture,
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return _HorizontalShimmer();
                    }
                    final items = snap.data ?? [];
                    if (items.isEmpty) {
                      return const _EmptyHint(
                          'Browse events to get AI recommendations');
                    }
                    return SizedBox(
                      height: 250,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: _PosterCard(
                            event: items[i],
                            index: i,
                            isAiPick: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ─── Category Chips ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 4),
                  child: _CategoryChips(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelect: (cat) => setState(() => _selectedCategory = cat),
                  ),
                ),
              ),

              // ─── Upcoming Events ──────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Upcoming Events',
                  actionLabel: 'See All',
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  onAction: () => context.go(RoutePaths.search),
                ),
              ),
              StreamBuilder<List<EventModel>>(
                stream: firestore.streamUpcomingEvents(
                  categories: _getCategoryFilter(),
                ),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return SliverToBoxAdapter(child: _VerticalShimmer());
                  }
                  var events = snap.data ?? [];



                  if (events.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: _EmptyState(
                          icon: Icons.event_note,
                          label: 'No upcoming events found',
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _StaggeredCard(
                        index: i,
                        child: _EventListCard(event: events[i]),
                      ),
                      childCount: events.take(5).length,
                    ),
                  );
                },
              ),

              // ─── Nearby Events ────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: 'Near You 📍',
                  actionLabel: 'View Map',
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  onAction: () => context.go(RoutePaths.map),
                ),
              ),
              SliverToBoxAdapter(
                child: FutureBuilder<Position?>(
                  future: _locationFuture,
                  builder: (ctx, locSnap) {
                    if (locSnap.connectionState == ConnectionState.waiting) {
                      return _VerticalShimmer();
                    }
                    final pos = locSnap.data;
                    if (pos == null) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _LocationDisabledCard(
                          onRetry: () {
                            setState(() {
                              _locationFuture = _resolveLocation();
                            });
                          },
                        ),
                      );
                    }
                    return StreamBuilder<List<EventModel>>(
                      stream: firestore.streamNearbyEvents(
                        lat: pos.latitude,
                        lng: pos.longitude,
                        radiusKm: radiusKm,
                      ),
                      builder: (ctx2, snap2) {
                        if (snap2.connectionState == ConnectionState.waiting) {
                          return _VerticalShimmer();
                        }
                        final events = snap2.data ?? [];
                        if (events.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _EmptyState(
                              icon: Icons.location_on,
                              label: 'No events within ${radiusKm.toInt()} km',
                            ),
                          );
                        }
                        return Column(
                          children: events
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map((e) => _StaggeredCard(
                                    index: e.key,
                                    child: _EventListCard(event: e.value),
                                  ))
                              .toList(),
                        );
                      },
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isActive: currentIndex == 0,
                  onTap: () => context.go(RoutePaths.home)),
              _NavItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  isActive: currentIndex == 1,
                  onTap: () => context.go(RoutePaths.map)),
              _NavItem(
                  icon: Icons.search_rounded,
                  label: 'Search',
                  isActive: currentIndex == 2,
                  onTap: () => context.go(RoutePaths.search)),
              _NavItem(
                  icon: Icons.notifications_rounded,
                  label: 'Alerts',
                  isActive: currentIndex == 3,
                  onTap: () => context.go(RoutePaths.notifications)),
              _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isActive: currentIndex == 4,
                  onTap: () => context.go(RoutePaths.profile)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Wave Hero ────────────────────────────────────────────────────────────

class _WaveHero extends StatelessWidget {
  final String greeting;
  final String emoji;
  final String userName;
  final Animation<double> animation;
  final VoidCallback onNotification;
  final VoidCallback onInbox;
  final VoidCallback onSearch;
  final VoidCallback onMap;

  const _WaveHero({
    required this.greeting,
    required this.emoji,
    required this.userName,
    required this.animation,
    required this.onNotification,
    required this.onInbox,
    required this.onSearch,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
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

        return ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 68, 24, 56),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1, c2, c3],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting $emoji',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName,
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onInbox,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.inbox_outlined, color: Colors.white, size: 22),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseAuth.instance.currentUser != null ? FirebaseFirestore.instance
                                      .collection('private_chats')
                                      .where('participants', arrayContains: FirebaseAuth.instance.currentUser!.uid)
                                      .snapshots() : null,
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) return const SizedBox.shrink();
                                    
                                    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
                                    bool hasUnread = snapshot.data!.docs.any((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final bool lastMessageIsRead = data['lastMessageIsRead'] ?? true;
                                      final String lastMessageSenderId = data['lastMessageSenderId'] ?? '';
                                      
                                      // It's unread if the last message is NOT read, and the sender is NOT the current user
                                      return !lastMessageIsRead && lastMessageSenderId != '' && lastMessageSenderId != currentUserId;
                                    });

                                    if (!hasUnread) return const SizedBox.shrink();

                                    return Positioned(
                                      top: -2,
                                      right: -2,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: AppColors.primary, width: 2),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onNotification,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tagline
                Text(
                  'Discover running, cycling & hiking\nevents across Malaysia 🇲🇾',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),

                // Quick buttons
                Row(
                  children: [
                    _HeroPill(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      onTap: onMap,
                    ),
                    const SizedBox(width: 10),
                    _HeroPill(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      onTap: onSearch,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height - 40,
      size.width,
      size.height - 10,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper oldClipper) => false;
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeroPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category Chips ───────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final void Function(String) onSelect;

  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected ? AppGradients.primary : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                cat,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textLight,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  actionLabel!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Staggered Card Wrapper ───────────────────────────────────────────────

class _StaggeredCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredCard({required this.index, required this.child});

  @override
  State<_StaggeredCard> createState() => _StaggeredCardState();
}

class _StaggeredCardState extends State<_StaggeredCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 80), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}

// ─── Tall Poster Card (Recommended) ──────────────────────────────────────

class _PosterCard extends StatefulWidget {
  final EventModel event;
  final int index;
  final bool isAiPick;

  const _PosterCard({
    required this.event,
    required this.index,
    this.isAiPick = false,
  });

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _tapController;
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(widget.event.category);

    return GestureDetector(
      onTapDown: (_) => _tapController.reverse(),
      onTapUp: (_) {
        _tapController.forward();
        context.push(RoutePaths.eventDetail, extra: widget.event);
      },
      onTapCancel: () => _tapController.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 185,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: catColor.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                widget.event.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: widget.event.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: catColor.withValues(alpha: 0.1),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: catColor.withValues(alpha: 0.1),
                          child: Icon(
                            AppTheme.getCategoryIcon(widget.event.category),
                            color: catColor,
                            size: 50,
                          ),
                        ),
                      )
                    : Container(
                        color: catColor.withValues(alpha: 0.12),
                        child: Icon(
                          AppTheme.getCategoryIcon(widget.event.category),
                          color: catColor,
                          size: 50,
                        ),
                      ),

                // Full gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppGradients.cardOverlay),
                ),

                // Content at bottom
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isAiPick)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '✨ AI Pick',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Text(
                        widget.event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.event.category.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (widget.event.isHybrid) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'HYBRID',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ] else if (widget.event.isVirtual) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'VIRTUAL',
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              AppTheme.formatDate(widget.event.date),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Event List Card (Upcoming / Nearby) ─────────────────────────────────

class _EventListCard extends StatefulWidget {
  final EventModel event;

  const _EventListCard({required this.event});

  @override
  State<_EventListCard> createState() => _EventListCardState();
}

class _EventListCardState extends State<_EventListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(widget.event.category);

    return GestureDetector(
      onTapDown: (_) => _tapCtrl.reverse(),
      onTapUp: (_) {
        _tapCtrl.forward();
        context.push(RoutePaths.eventDetail, extra: widget.event);
      },
      onTapCancel: () => _tapCtrl.forward(),
      child: ScaleTransition(
        scale: _tapCtrl,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Container(
            decoration: AppDecorations.surfaceCard,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Colored left accent bar
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: catColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                    ),
                    // Event thumbnail
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: widget.event.imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.event.imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                color: catColor.withValues(alpha: 0.08),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: catColor.withValues(alpha: 0.08),
                                child: Icon(
                                  AppTheme.getCategoryIcon(
                                      widget.event.category),
                                  color: catColor,
                                  size: 30,
                                ),
                              ),
                            )
                          : Container(
                              color: catColor.withValues(alpha: 0.08),
                              child: Icon(
                                AppTheme.getCategoryIcon(widget.event.category),
                                color: catColor,
                                size: 30,
                              ),
                            ),
                    ),
                    // Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category pill
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.event.category.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: catColor,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                if (widget.event.isHybrid) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'HYBRID',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.purple,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ] else if (widget.event.isVirtual) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'VIRTUAL',
                                      style: GoogleFonts.inter(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.orange,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                                  AppTheme.formatDate(widget.event.date),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 11, color: AppColors.textLight),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.event.location,
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
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey.shade300,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bottom Nav ──────────────────────────────────────────────────────────

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppGradients.primary : null,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: isActive ? Colors.white : const Color(0xFF94A3B8)),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────

class _HorizontalShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.only(right: 14),
          child: _Shimmer(width: 185, height: 240, radius: 22),
        ),
      ),
    );
  }
}

class _VerticalShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _Shimmer(width: double.infinity, height: 95, radius: 20),
          ),
        ),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const _Shimmer(
      {required this.width, required this.height, required this.radius});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [
              Color.lerp(Colors.grey.shade200, Colors.grey.shade100, _c.value)!,
              Color.lerp(Colors.grey.shade100, Colors.grey.shade200, _c.value)!,
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;

  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppDecorations.surfaceCard,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppColors.textLight, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: AppDecorations.surfaceCard,
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label,
              style:
                  GoogleFonts.inter(color: AppColors.textLight, fontSize: 14)),
        ],
      ),
    );
  }
}

class _LocationDisabledCard extends StatelessWidget {
  final VoidCallback? onRetry;

  const _LocationDisabledCard({this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_off,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location disabled',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textDark),
                ),
                Text(
                  'Enable location to see events near you',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          if (onRetry != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: onRetry,
            ),
        ],
      ),
    );
  }
}
