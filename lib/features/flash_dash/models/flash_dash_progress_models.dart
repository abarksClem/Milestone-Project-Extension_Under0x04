class FlashDashProgressSession {
  final String id;
  final String listId;
  final String listTitle;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int durationMs;
  final int wordCount;
  final int totalAttempts;
  final int firstTryKnown;
  final bool completed;

  const FlashDashProgressSession({
    required this.id,
    required this.listId,
    required this.listTitle,
    required this.startedAt,
    required this.completedAt,
    required this.durationMs,
    required this.wordCount,
    required this.totalAttempts,
    required this.firstTryKnown,
    required this.completed,
  });

  double get firstTryPercentage {
    if (wordCount <= 0) return 0;
    return (firstTryKnown / wordCount) * 100;
  }

  int get additionalPracticeAttempts {
    final extra = totalAttempts - wordCount;
    return extra < 0 ? 0 : extra;
  }

  Duration get duration => Duration(milliseconds: durationMs);

  factory FlashDashProgressSession.fromMap(Map<String, dynamic> map) {
    final listRelation = map['word_lists'];
    String listTitle = 'Dolch List';

    if (listRelation is Map && listRelation['title'] != null) {
      listTitle = listRelation['title'].toString();
    } else if (listRelation is List && listRelation.isNotEmpty) {
      final first = listRelation.first;
      if (first is Map && first['title'] != null) {
        listTitle = first['title'].toString();
      }
    }

    return FlashDashProgressSession(
      id: _requiredString(map, 'id'),
      listId: _requiredString(map, 'list_id'),
      listTitle: listTitle,
      startedAt: _requiredDateTime(map, 'started_at'),
      completedAt: _optionalDateTime(map['completed_at']),
      durationMs: _requiredInt(map, 'duration_ms'),
      wordCount: _requiredInt(map, 'word_count'),
      totalAttempts: _requiredInt(map, 'total_attempts'),
      firstTryKnown: _requiredInt(map, 'first_try_known'),
      completed: map['completed'] == true,
    );
  }

  static String _requiredString(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString().trim();
    if (value == null || value.isEmpty) {
      throw FormatException('Missing Flash Dash session field: $key');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      throw FormatException('Invalid Flash Dash session field: $key');
    }
    return parsed;
  }

  static DateTime _requiredDateTime(
    Map<String, dynamic> map,
    String key,
  ) {
    final parsed = _optionalDateTime(map[key]);
    if (parsed == null) {
      throw FormatException('Invalid Flash Dash session field: $key');
    }
    return parsed;
  }

  static DateTime? _optionalDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

class FlashDashPracticedWord {
  final String wordId;
  final String text;
  final int practiceAgainCount;
  final int timeoutCount;

  const FlashDashPracticedWord({
    required this.wordId,
    required this.text,
    required this.practiceAgainCount,
    required this.timeoutCount,
  });

  int get totalPracticeAttempts => practiceAgainCount + timeoutCount;
}

class FlashDashProgressSnapshot {
  final List<FlashDashProgressSession> recentSessions;
  final List<FlashDashPracticedWord> mostPracticedWords;

  FlashDashProgressSnapshot({
    required List<FlashDashProgressSession> recentSessions,
    required List<FlashDashPracticedWord> mostPracticedWords,
  })  : recentSessions =
            List<FlashDashProgressSession>.unmodifiable(recentSessions),
        mostPracticedWords =
            List<FlashDashPracticedWord>.unmodifiable(mostPracticedWords);

  factory FlashDashProgressSnapshot.empty() {
    return FlashDashProgressSnapshot(
      recentSessions: const <FlashDashProgressSession>[],
      mostPracticedWords: const <FlashDashPracticedWord>[],
    );
  }

  int get completedSessionCount => recentSessions.length;

  int get totalWordsCleared => recentSessions.fold<int>(
        0,
        (total, session) => total + session.wordCount,
      );

  int get totalCardAttempts => recentSessions.fold<int>(
        0,
        (total, session) => total + session.totalAttempts,
      );

  int get totalFirstTryKnown => recentSessions.fold<int>(
        0,
        (total, session) => total + session.firstTryKnown,
      );

  double get firstTryPercentage {
    final words = totalWordsCleared;
    if (words == 0) return 0;
    return (totalFirstTryKnown / words) * 100;
  }

  Duration get averageCompletionTime {
    if (recentSessions.isEmpty) return Duration.zero;
    final totalMs = recentSessions.fold<int>(
      0,
      (total, session) => total + session.durationMs,
    );
    return Duration(milliseconds: totalMs ~/ recentSessions.length);
  }

  DateTime? get latestSessionAt =>
      recentSessions.isEmpty ? null : recentSessions.first.startedAt;
}
