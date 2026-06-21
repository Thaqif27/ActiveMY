import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/event_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import 'admin_layout.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {

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
            backgroundColor: AppColors.darkBg,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }

        final userProfile = authSnapshot.data;
        if (userProfile == null || !userProfile.isAdmin) {
          return _buildAccessDenied(context);
        }

        return StreamBuilder<List<EventModel>>(
          stream: firestore.streamAllEvents(),
          builder: (context, eventsSnapshot) {
            return StreamBuilder<List<UserModel>>(
              stream: firestore.streamAllUsers(),
              builder: (context, usersSnapshot) {
                if ((eventsSnapshot.connectionState == ConnectionState.waiting && !eventsSnapshot.hasData) ||
                    (usersSnapshot.connectionState == ConnectionState.waiting && !usersSnapshot.hasData)) {
                  return const Scaffold(
                    backgroundColor: AppColors.darkBg,
                    body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  );
                }

                final events = eventsSnapshot.data ?? [];
                final users = usersSnapshot.data ?? [];

                final totalEvents = events.length;
                final activeEvents = events.where((e) => e.isActive).length;
                final totalUsers = users.length;

                final runningCount = events.where((e) => e.category.toLowerCase() == 'running').length;
                final cyclingCount = events.where((e) => e.category.toLowerCase() == 'cycling').length;
                final hikingCount = events.where((e) => e.category.toLowerCase() == 'hiking').length;

                final maxCount = [runningCount, cyclingCount, hikingCount]
                    .reduce((curr, next) => curr > next ? curr : next);

                return AdminLayout(
                  activeRoute: RoutePaths.adminDashboard,
                  title: 'Dashboard Overview',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Main Scroll View
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Row
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome Back, Admin! 👋',
                                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: -1.5,
                                        ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Here is what\'s happening with ActiveMY today.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Key Metrics Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      'Total Users',
                                      totalUsers.toString(),
                                      Icons.group,
                                      Colors.blueAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      'Active Events',
                                      activeEvents.toString(),
                                      Icons.event_available,
                                      Colors.greenAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildStatCard(
                                      context,
                                      'Total Ingested',
                                      totalEvents.toString(),
                                      Icons.storage,
                                      Colors.orangeAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Quick Chart Area
                              Text(
                                'Events by Category',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 320,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                                decoration: AppDecorations.glassCard.copyWith(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxCount.toDouble() + 5,
                                    barTouchData: BarTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            switch (value.toInt()) {
                                              case 0:
                                                return const Padding(
                                                  padding: EdgeInsets.only(top: 8),
                                                  child: Text('RUNNING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                );
                                              case 1:
                                                return const Padding(
                                                  padding: EdgeInsets.only(top: 8),
                                                  child: Text('CYCLING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                );
                                              case 2:
                                                return const Padding(
                                                  padding: EdgeInsets.only(top: 8),
                                                  child: Text('HIKING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                                                );
                                              default:
                                                return const Text('');
                                            }
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                          getTitlesWidget: (value, meta) {
                                            return Text(value.toInt().toString(), style: const TextStyle(color: Colors.white70));
                                          },
                                        ),
                                      ),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    borderData: FlBorderData(show: false),
                                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                                    barGroups: [
                                      BarChartGroupData(
                                        x: 0,
                                        barRods: [
                                          BarChartRodData(
                                            toY: runningCount.toDouble(),
                                            color: AppColors.running,
                                            width: 32,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 1,
                                        barRods: [
                                          BarChartRodData(
                                            toY: cyclingCount.toDouble(),
                                            color: AppColors.cycling,
                                            width: 32,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                      BarChartGroupData(
                                        x: 2,
                                        barRods: [
                                          BarChartRodData(
                                            toY: hikingCount.toDouble(),
                                            color: AppColors.hiking,
                                            width: 32,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return _HoverStatCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: AppDecorations.glassCard,
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

class _HoverStatCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HoverStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_HoverStatCard> createState() => _HoverStatCardState();
}

class _HoverStatCardState extends State<_HoverStatCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: _isHovering ? Matrix4.translationValues(0.0, -6.0, 0.0) : Matrix4.identity(),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                borderRadius: BorderRadius.circular(24),
                boxShadow: _isHovering
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background huge icon
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      widget.icon,
                      size: 140,
                      color: widget.color.withValues(alpha: 0.04),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Pill Label
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: widget.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  widget.label.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: widget.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Small glowing icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(widget.icon, color: widget.color, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Value
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.value,
                          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1.5,
                              ),
                        ),
                      ),
                    ],
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
