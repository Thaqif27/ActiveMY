class AppConstants {
  static const String appName = 'ActiveMY';
  static const List<String> categories = ['Running', 'Cycling', 'Hiking', 'Virtual', 'Hybrid'];
  static const double defaultRadiusKm = 50;
  static const List<double> radiusOptionsKm = [10, 50, 100, double.infinity];
  static const int maxRecommendations = 5;
  static const Duration behaviorLookback = Duration(days: 30);
  
  // Inject with --dart-define=GOOGLE_MAPS_API_KEY=...
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  // Inject with --dart-define=GROQ_API_KEY=...
  static const String groqApiKey = '';
  static const String scraperUrl = 'https://goldfish-app-n6w8a.ondigitalocean.app';
}

class FirestoreCollections {
  static const String events = 'events';
  static const String users = 'users';
  static const String userBehavior = 'user_behavior';
  static const String notifications = 'notifications';
  static const String favorites = 'favorites';
}

class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String map = '/map';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String eventDetail = '/event/:id';
  static const String eventChat = '/event/:id/chat';
  static const String privateChat = '/chat/:chatId';
  static const String inbox = '/inbox';
  
  static const String adminDashboard = '/admin/dashboard';
  static const String adminMap = '/admin/map';
  static const String adminEvents = '/admin/events';
  static const String adminUsers = '/admin/users';
  static const String adminScraper = '/admin/scraper';
  static const String adminScrapedEvents = '/admin/scraped-events';
}
