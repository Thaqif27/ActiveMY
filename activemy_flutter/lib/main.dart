import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'models/event_model.dart';
import 'screens/event_detail_screen.dart';
import 'screens/event_chat_screen.dart';
import 'screens/private_chat_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_map_screen.dart';
import 'screens/admin/admin_events_screen.dart';
import 'screens/admin/admin_users_screen.dart';
import 'screens/admin/admin_scraper_screen.dart';
import 'screens/admin/admin_scraped_events_screen.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'utils/constants.dart';
import 'utils/theme.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Catch initialization errors if already initialized or issues in testing
    debugPrint('Firebase initialization warning: $e');
  }
  runApp(const ActiveMYApp());
}

class ActiveMYApp extends StatefulWidget {
  const ActiveMYApp({super.key});

  @override
  State<ActiveMYApp> createState() => _ActiveMYAppState();
}

class _ActiveMYAppState extends State<ActiveMYApp> {
  final GoRouter _router = GoRouter(
    initialLocation: RoutePaths.splash,
    routes: [
      GoRoute(
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RoutePaths.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: RoutePaths.map,
        builder: (context, state) => const MapScreen(),
      ),
      GoRoute(
        path: RoutePaths.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: RoutePaths.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: RoutePaths.eventDetail,
        builder: (context, state) {
          final event = state.extra as EventModel;
          return EventDetailScreen(event: event);
        },
      ),
      GoRoute(
        path: RoutePaths.eventChat,
        builder: (context, state) {
          final event = state.extra as EventModel;
          return EventChatScreen(event: event);
        },
      ),
      GoRoute(
        path: RoutePaths.privateChat,
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final otherUserId = state.extra as String;
          return PrivateChatScreen(chatId: chatId, otherUserId: otherUserId);
        },
      ),
      GoRoute(
        path: RoutePaths.inbox,
        builder: (context, state) => const InboxScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminDashboard,
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: RoutePaths.adminMap,
        builder: (context, state) => const AdminMapScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminEvents,
        builder: (context, state) => const AdminEventsScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminUsers,
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminScraper,
        builder: (context, state) => const AdminScraperScreen(),
      ),
      GoRoute(
        path: RoutePaths.adminScrapedEvents,
        builder: (context, state) => const AdminScrapedEventsScreen(),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        Provider<FirestoreService>(
          create: (_) => FirestoreService(),
        ),
        ProxyProvider<FirestoreService, NotificationService>(
          update: (_, firestore, __) => NotificationService(firestoreService: firestore),
        ),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
