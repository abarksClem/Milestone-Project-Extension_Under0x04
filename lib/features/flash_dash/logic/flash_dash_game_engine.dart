import 'dart:math';

import 'package:readright/models/word.dart';

import '../models/flash_dash_game_models.dart';

typedef FlashDashClock = DateTime Function();

class FlashDashGameEngine {
  final FlashDashGameConfig config;
  final FlashDashClock _clock;
  final Random? _injectedRandom;

  FlashDashGameStatus _status = FlashDashGameStatus.initial;
  String? _errorMessage;
  bool _isTransitionProcessing = false;

  List<Word> _originalRoundWords = const <Word>[];
  final List<Word> _activeQueue = <Word>[];
  final Set<String> _clearedWordIds = <String>{};
  final Map<String, int> _perWordAttemptCounts = <String, int>{};
  final Set<String> _firstTryWordIds = <String>{};
  final Set<String> _additionalPracticeWordIds = <String>{};
  final List<FlashDashAttemptEvent> _attemptEvents =
  <FlashDashAttemptEvent>[];

  int _totalAnswerAttempts = 0;
  int _totalSwipeAttempts = 0;
  int _practiceAgainSwipeCount = 0;
  int _timeoutCount = 0;

  DateTime? _roundStartTime;
  DateTime? _roundCompletionTime;

  FlashDashGameEngine({
    this.config = const FlashDashGameConfig(),
    FlashDashClock? clock,
    Random? random,
  })  : _clock = clock ?? DateTime.now,
        _injectedRandom = random;

  FlashDashGameStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isTransitionProcessing => _isTransitionProcessing;

  Duration get cardDuration => config.cardDuration;
  int get selectedWordCount => _originalRoundWords.length;
  int get completedWords => _clearedWordIds.length;
  int get totalAnswerAttempts => _totalAnswerAttempts;
  int get totalSwipeAttempts => _totalSwipeAttempts;
  int get practiceAgainSwipeCount => _practiceAgainSwipeCount;
  int get timeoutCount => _timeoutCount;

  DateTime? get roundStartTime => _roundStartTime;
  DateTime? get roundCompletionTime => _roundCompletionTime;

  Word? get currentWord => _activeQueue.isEmpty ? null : _activeQueue.first;

  List<Word> get originalRoundWords =>
      List<Word>.unmodifiable(_originalRoundWords);

  List<Word> get activeQueue => List<Word>.unmodifiable(_activeQueue);

  Map<String, int> get perWordAttemptCounts =>
      Map<String, int>.unmodifiable(_perWordAttemptCounts);

  List<FlashDashAttemptEvent> get attemptEvents =>
      List<FlashDashAttemptEvent>.unmodifiable(_attemptEvents);

  List<Word> get wordsKnownOnFirstTry => List<Word>.unmodifiable(
    _originalRoundWords.where(
          (word) => _firstTryWordIds.contains(word.id),
    ),
  );

  List<Word> get wordsRequiringAdditionalPractice => List<Word>.unmodifiable(
    _originalRoundWords.where(
          (word) => _additionalPracticeWordIds.contains(word.id),
    ),
  );

  bool initialize(List<Word> words) {
    if (_status != FlashDashGameStatus.initial) {
      return _fail(
        'Flash Dash can only be initialized once. Create a new engine for a new round.',
      );
    }

    if (config.cardDuration.inMilliseconds <= 0) {
      return _fail('Card duration must be greater than zero.');
    }

    if (words.isEmpty) {
      return _fail('Flash Dash requires at least one word to start a round.');
    }

    final requestedCount = config.selectedWordCount ?? words.length;
    if (requestedCount <= 0) {
      return _fail('Selected word count must be greater than zero.');
    }
    if (requestedCount > words.length) {
      return _fail(
        'Selected word count ($requestedCount) exceeds the available word count (${words.length}).',
      );
    }

    final copiedWords = words.map(_copyWord).toList(growable: false);
    final ids = <String>{};
    final normalizedTexts = <String>{};

    for (final word in copiedWords) {
      final id = word.id.trim();
      final normalizedText = word.text.trim().toLowerCase();

      if (id.isEmpty) {
        return _fail('Every Flash Dash word must have a non-empty id.');
      }
      if (normalizedText.isEmpty) {
        return _fail('Every Flash Dash word must have non-empty text.');
      }
      if (!ids.add(id)) {
        return _fail('Duplicate Flash Dash word id detected: $id');
      }
      if (!normalizedTexts.add(normalizedText)) {
        return _fail(
          'Duplicate Flash Dash word text detected: ${word.text}',
        );
      }
    }

    final orderedWords = List<Word>.from(copiedWords);
    if (config.shuffleWords) {
      final random = _injectedRandom ?? Random(config.randomSeed);
      orderedWords.shuffle(random);
    }

    _originalRoundWords = List<Word>.unmodifiable(
      orderedWords.take(requestedCount).map(_copyWord),
    );

    _activeQueue
      ..clear()
      ..addAll(_originalRoundWords.map(_copyWord));

    _perWordAttemptCounts
      ..clear()
      ..addEntries(
        _originalRoundWords.map(
              (word) => MapEntry<String, int>(word.id, 0),
        ),
      );

    _clearedWordIds.clear();
    _firstTryWordIds.clear();
    _additionalPracticeWordIds.clear();
    _attemptEvents.clear();
    _totalAnswerAttempts = 0;
    _totalSwipeAttempts = 0;
    _practiceAgainSwipeCount = 0;
    _timeoutCount = 0;
    _roundStartTime = null;
    _roundCompletionTime = null;
    _errorMessage = null;
    _isTransitionProcessing = false;
    _status = FlashDashGameStatus.ready;

    return _verifyInvariants();
  }

