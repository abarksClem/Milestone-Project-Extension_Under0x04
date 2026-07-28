import 'package:flutter/material.dart';
import 'package:readright/config/config.dart';
import 'package:readright/features/flash_dash/models/flash_dash_game_models.dart';
import 'package:readright/features/flash_dash/models/flash_dash_persistence_models.dart';
import 'package:readright/models/word.dart';

class FlashDashSummaryView extends StatelessWidget {
  final String listTitle;
  final FlashDashRoundSummary summary;
  final VoidCallback onPlayAgain;
  final VoidCallback onDashboard;
  final VoidCallback? onProgress;
  final bool progressEnabled;
  final FlashDashResultSaveStatus saveStatus;
  final String? saveError;
  final VoidCallback? onRetrySave;

  const FlashDashSummaryView({
    super.key,
    required this.listTitle,
    required this.summary,
    required this.onPlayAgain,
    required this.onDashboard,
    this.onProgress,
    this.progressEnabled = false,
    this.saveStatus = FlashDashResultSaveStatus.notStarted,
    this.saveError,
    this.onRetrySave,
  });

  @override
  Widget build(BuildContext context) {
    final firstTryCount = summary.wordsKnownOnFirstTry.length;
    final practiceCount = summary.wordsRequiringAdditionalPractice.length;
    final totalWords = summary.originalRoundWords.length;
    final firstTryPercentage = totalWords == 0
        ? 0
        : ((firstTryCount / totalWords) * 100).round();
    final mostPracticed = _mostPracticedWords(summary);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(AppConfig.primaryColor).withOpacity(0.17),
              border: Border.all(
                color: Color(AppConfig.primaryColor),
                width: 4,
              ),
            ),
            child: Icon(
              Icons.emoji_events_rounded,
              size: 65,
              color: Color(AppConfig.primaryColor),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Amazing Flash Dash!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You cleared every word in $listTitle.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 22),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _SummaryStat(
                icon: Icons.timer_outlined,
                label: 'Completion Time',
                value: _formatDuration(summary.elapsedTime),
              ),
              _SummaryStat(
                icon: Icons.touch_app_rounded,
                label: 'Total Attempts',
                value: '${summary.totalAnswerAttempts}',
              ),
              _SummaryStat(
                icon: Icons.star_rounded,
                label: 'Known First Try',
                value: '$firstTryCount',
              ),
              _SummaryStat(
                icon: Icons.replay_rounded,
                label: 'Needed Practice',
                value: '$practiceCount',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 82,
                        height: 82,
                        child: CircularProgressIndicator(
                          value: firstTryPercentage / 100,
                          strokeWidth: 9,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(AppConfig.primaryColor),
                          ),
                        ),
                      ),
                      Text(
                        '$firstTryPercentage%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'First-Try Score',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Words cleared the first time they appeared.',
                          style: TextStyle(height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.fitness_center_rounded,
                        color: Color(AppConfig.secondaryColor),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Most-Practiced Words',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (mostPracticed.isEmpty)
                    const Text(
                      'Every word was known on the first try. Fantastic work!',
                      style: TextStyle(height: 1.4),
                    )
                  else
                    ...mostPracticed.map(
                          (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.word.text,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Color(AppConfig.secondaryColor)
                                    .withOpacity(0.13),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${entry.attempts} attempts',
                                style: TextStyle(
                                  color: Color(AppConfig.secondaryColor),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (saveStatus != FlashDashResultSaveStatus.notStarted) ...[
            const SizedBox(height: 16),
            _buildSaveStatusCard(context),
          ],
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onPlayAgain,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Play Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(AppConfig.primaryColor),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (onProgress != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                key: const Key('flash-dash-view-progress'),
                onPressed: progressEnabled ? onProgress : null,
                icon: const Icon(Icons.insights_rounded),
                label: Text(
                  progressEnabled
                      ? 'View Progress'
                      : 'View Progress After Saving',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(AppConfig.primaryColor),
                  side: BorderSide(
                    color: Color(AppConfig.primaryColor),
                    width: 2,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: onDashboard,
              icon: const Icon(Icons.dashboard_rounded),
              label: const Text('Return to Dashboard'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(AppConfig.secondaryColor),
                side: BorderSide(
                  color: Color(AppConfig.secondaryColor),
                  width: 2,
                ),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveStatusCard(BuildContext context) {
    switch (saveStatus) {
      case FlashDashResultSaveStatus.notStarted:
        return const SizedBox.shrink();
      case FlashDashResultSaveStatus.saving:
        return Card(
          child: ListTile(
            leading: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(AppConfig.secondaryColor),
              ),
            ),
            title: const Text(
              'Saving your result…',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('You can still read your round summary.'),
          ),
        );
      case FlashDashResultSaveStatus.saved:
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.cloud_done_rounded,
              color: Color(AppConfig.primaryColor),
            ),
            title: const Text(
              'Result saved',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Your Flash Dash round is safely stored.'),
          ),
        );
      case FlashDashResultSaveStatus.failed:
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.cloud_off_rounded),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Result not saved yet',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            saveError ??
                                'Your summary is safe on this screen. Try saving again.',
                            style: const TextStyle(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (onRetrySave != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: onRetrySave,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry Save'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }

  List<_PracticedWord> _mostPracticedWords(FlashDashRoundSummary round) {
    final wordById = <String, Word>{
      for (final word in round.originalRoundWords) word.id: word,
    };

    final entries = round.perWordAttemptCounts.entries
        .where((entry) => entry.value > 1 && wordById.containsKey(entry.key))
        .map(
          (entry) => _PracticedWord(
        word: wordById[entry.key]!,
        attempts: entry.value,
      ),
    )
        .toList();

    entries.sort((a, b) {
      final byAttempts = b.attempts.compareTo(a.attempts);
      if (byAttempts != 0) return byAttempts;
      return a.word.text.toLowerCase().compareTo(b.word.text.toLowerCase());
    });

    return entries.take(5).toList(growable: false);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes == 0) return '${seconds}s';
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Color(AppConfig.secondaryColor), size: 28),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticedWord {
  final Word word;
  final int attempts;

  const _PracticedWord({required this.word, required this.attempts});
}
