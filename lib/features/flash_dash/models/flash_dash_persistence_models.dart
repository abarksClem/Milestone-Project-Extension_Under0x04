import 'flash_dash_game_models.dart';

enum FlashDashResultSaveStatus {
  notStarted,
  saving,
  saved,
  failed,
}

class FlashDashPersistedAttempt {
  final String wordId;
  final int sequenceNumber;
  final FlashDashAnswer result;
  final int elapsedMs;

  const FlashDashPersistedAttempt({
    required this.wordId,
    required this.sequenceNumber,
    required this.result,
    required this.elapsedMs,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'word_id': wordId,
        'sequence_number': sequenceNumber,
        'result': _resultValue(result),
        'elapsed_ms': elapsedMs,
      };

  static String _resultValue(FlashDashAnswer answer) {
    switch (answer) {
      case FlashDashAnswer.known:
        return 'known';
      case FlashDashAnswer.practiceAgain:
        return 'practice_again';
      case FlashDashAnswer.timeout:
        return 'timeout';
    }
  }
}

class FlashDashSessionSaveRequest {
  final String sessionId;
  final String listId;
  final DateTime startedAt;
  final DateTime completedAt;
  final int durationMs;
  final int wordCount;
  final int totalAttempts;
  final int firstTryKnown;
  final bool completed;
  final List<FlashDashPersistedAttempt> attempts;

  FlashDashSessionSaveRequest({
    required this.sessionId,
    required this.listId,
    required this.startedAt,
    required this.completedAt,
    required this.durationMs,
    required this.wordCount,
    required this.totalAttempts,
    required this.firstTryKnown,
    required this.completed,
    required List<FlashDashPersistedAttempt> attempts,
  }) : attempts = List<FlashDashPersistedAttempt>.unmodifiable(attempts) {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId', 'Must not be empty.');
    }
    if (listId.trim().isEmpty) {
      throw ArgumentError.value(listId, 'listId', 'Must not be empty.');
    }
    if (durationMs < 0) {
      throw ArgumentError.value(durationMs, 'durationMs', 'Must be nonnegative.');
    }
    if (wordCount <= 0) {
      throw ArgumentError.value(wordCount, 'wordCount', 'Must be positive.');
    }
    if (totalAttempts != attempts.length) {
      throw ArgumentError(
        'totalAttempts must equal the number of attempt records.',
      );
    }
    if (firstTryKnown < 0 || firstTryKnown > wordCount) {
      throw ArgumentError.value(
        firstTryKnown,
        'firstTryKnown',
        'Must be between zero and wordCount.',
      );
    }
    if (completedAt.isBefore(startedAt)) {
      throw ArgumentError('completedAt cannot be before startedAt.');
    }
  }

  factory FlashDashSessionSaveRequest.fromSummary({
    required String sessionId,
    required String listId,
    required FlashDashRoundSummary summary,
  }) {
    final attempts = summary.attemptEvents
        .map(
          (event) => FlashDashPersistedAttempt(
            wordId: event.word.id,
            sequenceNumber: event.sequenceNumber,
            result: event.result,
            elapsedMs: event.elapsed.inMilliseconds,
          ),
        )
        .toList(growable: false);

    return FlashDashSessionSaveRequest(
      sessionId: sessionId,
      listId: listId,
      startedAt: summary.roundStartTime,
      completedAt: summary.roundCompletionTime,
      durationMs: summary.elapsedTime.inMilliseconds,
      wordCount: summary.originalRoundWords.length,
      totalAttempts: summary.totalAnswerAttempts,
      firstTryKnown: summary.wordsKnownOnFirstTry.length,
      completed: true,
      attempts: attempts,
    );
  }

  Map<String, dynamic> toRpcParameters() => <String, dynamic>{
        'p_session_id': sessionId,
        'p_list_id': listId,
        'p_started_at': startedAt.toUtc().toIso8601String(),
        'p_completed_at': completedAt.toUtc().toIso8601String(),
        'p_duration_ms': durationMs,
        'p_word_count': wordCount,
        'p_total_attempts': totalAttempts,
        'p_first_try_known': firstTryKnown,
        'p_completed': completed,
        'p_attempts': attempts.map((attempt) => attempt.toJson()).toList(),
      };
}

class FlashDashSavedSession {
  final String sessionId;

  const FlashDashSavedSession(this.sessionId);
}
