import '../models/event_model.dart';

class RecommendationService {
  /// Returns a sorted list of the top 5 recommended Event IDs based on a rule-based scoring system.
  List<String> getRecommendedEventIds({
    required List<String> userViewedCategories,
    required List<String> userSavedCategories,
    required List<String> userCategories,
    required List<EventModel> availableEvents,
  }) {
    if (availableEvents.isEmpty) {
      return [];
    }

    // 1. Initialize scores
    Map<String, int> scores = {};
    for (var event in availableEvents) {
      scores[event.id] = 0;
    }

    // Normalize user preferences to lowercase for safe comparison
    final normalizedUserPrefs = userCategories.map((c) => c.toLowerCase()).toList();

    // 2. Rule 1: User Preferences (+10 points)
    for (var event in availableEvents) {
      if (normalizedUserPrefs.contains(event.category.toLowerCase())) {
        scores[event.id] = (scores[event.id] ?? 0) + 10;
      }
    }

    // 3. Rule 2: Saved Behavior (+5 points per save of the same category)
    Map<String, int> savedCatCounts = {};
    for (var c in userSavedCategories) {
      final key = c.toLowerCase();
      savedCatCounts[key] = (savedCatCounts[key] ?? 0) + 1;
    }
    for (var event in availableEvents) {
      int saves = savedCatCounts[event.category.toLowerCase()] ?? 0;
      scores[event.id] = (scores[event.id] ?? 0) + (saves * 5);
    }

    // 4. Rule 3: Viewed Behavior (+2 points per view of the same category)
    Map<String, int> viewedCatCounts = {};
    for (var c in userViewedCategories) {
      final key = c.toLowerCase();
      viewedCatCounts[key] = (viewedCatCounts[key] ?? 0) + 1;
    }
    for (var event in availableEvents) {
      int views = viewedCatCounts[event.category.toLowerCase()] ?? 0;
      scores[event.id] = (scores[event.id] ?? 0) + (views * 2);
    }

    // 5. Rule 4: Urgency
    final now = DateTime.now();
    for (var event in availableEvents) {
      final diff = event.date.difference(now).inDays;
      if (diff >= 0 && diff <= 30) {
        scores[event.id] = (scores[event.id] ?? 0) + 5;
      } else if (diff > 30 && diff <= 60) {
        scores[event.id] = (scores[event.id] ?? 0) + 3;
      } else if (diff > 60 && diff <= 90) {
        scores[event.id] = (scores[event.id] ?? 0) + 1;
      }
    }

    // 6. Sort and return top 5
    var sortedEvents = availableEvents.toList();
    sortedEvents.sort((a, b) {
      int scoreA = scores[a.id] ?? 0;
      int scoreB = scores[b.id] ?? 0;
      if (scoreB != scoreA) {
        return scoreB.compareTo(scoreA); // Descending order of score
      } else {
        // Tie-breaker: Soonest date first
        return a.date.compareTo(b.date);
      }
    });

    return sortedEvents.take(5).map((e) => e.id).toList();
  }
}
