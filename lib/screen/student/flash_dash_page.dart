import 'package:flutter/material.dart';
import 'package:readright/config/config.dart';
import 'package:readright/features/flash_dash/data/flash_dash_word_repository.dart';
import 'package:readright/features/flash_dash/data/supabase_flash_dash_word_repository.dart';
import 'package:readright/features/flash_dash/models/flash_dash_game_models.dart';
import 'package:readright/features/flash_dash/presentation/flash_dash_session_controller.dart';
import 'package:readright/features/flash_dash/widgets/flash_dash_instructions_view.dart';
import 'package:readright/features/flash_dash/widgets/flash_dash_progress_panel.dart';
import 'package:readright/features/flash_dash/widgets/flash_dash_summary_view.dart';
import 'package:readright/features/flash_dash/widgets/flash_dash_swipe_card.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

class FlashDashPage extends StatefulWidget {
  final FlashDashWordRepository? repository;
  final FlashDashGameConfig config;
  final FlashDashEngineFactory? engineFactory;

  const FlashDashPage({
    super.key,
    this.repository,
    this.config = const FlashDashGameConfig(
      cardDuration: Duration(seconds: 5),
      selectedWordCount: 10,
      shuffleWords: true,
    ),
    this.engineFactory,
  });

  @override
  State<FlashDashPage> createState() => _FlashDashPageState();
}

class _FlashDashPageState extends State<FlashDashPage>
    with WidgetsBindingObserver {
  late final FlashDashSessionController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = FlashDashSessionController(
      repository:
          widget.repository ?? SupabaseFlashDashWordRepository(),
      config: widget.config,
      engineFactory: widget.engineFactory,
    );

    _controller.loadWords();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.pauseGame();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _handleSystemBack() async {
    if (!_controller.hasRoundInProgress) return true;
    return _confirmExitRound();
  }

  Future<bool> _confirmExitRound() async {
    final wasActivelyPlaying =
        _controller.screenState == FlashDashScreenState.activeGame;

    if (wasActivelyPlaying) {
      _controller.pauseGame();
    }

    final shouldExit = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            return AlertDialog(
              icon: Icon(
                Icons.exit_to_app_rounded,
                color: Color(AppConfig.secondaryColor),
                size: 38,
              ),
              title: const Text('Leave Flash Dash?'),
              content: const Text(
                'This round is not finished. Your current round will be lost.',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.spaceEvenly,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Keep Playing'),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text('Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(AppConfig.secondaryColor),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted) return false;

    if (!shouldExit && wasActivelyPlaying) {
      _controller.resumeGame();
    }

    return shouldExit;
  }

  Future<void> _returnToDashboard({bool confirmActiveRound = true}) async {
    if (confirmActiveRound && _controller.hasRoundInProgress) {
      final shouldExit = await _confirmExitRound();
      if (!shouldExit || !mounted) return;
    }

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/studentDashboard',
      (route) => false,
    );
  }

  Future<bool> _handleLogoutRequest() async {
    if (!_controller.hasRoundInProgress) return true;
    return _confirmExitRound();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleSystemBack,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final activeRound = _controller.hasRoundInProgress;

          return StudentBaseScaffold(
            currentIndex: 0,
            pageTitle: 'Flash Dash',
            pageIcon: Icons.style_rounded,
            showBottomNavigationBar: !activeRound,
            onBeforeLogout: _handleLogoutRequest,
            body: SafeArea(child: _buildBody()),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    switch (_controller.screenState) {
      case FlashDashScreenState.loading:
        return _buildLoading();
      case FlashDashScreenState.loadFailure:
        return _buildLoadFailure();
      case FlashDashScreenState.instructions:
        final wordSet = _controller.wordSet!;
        return FlashDashInstructionsView(
          listTitle: wordSet.listTitle,
          wordCount: _controller.totalWords,
          cardDuration: widget.config.cardDuration,
          onStart: () {
            _controller.startRound();
          },
          onExit: () => _returnToDashboard(confirmActiveRound: false),
        );
      case FlashDashScreenState.activeGame:
      case FlashDashScreenState.pausedGame:
        return _buildGame();
      case FlashDashScreenState.roundComplete:
        final summary = _controller.summary;
        if (summary == null) {
          return _buildUnexpectedError();
        }
        return FlashDashSummaryView(
          listTitle: _controller.wordSet?.listTitle ?? 'your Dolch list',
          summary: summary,
          onPlayAgain: () {
            _controller.playAgain();
          },
          onDashboard: () =>
              _returnToDashboard(confirmActiveRound: false),
        );
    }
  }

  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(AppConfig.primaryColor),
            ),
            const SizedBox(height: 18),
            const Text(
              'Loading your sight words…',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadFailure() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 72,
              color: Color(AppConfig.secondaryColor),
            ),
            const SizedBox(height: 18),
            const Text(
              'We could not start Flash Dash',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _controller.errorMessage ??
                  'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  _controller.loadWords();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(AppConfig.primaryColor),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () =>
                  _returnToDashboard(confirmActiveRound: false),
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnexpectedError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 68),
            const SizedBox(height: 16),
            const Text(
              'The round summary is unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _controller.loadWords();
              },
              child: const Text('Restart Flash Dash'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final displayedWord = _controller.displayedWord;
    if (displayedWord == null) return _buildUnexpectedError();

    final isPaused =
        _controller.screenState == FlashDashScreenState.pausedGame;

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight > 38
                      ? constraints.maxHeight - 38
                      : 0,
                ),
                child: Column(
                  children: [
                    FlashDashProgressPanel(
                      listTitle:
                          _controller.wordSet?.listTitle ?? 'Current Dolch List',
                      completedWords: _controller.completedWords,
                      totalWords: _controller.totalWords,
                      remainingUniqueWords: _controller.remainingUniqueWords,
                      remainingSeconds: _controller.remainingWholeSeconds,
                      roundProgress: _controller.roundProgress,
                      timerProgress: _controller.timerProgress,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !_controller.isTransitioning && !isPaused
                                ? () {
                                    _controller.pauseGame();
                                  }
                                : null,
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: !_controller.isTransitioning
                                ? () {
                                    _returnToDashboard();
                                  }
                                : null,
                            icon: const Icon(Icons.exit_to_app_rounded),
                            label: const Text('Exit'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              foregroundColor: Color(AppConfig.secondaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    FlashDashSwipeCard(
                      word: displayedWord,
                      enabled: !isPaused && !_controller.isTransitioning,
                      transitionSerial: _controller.transitionSerial,
                      transitionAnswer: _controller.activeTransition?.answer,
                      onAnswerRequested: _controller.submitAnswer,
                      onTransitionAnimationComplete:
                          _controller.completeTransitionAnimation,
                      onCardReady: () {
                        _controller.markCardReady();
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (isPaused)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.62),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pause_circle_filled_rounded,
                        size: 68,
                        color: Color(AppConfig.secondaryColor),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Game Paused',
                        style: TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The countdown is stopped.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _controller.resumeGame();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Resume'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(AppConfig.primaryColor),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _returnToDashboard();
                        },
                        icon: const Icon(Icons.exit_to_app_rounded),
                        label: const Text('Leave Round'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
