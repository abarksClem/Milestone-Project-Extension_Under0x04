import 'package:flutter/material.dart';
import 'package:readright/config/config.dart';

class FlashDashProgressPanel extends StatelessWidget {
  final String listTitle;
  final int completedWords;
  final int totalWords;
  final int remainingUniqueWords;
  final int remainingSeconds;
  final double roundProgress;
  final double timerProgress;

  const FlashDashProgressPanel({
    super.key,
    required this.listTitle,
    required this.completedWords,
    required this.totalWords,
    required this.remainingUniqueWords,
    required this.remainingSeconds,
    required this.roundProgress,
    required this.timerProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: Color(AppConfig.secondaryColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    listTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Semantics(
                  label: '$remainingSeconds seconds remaining',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(AppConfig.secondaryColor),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: Color(AppConfig.secondaryColor),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$remainingSeconds',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: roundProgress,
                minHeight: 12,
                backgroundColor: theme.colorScheme.onSurface.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(AppConfig.primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$completedWords of $totalWords cleared',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$remainingUniqueWords remaining',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.hourglass_bottom_rounded, size: 18),
                const SizedBox(width: 7),
                const Text(
                  'Time for this card',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: LinearProgressIndicator(
                      value: timerProgress,
                      minHeight: 9,
                      backgroundColor:
                          theme.colorScheme.onSurface.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(AppConfig.secondaryColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
