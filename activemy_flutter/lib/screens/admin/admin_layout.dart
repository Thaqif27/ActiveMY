import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../../services/auth_service.dart';
import '../../utils/theme.dart';
import '../../utils/constants.dart';

class AdminLayout extends StatefulWidget {
  final Widget child;
  final String activeRoute;
  final String title;

  const AdminLayout({
    super.key,
    required this.child,
    required this.activeRoute,
    required this.title,
  });

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  @override
  void initState() {
    super.initState();
  }

  void _handleLogout() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    await authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppAdminColors.bgDark,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: AppAdminColors.textMain,
          displayColor: AppAdminColors.textMain,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F172A), // Slate 900
                Color(0xFF020617), // Slate 950
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              // Sidebar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      width: 280,
                      decoration: BoxDecoration(
                        color: AppAdminColors.cardDark.withValues(alpha: 0.5),
                        border: Border.all(color: AppAdminColors.border, width: 1.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 32),
                          // Brand Logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppAdminColors.primaryNeon.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppAdminColors.primaryNeon.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.flash_on, color: AppAdminColors.primaryNeon, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'ActiveMY',
                                style: GoogleFonts.outfit(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),
                          // Menu Items
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              children: [
                                _HoverSidebarItem(
                                  icon: Icons.dashboard_rounded,
                                  title: 'Dashboard',
                                  isActive: widget.activeRoute == RoutePaths.adminDashboard,
                                  onTap: () => context.go(RoutePaths.adminDashboard),
                                ),
                                const SizedBox(height: 8),
                                _HoverSidebarItem(
                                  icon: Icons.map_rounded,
                                  title: 'Map Data',
                                  isActive: widget.activeRoute == RoutePaths.adminMap,
                                  onTap: () => context.go(RoutePaths.adminMap),
                                ),
                                const SizedBox(height: 8),
                                _HoverSidebarItem(
                                  icon: Icons.event_rounded,
                                  title: 'Manage Events',
                                  isActive: widget.activeRoute == RoutePaths.adminEvents,
                                  onTap: () => context.go(RoutePaths.adminEvents),
                                ),
                                const SizedBox(height: 8),
                                _HoverSidebarItem(
                                  icon: Icons.new_releases_rounded,
                                  title: 'Newly Scraped',
                                  isActive: widget.activeRoute == RoutePaths.adminScrapedEvents,
                                  onTap: () => context.go(RoutePaths.adminScrapedEvents),
                                ),
                                const SizedBox(height: 8),
                                _HoverSidebarItem(
                                  icon: Icons.smart_toy_rounded,
                                  title: 'Scraper',
                                  isActive: widget.activeRoute == RoutePaths.adminScraper,
                                  onTap: () => context.go(RoutePaths.adminScraper),
                                ),
                                const SizedBox(height: 8),
                                _HoverSidebarItem(
                                  icon: Icons.people_rounded,
                                  title: 'Users',
                                  isActive: widget.activeRoute == RoutePaths.adminUsers,
                                  onTap: () => context.go(RoutePaths.adminUsers),
                                ),
                              ],
                            ),
                          ),
                          // User Profile at bottom
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                // Logout Button
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    border: Border(top: BorderSide(color: AppAdminColors.border)),
                                  ),
                                  child: TextButton.icon(
                                    onPressed: _handleLogout,
                                    icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
                                    label: const Text('Sign Out', style: TextStyle(color: Colors.white54)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      alignment: Alignment.centerLeft,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      color: AppAdminColors.cardDark.withValues(alpha: 0.8),
                      child: Column(
                        children: [
                          // Top Header Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            decoration: const BoxDecoration(
                              color: AppAdminColors.cardDark,
                              border: Border(bottom: BorderSide(color: AppAdminColors.border)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Welcome back, manage your system here.',
                                      style: TextStyle(color: AppAdminColors.textSub),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Page Content
                          Expanded(
                            child: widget.child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoverSidebarItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _HoverSidebarItem({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_HoverSidebarItem> createState() => _HoverSidebarItemState();
}

class _HoverSidebarItemState extends State<_HoverSidebarItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          decoration: BoxDecoration(
            color: widget.isActive 
                ? AppAdminColors.primaryNeon.withValues(alpha: 0.15) 
                : (_isHovering ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isActive 
                  ? AppAdminColors.primaryNeon.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            boxShadow: widget.isActive ? [
              BoxShadow(
                color: AppAdminColors.primaryNeon.withValues(alpha: 0.2),
                blurRadius: 12,
              )
            ] : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon, 
                color: widget.isActive ? AppAdminColors.primaryNeon : (_isHovering ? Colors.white : AppAdminColors.textSub), 
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                widget.title,
                style: TextStyle(
                  color: widget.isActive ? Colors.white : (_isHovering ? Colors.white : AppAdminColors.textSub),
                  fontSize: 15,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
