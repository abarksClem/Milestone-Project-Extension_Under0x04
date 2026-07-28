import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flash_dash_progress_models.dart';
import 'flash_dash_progress_repository.dart';

typedef FlashDashCurrentUserIdProvider = String? Function();
typedef FlashDashProgressRowsLoader =
    Future<List<Map<String, dynamic>>> Function(String userId);

class SupabaseFlashDashProgressRepository
    implements FlashDashProgressRepository {
  final SupabaseClient? _client;
  final FlashDashCurrentUserIdProvider? _currentUserIdProvider;
  final FlashDashProgressRowsLoader? _sessionRowsLoader;
  final FlashDashProgressRowsLoader? _practiceRowsLoader;

  SupabaseFlashDashProgressRepository({
    SupabaseClient? client,
    FlashDashCurrentUserIdProvider? currentUserIdProvider,
    FlashDashProgressRowsLoader? sessionRowsLoader,
    FlashDashProgressRowsLoader? practiceRowsLoader,
  })  : _client = client,
        _currentUserIdProvider = currentUserIdProvider,
        _sessionRowsLoader = sessionRowsLoader,
        _practiceRowsLoader = practiceRowsLoader;

  @override
  Future<FlashDashProgressSnapshot> loadCurrentStudentProgress() async {
    final userId = _resolveCurrentUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw const FlashDashProgressRepositoryException(
        'Sign in to see your Flash Dash progress.',
      );
    }

    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        _loadSessionRows(userId),
        _loadPracticeRows(userId),
      ]);

      final sessions = results[0]
          .map(FlashDashProgressSession.fromMap)
          .where((session) => session.completed)
          .toList(growable: false)
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

      final practicedWords = _aggregatePracticedWords(results[1]);

      return FlashDashProgressSnapshot(
        recentSessions: sessions,
        mostPracticedWords: practicedWords,
      );
    } on FlashDashProgressRepositoryException {
      rethrow;
    } catch (error) {
      throw FlashDashProgressRepositoryException(
        'Flash Dash progress could not be loaded. Please try again.',
        cause: error,
      );
    }
  }

  String? _resolveCurrentUserId() {
    final provider = _currentUserIdProvider;
    if (provider != null) return provider();
    return (_client ?? Supabase.instance.client).auth.currentUser?.id;
  }

  Future<List<Map<String, dynamic>>> _loadSessionRows(String userId) async {
    final loader = _sessionRowsLoader;
    if (loader != null) return loader(userId);

    final response = await (_client ?? Supabase.instance.client)
        .from('flash_dash_sessions')
        .select(
          'id, list_id, started_at, completed_at, duration_ms, '
          'word_count, total_attempts, first_try_known, completed, '
          'word_lists(title)',
        )
        .eq('user_id', userId)
        .eq('completed', true)
        .order('started_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _loadPracticeRows(String userId) async {
    final loader = _practiceRowsLoader;
    if (loader != null) return loader(userId);

    final response = await (_client ?? Supabase.instance.client)
        .from('flash_dash_attempts')
        .select('word_id, result, words(text)')
        .eq('user_id', userId)
        .filter('result', 'in', '(practice_again,timeout)');

    return List<Map<String, dynamic>>.from(response);
  }

  List<FlashDashPracticedWord> _aggregatePracticedWords(
    List<Map<String, dynamic>> rows,
  ) {
    final grouped = <String, _MutablePracticeCounts>{};

    for (final row in rows) {
      final wordId = row['word_id']?.toString().trim();
      final result = row['result']?.toString();
      if (wordId == null || wordId.isEmpty) continue;
      if (result != 'practice_again' && result != 'timeout') continue;

      final text = _wordText(row['words']);
      final counts = grouped.putIfAbsent(
        wordId,
        () => _MutablePracticeCounts(wordId: wordId, text: text),
      );

      if (counts.text == 'Unknown word' && text != 'Unknown word') {
        counts.text = text;
      }

      if (result == 'timeout') {
        counts.timeoutCount += 1;
      } else {
        counts.practiceAgainCount += 1;
      }
    }

    final words = grouped.values
        .map(
          (counts) => FlashDashPracticedWord(
            wordId: counts.wordId,
            text: counts.text,
            practiceAgainCount: counts.practiceAgainCount,
            timeoutCount: counts.timeoutCount,
          ),
        )
        .toList();

    words.sort((a, b) {
      final byCount =
          b.totalPracticeAttempts.compareTo(a.totalPracticeAttempts);
      if (byCount != 0) return byCount;
      return a.text.toLowerCase().compareTo(b.text.toLowerCase());
    });

    return words.take(5).toList(growable: false);
  }

  String _wordText(dynamic relation) {
    if (relation is Map && relation['text'] != null) {
      final text = relation['text'].toString().trim();
      if (text.isNotEmpty) return text;
    }

    if (relation is List && relation.isNotEmpty) {
      final first = relation.first;
      if (first is Map && first['text'] != null) {
        final text = first['text'].toString().trim();
        if (text.isNotEmpty) return text;
      }
    }

    return 'Unknown word';
  }
}

class _MutablePracticeCounts {
  final String wordId;
  String text;
  int practiceAgainCount = 0;
  int timeoutCount = 0;

  _MutablePracticeCounts({
    required this.wordId,
    required this.text,
  });
}