  bool start() {
    if (_status != FlashDashGameStatus.ready || _activeQueue.isEmpty) {
      return false;
    }

    _roundStartTime = _clock();
    _status = FlashDashGameStatus.playing;
    return true;
  }

  bool pause() {
    if (_status != FlashDashGameStatus.playing || _isTransitionProcessing) {
      return false;
    }

    _status = FlashDashGameStatus.paused;
    return true;
  }

  bool resume() {
    if (_status != FlashDashGameStatus.paused) {
      return false;
    }

    _status = FlashDashGameStatus.playing;
    return true;
  }

  FlashDashTransition? submitKnown({Duration elapsed = Duration.zero}) =>
      submitAnswer(FlashDashAnswer.known, elapsed: elapsed);

  FlashDashTransition? submitPracticeAgain({
    Duration elapsed = Duration.zero,
  }) =>
      submitAnswer(FlashDashAnswer.practiceAgain, elapsed: elapsed);

  FlashDashTransition? submitTimeout({Duration? elapsed}) => submitAnswer(
    FlashDashAnswer.timeout,
    elapsed: elapsed ?? config.cardDuration,
  );

  FlashDashTransition? submitAnswer(
      FlashDashAnswer answer, {
        Duration elapsed = Duration.zero,
      }) {
    if (_status != FlashDashGameStatus.playing ||
        _isTransitionProcessing ||
        _activeQueue.isEmpty) {
      return null;
    }

    if (elapsed.isNegative) {
      _fail('Attempt elapsed time cannot be negative.');
      return null;
    }

    _isTransitionProcessing = true;

    final answeredWord = _activeQueue.removeAt(0);
    final attemptNumber = (_perWordAttemptCounts[answeredWord.id] ?? 0) + 1;
    _perWordAttemptCounts[answeredWord.id] = attemptNumber;
    _totalAnswerAttempts += 1;

    switch (answer) {
      case FlashDashAnswer.known:
        _totalSwipeAttempts += 1;

        if (!_clearedWordIds.add(answeredWord.id)) {
          _fail('A cleared word was encountered more than once.');
          return null;
        }

        if (attemptNumber == 1) {
          _firstTryWordIds.add(answeredWord.id);
        } else {
          _additionalPracticeWordIds.add(answeredWord.id);
        }
        break;

      case FlashDashAnswer.practiceAgain:
        _totalSwipeAttempts += 1;
        _practiceAgainSwipeCount += 1;
        _additionalPracticeWordIds.add(answeredWord.id);
        _activeQueue.add(answeredWord);
        break;

      case FlashDashAnswer.timeout:
        _timeoutCount += 1;
        _additionalPracticeWordIds.add(answeredWord.id);
        _activeQueue.add(answeredWord);
        break;
    }

    _attemptEvents.add(
      FlashDashAttemptEvent(
        sequenceNumber: _totalAnswerAttempts,
        word: answeredWord,
        result: answer,
        attemptNumberForWord: attemptNumber,
        elapsed: elapsed,
      ),
    );

    if (_activeQueue.isEmpty) {
      _roundCompletionTime = _clock();
      _status = FlashDashGameStatus.completed;
    }

    if (!_verifyInvariants()) {
      return null;
    }

    return FlashDashTransition(
      answeredWord: _copyWord(answeredWord),
      answer: answer,
      attemptNumberForWord: attemptNumber,
      activeQueueAfter: _activeQueue.map(_copyWord).toList(growable: false),
      nextWord: currentWord == null ? null : _copyWord(currentWord!),
      completedWords: completedWords,
      totalWords: selectedWordCount,
      roundCompleted: _status == FlashDashGameStatus.completed,
    );
  }

  bool completeTransition() {
    if (!_isTransitionProcessing) {
      return false;
    }

    _isTransitionProcessing = false;
    return true;
  }

