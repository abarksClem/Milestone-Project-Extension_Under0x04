import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:readright/models/word.dart';

import '../data/flash_dash_word_repository.dart';
import '../logic/flash_dash_game_engine.dart';
import '../models/flash_dash_game_models.dart';

enum FlashDashScreenState {
  loading,
  loadFailure,
  instructions,
  activeGame,
  pausedGame,
  roundComplete,
}

typedef FlashDashEngineFactory = FlashDashGameEngine Function(
  FlashDashGameConfig config,
);

typedef FlashDashNow = DateTime Function();

class FlashDashSessionController extends ChangeNotifier {
  final FlashDashWordRepository repository;
  final FlashDashGameConfig config;
  final FlashDashEngineFactory _engineFactory;
  final FlashDashNow _now;

  FlashDashScreenState _screenState = FlashDashScreenState.loading;
  FlashDashWordSet? _wordSet;
  FlashDashGameEngine? _engine;
  String? _errorMessage;

  Timer? _countdownTimer;
  DateTime? _cardDeadline;
  Duration _remainingCardTime;

  FlashDashTransition? _activeTransition;
  int _transitionSerial = 0;
  bool _answerLocked = false;
  bool _cardReady = false;
  bool _pauseRequestedAfterTransition = false;
  bool _resumeRequestedAfterTransition = false;
  bool _disposed = false;
  int _loadRequestId = 0;

  FlashDashSessionController({
    required this.repository,
    required this.config,
    FlashDashEngineFactory? engineFactory,
    FlashDashNow? now,
  })  : _engineFactory =
            engineFactory ?? ((gameConfig) => FlashDashGameEngine(config: gameConfig)),
        _now = now ?? DateTime.now,
        _remainingCardTime = config.cardDuration;

  FlashDashScreenState get screenState => _screenState;
  FlashDashWordSet? get wordSet => _wordSet;
  FlashDashGameEngine? get engine => _engine;
  String? get errorMessage => _errorMessage;
  Duration get remainingCardTime => _remainingCardTime;
  FlashDashTransition? get activeTransition => _activeTransition;
  int get transitionSerial => _transitionSerial;
  bool get isTransitioning => _activeTransition != null || _answerLocked;
  bool get isCardReady => _cardReady;

  Word? get displayedWord =>
      _activeTransition?.answeredWord ?? _engine?.currentWord;

  int get completedWords => _engine?.completedWords ?? 0;
  int get totalWords => _engine?.selectedWordCount ?? 0;
  int get remainingUniqueWords => _engine?.activeQueue.length ?? 0;

  double get roundProgress {
    if (totalWords == 0) return 0;
    return (completedWords / totalWords).clamp(0.0, 1.0).toDouble();
  }

