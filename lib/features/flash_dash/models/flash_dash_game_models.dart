import 'package:readright/models/word.dart';

enum FlashDashGameStatus {
  initial,
  ready,
  playing,
  paused,
  completed,
  error,
}

enum FlashDashAnswer {
  known,
  practiceAgain,
  timeout,
}

class FlashDashGameConfig {
  final Duration cardDuration;
  final int? selectedWordCount;
  final bool shuffleWords;
  final int? randomSeed;

  const FlashDashGameConfig({
    this.cardDuration = const Duration(seconds: 5),
    this.selectedWordCount,
    this.shuffleWords = false,
    this.randomSeed,
  });
}

class FlashDashTransition {
  final Word answeredWord;
  final FlashDashAnswer answer;
  final int attemptNumberForWord;
  final List<Word> activeQueueAfter;
  final Word? nextWord;
  final int completedWords;
  final int totalWords;
  final bool roundCompleted;

  FlashDashTransition({
    required this.answeredWord,
    required this.answer,
    required this.attemptNumberForWord,
    required List<Word> activeQueueAfter,
    required this.nextWord,
    required this.completedWords,
    required this.totalWords,
    required this.roundCompleted,
  }) : activeQueueAfter = List<Word>.unmodifiable(activeQueueAfter);
}

class FlashDashRoundSummary {
  final List<Word> originalRoundWords;
  final int completedWords;
  final int totalAnswerAttempts;
  final int totalSwipeAttempts;
  final int practiceAgainSwipeCount;
  final int timeoutCount;
  final Map<String, int> perWordAttemptCounts;
  final List<Word> wordsKnownOnFirstTry;
  final List<Word> wordsRequiringAdditionalPractice;
  final DateTime roundStartTime;
  final DateTime roundCompletionTime;

  FlashDashRoundSummary({
    required List<Word> originalRoundWords,
    required this.completedWords,
    required this.totalAnswerAttempts,
    required this.totalSwipeAttempts,
    required this.practiceAgainSwipeCount,
    required this.timeoutCount,
    required Map<String, int> perWordAttemptCounts,
    required List<Word> wordsKnownOnFirstTry,
    required List<Word> wordsRequiringAdditionalPractice,
    required this.roundStartTime,
    required this.roundCompletionTime,
  })  : originalRoundWords = List<Word>.unmodifiable(originalRoundWords),
        perWordAttemptCounts = Map<String, int>.unmodifiable(
          perWordAttemptCounts,
        ),
        wordsKnownOnFirstTry = List<Word>.unmodifiable(wordsKnownOnFirstTry),
        wordsRequiringAdditionalPractice = List<Word>.unmodifiable(
          wordsRequiringAdditionalPractice,
        );

  Duration get elapsedTime => roundCompletionTime.difference(roundStartTime);
}
