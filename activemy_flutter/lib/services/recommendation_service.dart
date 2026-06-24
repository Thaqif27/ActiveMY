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
    required List<Map<String, String>> availableEvents,
  }) async {
    final availableEventIds = availableEvents.map((e) => e['id']!).toList();
    if (_apiKey.isEmpty || availableEventIds.isEmpty) {
      return availableEventIds.take(5).toList();
    }

    try {
      final prompt = _buildPrompt(
        viewedEvents: userViewedEvents,
        savedEvents: userSavedEvents,
        categories: userCategories,
        availableEvents: availableEvents,
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
    required List<Map<String, String>> availableEvents,
  }) {
    final availableEventsString = availableEvents.map((e) => '- ID: ${e['id']} | Category: ${e['category']} | Title: ${e['title']}').join('\n');
    
    return '''You are a sports event recommendation engine. Based on the user's activity and preferences, recommend the best events for them.

User Information:
- Preferred categories: $categories
- Events viewed (IDs): ${viewedEvents.isEmpty ? 'None' : viewedEvents.join(', ')}
- Events saved (IDs): ${savedEvents.isEmpty ? 'None' : savedEvents.join(', ')}

Available events to choose from:
$availableEventsString

Please recommend the top 5 most relevant event IDs from the available list. Consider:
1. Match with user's preferred categories
2. Similar to events they've viewed/saved
3. Variety in event types

Return ONLY the 5 event IDs as a comma-separated list, nothing else. Do not include any explanation or intro text.
Example format: event_id_1,event_id_2,event_id_3,event_id_4,event_id_5''';
  }

  List<String> _parseRecommendations(String response, List<String> availableIds) {
    try {
      // Remove any hallucinated intro texts
      var cleanResponse = response.replaceAll(RegExp(r'```[a-zA-Z]*'), '').replaceAll('`', '').trim();
      final recommended = cleanResponse
          .split(RegExp(r'[,\n]'))
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