  FlashDashRoundSummary? get summary {
    if (_status != FlashDashGameStatus.completed ||
        _roundStartTime == null ||
        _roundCompletionTime == null) {
      return null;
    }

    return FlashDashRoundSummary(
      originalRoundWords: _originalRoundWords.map(_copyWord).toList(),
      completedWords: completedWords,
      totalAnswerAttempts: _totalAnswerAttempts,
      totalSwipeAttempts: _totalSwipeAttempts,
      practiceAgainSwipeCount: _practiceAgainSwipeCount,
      timeoutCount: _timeoutCount,
      perWordAttemptCounts: _perWordAttemptCounts,
      wordsKnownOnFirstTry: wordsKnownOnFirstTry.map(_copyWord).toList(),
      wordsRequiringAdditionalPractice:
      wordsRequiringAdditionalPractice.map(_copyWord).toList(),
      attemptEvents: _attemptEvents,
      roundStartTime: _roundStartTime!,
      roundCompletionTime: _roundCompletionTime!,
    );
  }

  bool _verifyInvariants() {
    final originalIds = _originalRoundWords.map((word) => word.id).toSet();
    final queueIds = _activeQueue.map((word) => word.id).toList();
    final queueIdSet = queueIds.toSet();

    if (queueIds.length != queueIdSet.length) {
      return _fail('Invariant failed: the active queue contains duplicates.');
    }

    if (!_isSubset(queueIdSet, originalIds)) {
      return _fail(
        'Invariant failed: the active queue contains an unknown word.',
      );
    }

    if (!_isSubset(_clearedWordIds, originalIds)) {
      return _fail('Invariant failed: cleared words contain an unknown word.');
    }

    if (queueIdSet.intersection(_clearedWordIds).isNotEmpty) {
      return _fail(
        'Invariant failed: a word cannot be both active and cleared.',
      );
    }

    final partition = <String>{...queueIdSet, ..._clearedWordIds};
    if (!_sameSet(partition, originalIds)) {
      return _fail(
        'Invariant failed: an original round word was lost or duplicated.',
      );
    }

    if (!_sameSet(_perWordAttemptCounts.keys.toSet(), originalIds)) {
      return _fail(
        'Invariant failed: attempt counters do not match the round words.',
      );
    }

    if (_attemptEvents.length != _totalAnswerAttempts) {
      return _fail(
        'Invariant failed: attempt event count does not match total attempts.',
      );
    }

    final eventCounts = <String, int>{
      for (final word in _originalRoundWords) word.id: 0,
    };
    var practiceAgainEvents = 0;
    var timeoutEvents = 0;
    var swipeEvents = 0;

    for (var index = 0; index < _attemptEvents.length; index += 1) {
      final event = _attemptEvents[index];
      if (event.sequenceNumber != index + 1) {
        return _fail(
          'Invariant failed: attempt sequence numbers must be contiguous.',
        );
      }
      if (!originalIds.contains(event.word.id)) {
        return _fail(
          'Invariant failed: an attempt references an unknown word.',
        );
      }
      if (event.elapsed.isNegative) {
        return _fail(
          'Invariant failed: an attempt has a negative elapsed time.',
        );
      }

      eventCounts[event.word.id] = (eventCounts[event.word.id] ?? 0) + 1;
      if (event.attemptNumberForWord != eventCounts[event.word.id]) {
        return _fail(
          'Invariant failed: per-word attempt numbers are not contiguous.',
        );
      }

      switch (event.result) {
        case FlashDashAnswer.known:
          swipeEvents += 1;
          break;
        case FlashDashAnswer.practiceAgain:
          swipeEvents += 1;
          practiceAgainEvents += 1;
          break;
        case FlashDashAnswer.timeout:
          timeoutEvents += 1;
          break;
      }
    }

    if (!_mapsEqual(eventCounts, _perWordAttemptCounts)) {
      return _fail(
        'Invariant failed: attempt events do not match per-word counters.',
      );
    }
    if (swipeEvents != _totalSwipeAttempts ||
        practiceAgainEvents != _practiceAgainSwipeCount ||
        timeoutEvents != _timeoutCount) {
      return _fail(
        'Invariant failed: attempt outcomes do not match aggregate counters.',
      );
    }

    if (_status == FlashDashGameStatus.completed && _activeQueue.isNotEmpty) {
      return _fail(
        'Invariant failed: a completed round must have an empty queue.',
      );
    }

    if (_activeQueue.isEmpty &&
        _status == FlashDashGameStatus.playing &&
        originalIds.isNotEmpty) {
      return _fail(
        'Invariant failed: an empty queue must complete the active round.',
      );
    }

    return true;
  }

  bool _fail(String message) {
    _status = FlashDashGameStatus.error;
    _errorMessage = message;
    _isTransitionProcessing = false;
    return false;
  }

  static bool _sameSet(Set<String> left, Set<String> right) {
    return left.length == right.length && left.containsAll(right);
  }

  static bool _isSubset(Set<String> candidate, Set<String> allowed) {
    return allowed.containsAll(candidate);
  }

  static bool _mapsEqual(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static Word _copyWord(Word word) {
    return word.copyWith(
      sentences: List<String>.unmodifiable(word.sentences),
    );
  }
}