  double get timerProgress {
    final totalMilliseconds = config.cardDuration.inMilliseconds;
    if (totalMilliseconds <= 0) return 0;
    return (_remainingCardTime.inMilliseconds / totalMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  int get remainingWholeSeconds {
    final milliseconds = _remainingCardTime.inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  FlashDashRoundSummary? get summary => _engine?.summary;

  bool get hasRoundInProgress =>
      _screenState == FlashDashScreenState.activeGame ||
      _screenState == FlashDashScreenState.pausedGame;

  Future<void> loadWords() async {
    final requestId = ++_loadRequestId;
    _cancelCountdown(preserveRemaining: false);
    _wordSet = null;
    _engine = null;
    _activeTransition = null;
    _answerLocked = false;
    _cardReady = false;
    _pauseRequestedAfterTransition = false;
    _resumeRequestedAfterTransition = false;
    _remainingCardTime = config.cardDuration;
    _errorMessage = null;
    _screenState = FlashDashScreenState.loading;
    _notify();

    try {
      final loadedWordSet = await repository.loadCurrentWordSet();
      if (_disposed || requestId != _loadRequestId) return;

      _wordSet = loadedWordSet;
      final initialized = _prepareEngine();
      if (!initialized) {
        _screenState = FlashDashScreenState.loadFailure;
        _notify();
        return;
      }

      _screenState = FlashDashScreenState.instructions;
      _notify();
    } catch (error) {
      if (_disposed || requestId != _loadRequestId) return;
      _errorMessage = error is FlashDashRepositoryException
          ? error.message
          : 'Flash Dash could not load your words. Please try again.';
      _screenState = FlashDashScreenState.loadFailure;
      _notify();
    }
  }

  bool startRound() {
    final gameEngine = _engine;
    if (_screenState != FlashDashScreenState.instructions ||
        gameEngine == null ||
        !gameEngine.start()) {
      return false;
    }

    _remainingCardTime = config.cardDuration;
    _cardReady = false;
    _screenState = FlashDashScreenState.activeGame;
    _notify();
    return true;
  }

  bool playAgain() {
    _cancelCountdown(preserveRemaining: false);
    _activeTransition = null;
    _answerLocked = false;
    _cardReady = false;
    _pauseRequestedAfterTransition = false;
    _resumeRequestedAfterTransition = false;
    _remainingCardTime = config.cardDuration;

    if (!_prepareEngine()) {
      _screenState = FlashDashScreenState.loadFailure;
      _notify();
      return false;
    }

    final gameEngine = _engine;
    if (gameEngine == null || !gameEngine.start()) {
      _errorMessage = 'A new Flash Dash round could not be started.';
      _screenState = FlashDashScreenState.loadFailure;
      _notify();
      return false;
    }

    _screenState = FlashDashScreenState.activeGame;
    _notify();
    return true;
  }

  bool submitAnswer(FlashDashAnswer answer) {
    final gameEngine = _engine;
    if (_screenState != FlashDashScreenState.activeGame ||
        gameEngine == null ||
        !_cardReady ||
        _answerLocked ||
        _activeTransition != null) {
      return false;
    }

    _answerLocked = true;
    _cardReady = false;
    _cancelCountdown(preserveRemaining: false);

    final transition = gameEngine.submitAnswer(answer);
    if (transition == null) {
      _answerLocked = false;
      _cardReady = true;
      if (gameEngine.status == FlashDashGameStatus.playing) {
        _remainingCardTime = config.cardDuration;
        _startCountdown();
      }
      return false;
    }

    _activeTransition = transition;
    _transitionSerial += 1;
    _remainingCardTime = config.cardDuration;
    _notify();
    return true;
  }

  void completeTransitionAnimation() {
    final gameEngine = _engine;
    if (_activeTransition == null || gameEngine == null) return;

    gameEngine.completeTransition();
    _activeTransition = null;
    _answerLocked = false;

    if (gameEngine.status == FlashDashGameStatus.completed) {
      _pauseRequestedAfterTransition = false;
      _resumeRequestedAfterTransition = false;
      _cardReady = false;
      _screenState = FlashDashScreenState.roundComplete;
      _cancelCountdown(preserveRemaining: false);
      _notify();
      return;
    }

    if (_resumeRequestedAfterTransition) {
      _resumeRequestedAfterTransition = false;
      _pauseRequestedAfterTransition = false;
      _screenState = FlashDashScreenState.activeGame;
      _remainingCardTime = config.cardDuration;
      _cardReady = false;
      _notify();
      return;
    }

    if (_pauseRequestedAfterTransition) {
      _pauseRequestedAfterTransition = false;
      gameEngine.pause();
      _screenState = FlashDashScreenState.pausedGame;
      _remainingCardTime = config.cardDuration;
      _cardReady = false;
      _notify();
      return;
    }

    _screenState = FlashDashScreenState.activeGame;
    _remainingCardTime = config.cardDuration;
    _cardReady = false;
    _notify();
  }


  bool markCardReady() {
    if (_screenState != FlashDashScreenState.activeGame ||
        _activeTransition != null ||
        _answerLocked ||
        _engine?.status != FlashDashGameStatus.playing) {
      return false;
    }

    if (_cardReady) return true;

    _cardReady = true;
    _remainingCardTime = config.cardDuration;
    _notify();
    _startCountdown();
    return true;
  }

  bool pauseGame() {
    final gameEngine = _engine;
    if (_screenState != FlashDashScreenState.activeGame || gameEngine == null) {
      return false;
    }

    _captureRemainingTime();
    _cancelCountdown();

    if (_activeTransition != null || gameEngine.isTransitionProcessing) {
      _pauseRequestedAfterTransition = true;
      _resumeRequestedAfterTransition = false;
      _screenState = FlashDashScreenState.pausedGame;
      _notify();
      return true;
    }

    if (!gameEngine.pause()) return false;

    _screenState = FlashDashScreenState.pausedGame;
    _notify();
    return true;
  }

  bool resumeGame() {
    final gameEngine = _engine;
    if (_screenState != FlashDashScreenState.pausedGame || gameEngine == null) {
      return false;
    }

    if (_activeTransition != null || gameEngine.isTransitionProcessing) {
      _pauseRequestedAfterTransition = false;
      _resumeRequestedAfterTransition = true;
      return true;
    }

    if (!gameEngine.resume()) return false;

    _pauseRequestedAfterTransition = false;
    _resumeRequestedAfterTransition = false;
    _screenState = FlashDashScreenState.activeGame;
    _notify();
    if (_cardReady) {
      _startCountdown();
    }
    return true;
  }

  bool _prepareEngine() {
    final loadedWordSet = _wordSet;
    if (loadedWordSet == null) {
      _errorMessage = 'No Dolch words are available for Flash Dash.';
      return false;
    }

    final gameEngine = _engineFactory(config);
    if (!gameEngine.initialize(loadedWordSet.words)) {
      _engine = gameEngine;
      _errorMessage = gameEngine.errorMessage ??
          'Flash Dash could not prepare this round.';
      return false;
    }

    _engine = gameEngine;
    _errorMessage = null;
    return true;
  }

  void _startCountdown() {
    if (_disposed ||
        !_cardReady ||
        _screenState != FlashDashScreenState.activeGame ||
        _activeTransition != null ||
        _answerLocked ||
        _engine?.status != FlashDashGameStatus.playing) {
      return;
    }

    _countdownTimer?.cancel();
    final startingDuration = _remainingCardTime > Duration.zero
        ? _remainingCardTime
        : config.cardDuration;
    _remainingCardTime = startingDuration;
    _cardDeadline = _now().add(startingDuration);

    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) {
        if (_disposed ||
            _screenState != FlashDashScreenState.activeGame ||
            _activeTransition != null ||
            _answerLocked) {
          timer.cancel();
          return;
        }

        final deadline = _cardDeadline;
        if (deadline == null) {
          timer.cancel();
          return;
        }

        final remaining = deadline.difference(_now());
        if (remaining <= Duration.zero) {
          _remainingCardTime = Duration.zero;
          timer.cancel();
          _countdownTimer = null;
          _cardDeadline = null;
          _notify();
          submitAnswer(FlashDashAnswer.timeout);
          return;
        }

        _remainingCardTime = remaining;
        _notify();
      },
    );
  }

  void _captureRemainingTime() {
    final deadline = _cardDeadline;
    if (deadline == null) return;

    final remaining = deadline.difference(_now());
    _remainingCardTime = remaining > Duration.zero ? remaining : Duration.zero;
  }

  void _cancelCountdown({bool preserveRemaining = true}) {
    if (preserveRemaining) {
      _captureRemainingTime();
    }
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _cardDeadline = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loadRequestId += 1;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    super.dispose();
  }
}
