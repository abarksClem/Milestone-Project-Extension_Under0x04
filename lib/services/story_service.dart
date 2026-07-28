import 'package:supabase_flutter/supabase_flutter.dart';

class StoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> generateStory({
    required String student,
    required String readingLevel,
    required String interest,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'generate-story',
        body: {
          'student': student,
          'readingLevel': readingLevel,
          'interest': interest,
        },
      );

      if (response.status != 200) {
        throw Exception(
          response.data?['error'] ??
              'Failed to generate story (${response.status})',
        );
      }

      if (response.data == null) {
        throw Exception('No data returned from the server.');
      }

      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Story generation failed: $e');
    }
  }
}