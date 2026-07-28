import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:readright/config/config.dart';
import 'package:readright/features/flash_dash/models/flash_dash_game_models.dart';
import 'package:readright/models/word.dart';

class FlashDashSwipeCard extends StatefulWidget {
  final Word word;
  final bool enabled;
  final int transitionSerial;
  final FlashDashAnswer? transitionAnswer;
  final bool Function(FlashDashAnswer answer) onAnswerRequested;
  final VoidCallback onTransitionAnimationComplete;
  final VoidCallback onCardReady;

  const FlashDashSwipeCard({
    super.key,
    required this.word,
    required this.enabled,
    required this.transitionSerial,
    required this.transitionAnswer,
    required this.onAnswerRequested,
    required this.onTransitionAnimationComplete,
    required this.onCardReady,
  });

  @override
  State<FlashDashSwipeCard> createState() => _FlashDashSwipeCardState();
}

class _FlashDashSwipeCardState extends State<FlashDashSwipeCard>
    with SingleTickerProviderStateMixin {
  static const double _dragThreshold = 88;

  late final AnimationController _animationController;
  Animation<Offset>? _offsetAnimation;

  Offset _dragOffset = Offset.zero;
  bool _animating = false;
  int _handledTransitionSerial = 0;

  Offset get _visibleOffset => _offsetAnimation?.value ?? _dragOffset;

  FlashDashAnswer? get _dragPreviewAnswer {
    if (_dragOffset.dx > 24) return FlashDashAnswer.known;
    if (_dragOffset.dx < -24) return FlashDashAnswer.practiceAgain;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _handledTransitionSerial = widget.transitionSerial;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyCardReady());
  }

  @override
  void didUpdateWidget(covariant FlashDashSwipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final hasNewTransition =
        widget.transitionSerial != _handledTransitionSerial &&
        widget.transitionAnswer != null;

    if (hasNewTransition) {
      _handledTransitionSerial = widget.transitionSerial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _animateAcceptedAnswer(widget.transitionAnswer!);
        }
      });
    }

    final cardBecameReady = widget.transitionAnswer == null &&
        (oldWidget.word.id != widget.word.id ||
            (!oldWidget.enabled && widget.enabled));
    if (cardBecameReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyCardReady());
    }
  }

  void _notifyCardReady() {
    if (mounted && widget.enabled && widget.transitionAnswer == null) {
      widget.onCardReady();
    }
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _animating || widget.transitionAnswer != null) return;

    setState(() {
      _dragOffset += details.delta;
      _dragOffset = Offset(
        _dragOffset.dx,
        _dragOffset.dy.clamp(-70.0, 70.0).toDouble(),
      );
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.enabled || _animating || widget.transitionAnswer != null) return;

    final horizontalVelocity = details.velocity.pixelsPerSecond.dx;
    final swipedRight =
        _dragOffset.dx >= _dragThreshold || horizontalVelocity >= 700;
    final swipedLeft =
        _dragOffset.dx <= -_dragThreshold || horizontalVelocity <= -700;

    if (swipedRight) {
      _requestAnswer(FlashDashAnswer.known);
    } else if (swipedLeft) {
      _requestAnswer(FlashDashAnswer.practiceAgain);
    } else {
      _animateBackToCenter();
    }
  }

  void _requestAnswer(FlashDashAnswer answer) {
    if (!widget.enabled || _animating || widget.transitionAnswer != null) return;

    final accepted = widget.onAnswerRequested(answer);
    if (!accepted) {
      _animateBackToCenter();
    }
  }

  Future<void> _animateAcceptedAnswer(FlashDashAnswer answer) async {
    if (_animating) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final direction = answer == FlashDashAnswer.known ? 1.0 : -1.0;
    final target = Offset(
      direction * (screenWidth + 160),
      answer == FlashDashAnswer.timeout ? 26 : _dragOffset.dy * 0.25,
    );

    setState(() => _animating = true);
    _animationController.stop();
    _animationController.duration = const Duration(milliseconds: 320);
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInBack,
      ),
    );

    try {
      await _animationController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;
    widget.onTransitionAnimationComplete();

    if (!mounted) return;
    setState(() {
      _animationController.reset();
      _offsetAnimation = null;
      _dragOffset = Offset.zero;
      _animating = false;
    });
  }

  Future<void> _animateBackToCenter() async {
    if (_animating || _dragOffset == Offset.zero) return;

    setState(() => _animating = true);
    _animationController.stop();
    _animationController.duration = const Duration(milliseconds: 220);
    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    try {
      await _animationController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;
    setState(() {
      _animationController.reset();
      _offsetAnimation = null;
      _dragOffset = Offset.zero;
      _animating = false;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offset = _visibleOffset;
    final answer = widget.transitionAnswer ?? _dragPreviewAnswer;
    final rotation = (offset.dx / 900).clamp(-0.16, 0.16).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _SwipeHint(
                icon: Icons.replay_rounded,
                title: 'Practice Again',
                subtitle: 'Swipe left',
                color: Color(AppConfig.secondaryColor),
                alignment: CrossAxisAlignment.start,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SwipeHint(
                icon: Icons.check_circle_rounded,
                title: 'I Know It',
                subtitle: 'Swipe right',
                color: Color(AppConfig.primaryColor),
                alignment: CrossAxisAlignment.end,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          label:
              'Sight word ${widget.word.text}. Swipe left to practice again or swipe right if you know it.',
          button: true,
          enabled: widget.enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: widget.enabled ? _handlePanUpdate : null,
            onPanEnd: widget.enabled ? _handlePanEnd : null,
            child: Transform.translate(
              offset: offset,
              child: Transform.rotate(
                angle: rotation,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        minHeight: 245,
                        maxHeight: 310,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: answer == FlashDashAnswer.known
                              ? Color(AppConfig.primaryColor)
                              : answer == FlashDashAnswer.practiceAgain ||
                                      answer == FlashDashAnswer.timeout
                                  ? Color(AppConfig.secondaryColor)
                                  : theme.colorScheme.onSurface.withOpacity(0.18),
                          width: answer == null ? 2 : 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.13),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.word.text,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 82,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (answer != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 100),
                            opacity: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _feedbackColor(answer).withOpacity(0.13),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Center(
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width - 72,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface
                                        .withOpacity(0.94),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _feedbackColor(answer),
                                      width: 3,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _feedbackIcon(answer),
                                        size: 32,
                                        color: _feedbackColor(answer),
                                      ),
                                      const SizedBox(width: 9),
                                      Flexible(
                                        child: Text(
                                          _feedbackText(answer),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final practiceButton = _buildPracticeButton();
            final knownButton = _buildKnownButton();

            if (constraints.maxWidth < 390) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: practiceButton),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: knownButton),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: practiceButton),
                const SizedBox(width: 12),
                Expanded(child: knownButton),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPracticeButton() {
    return OutlinedButton.icon(
      onPressed: widget.enabled && !_animating
          ? () => _requestAnswer(FlashDashAnswer.practiceAgain)
          : null,
      icon: const Icon(Icons.replay_rounded),
      label: const Text('Practice Again'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(AppConfig.secondaryColor),
        side: BorderSide(
          color: Color(AppConfig.secondaryColor),
          width: 2,
        ),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildKnownButton() {
    return ElevatedButton.icon(
      onPressed: widget.enabled && !_animating
          ? () => _requestAnswer(FlashDashAnswer.known)
          : null,
      icon: const Icon(Icons.check_circle_rounded),
      label: const Text('I Know It'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(AppConfig.primaryColor),
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _feedbackColor(FlashDashAnswer answer) {
    return answer == FlashDashAnswer.known
        ? Color(AppConfig.primaryColor)
        : Color(AppConfig.secondaryColor);
  }

  IconData _feedbackIcon(FlashDashAnswer answer) {
    switch (answer) {
      case FlashDashAnswer.known:
        return Icons.check_circle_rounded;
      case FlashDashAnswer.practiceAgain:
        return Icons.replay_rounded;
      case FlashDashAnswer.timeout:
        return Icons.timer_off_rounded;
    }
  }

  String _feedbackText(FlashDashAnswer answer) {
    switch (answer) {
      case FlashDashAnswer.known:
        return 'I Know It!';
      case FlashDashAnswer.practiceAgain:
        return 'Practice Again';
      case FlashDashAnswer.timeout:
        return "Time's Up — Practice Again";
    }
  }
}

class _SwipeHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final CrossAxisAlignment alignment;

  const _SwipeHint({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isRightAligned = alignment == CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment:
              isRightAligned ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (isRightAligned) ...[
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Transform.rotate(
              angle: isRightAligned ? 0 : math.pi,
              child: Icon(Icons.swipe_right_rounded, color: color),
            ),
            const SizedBox(width: 4),
            Icon(icon, color: color, size: 20),
            if (!isRightAligned) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
