import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:readright/config/config.dart';

import '../models/flash_dash_progress_models.dart';

class FlashDashProgressHistoryCard extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final FlashDashProgressSnapshot? snapshot;
  final VoidCallback onRetry;

  const FlashDashProgressHistoryCard({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.snapshot,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        key: const Key('flash-dash-progress-card'),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.style_rounded,
                    color: Color(AppConfig.secondaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Flash Dash Progress',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                _buildLoading()
              else if (errorMessage != null)
                _buildError(context)
              else if (snapshot == null ||
                  snapshot!.completedSessionCount == 0)
                _buildEmpty(context)
              else
                _buildLoaded(context, snapshot!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading Flash Dash results…'),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Column(
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 42,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('flash-dash-progress-retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 48,
              color: Color(AppConfig.primaryColor),
            ),
            const SizedBox(height: 10),
            const Text(
              'No Flash Dash rounds yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Complete a round and your game progress will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    FlashDashProgressSnapshot data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MetricChip(
              icon: Icons.flag_rounded,
              label: 'Rounds',
              value: '${data.completedSessionCount}',
            ),
            _MetricChip(
              icon: Icons.star_rounded,
              label: 'First Try',
              value: '${data.firstTryPercentage.round()}%',
            ),
            _MetricChip(
              icon: Icons.check_circle_rounded,
              label: 'Words Cleared',
              value: '${data.totalWordsCleared}',
            ),
            _MetricChip(
              icon: Icons.touch_app_rounded,
              label: 'Card Attempts',
              value: '${data.totalCardAttempts}',
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Recent Rounds',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...data.recentSessions.take(3).map(
              (session) => _RecentRoundRow(session: session),
            ),
        const SizedBox(height: 16),
        const Text(
          'Words to Keep Practicing',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        if (data.mostPracticedWords.isEmpty)
          Row(
            children: [
              Icon(
                Icons.celebration_rounded,
                color: Color(AppConfig.primaryColor),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'No extra practice was needed in your saved rounds.',
                  style: TextStyle(height: 1.35),
                ),
              ),
            ],
          )
        else
          ...data.mostPracticedWords.map(
            (word) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      word.text,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${word.totalPracticeAttempts} extra '
                    '${word.totalPracticeAttempts == 1 ? 'try' : 'tries'}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 135,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Color(AppConfig.primaryColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color(AppConfig.primaryColor).withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Color(AppConfig.primaryColor)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRoundRow extends StatelessWidget {
  final FlashDashProgressSession session;

  const _RecentRoundRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy • h:mm a').format(session.startedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Color(AppConfig.secondaryColor).withOpacity(0.14),
            child: Icon(
              Icons.bolt_rounded,
              color: Color(AppConfig.secondaryColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.listTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date\n'
                  '${session.firstTryPercentage.round()}% first try • '
                  '${session.totalAttempts} attempts • '
                  '${_formatDuration(session.duration)}',
                  style: TextStyle(
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
