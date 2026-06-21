import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/constants.dart';

class RecommendationService {
  static const String _apiKey = AppConstants.groqApiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<List<String>> getRecommendedEventIds({
    required List<String> userViewedEvents,
    required List<String> userSavedEvents,
    required List<String> userCategories,
    required List<String> availableEventIds,
  }) async {
    if (_apiKey.isEmpty || availableEventIds.isEmpty) {
      return availableEventIds.take(5).toList();
    }

    try {
      final prompt = _buildPrompt(
        viewedEvents: userViewedEvents,
        savedEvents: userSavedEvents,
        categories: userCategories,
        availableEvents: availableEventIds,
      );

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return _parseRecommendations(content, availableEventIds);
      } else {
        return availableEventIds.take(5).toList();
      }
    } catch (e) {
      return availableEventIds.take(5).toList();
    }
  }

  String _buildPrompt({
    required List<String> viewedEvents,
    required List<String> savedEvents,
    required List<String> categories,
    required List<String> availableEvents,
  }) {
    return '''You are a sports event recommendation engine. Based on the user's activity and preferences, recommend the best events for them.

User Information:
- Preferred categories: $categories
- Events viewed: ${viewedEvents.isEmpty ? 'None' : viewedEvents.join(', ')}
- Events saved: ${savedEvents.isEmpty ? 'None' : savedEvents.join(', ')}

Available event IDs to choose from:
${availableEvents.join(', ')}

Please recommend the top 5 most relevant event IDs from the available list. Consider:
1. Match with user's preferred categories
2. Similar to events they've viewed/saved
3. Variety in event types

Return ONLY the 5 event IDs as a comma-separated list, nothing else.
Example format: event_id_1,event_id_2,event_id_3,event_id_4,event_id_5''';
  }

  List<String> _parseRecommendations(String response, List<String> availableIds) {
    try {
      final recommended = response
          .trim()
          .split(',')
          .map((id) => id.trim())
          .where((id) => availableIds.contains(id))
          .take(5)
          .toList();

      if (recommended.length < 5) {
        for (final id in availableIds) {
          if (!recommended.contains(id)) {
            recommended.add(id);
            if (recommended.length >= 5) break;
          }
        }
      }

      return recommended.take(5).toList();
    } catch (e) {
      return availableIds.take(5).toList();
    }
  }
}
