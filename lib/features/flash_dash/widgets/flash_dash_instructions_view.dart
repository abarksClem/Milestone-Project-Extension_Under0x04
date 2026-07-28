import 'package:flutter/material.dart';
import 'package:readright/config/config.dart';

class FlashDashInstructionsView extends StatelessWidget {
  final String listTitle;
  final int wordCount;
  final Duration cardDuration;
  final VoidCallback onStart;
  final VoidCallback onExit;

  const FlashDashInstructionsView({
    super.key,
    required this.listTitle,
    required this.wordCount,
    required this.cardDuration,
    required this.onStart,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(AppConfig.primaryColor).withOpacity(0.16),
              border: Border.all(
                color: Color(AppConfig.primaryColor),
                width: 3,
              ),
            ),
            child: Icon(
              Icons.style_rounded,
              size: 58,
              color: Color(AppConfig.primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready to Flash Dash?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$listTitle • $wordCount ${wordCount == 1 ? 'word' : 'words'}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _InstructionCard(
            icon: Icons.swipe_left_rounded,
            title: 'Swipe left',
            message: 'Practice Again',
            detail: 'The word moves to the end so you can see it again.',
            color: Color(AppConfig.secondaryColor),
          ),
          const SizedBox(height: 12),
          _InstructionCard(
            icon: Icons.swipe_right_rounded,
            title: 'Swipe right',
            message: 'I Know It',
            detail: 'The word is cleared from this round.',
            color: Color(AppConfig.primaryColor),
          ),
          const SizedBox(height: 12),
          _InstructionCard(
            icon: Icons.timer_outlined,
            title: '${cardDuration.inSeconds} seconds per card',
            message: "Time's up means Practice Again",
            detail: 'You can also use the large buttons instead of swiping.',
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded, size: 30),
              label: const Text('Start Flash Dash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(AppConfig.primaryColor),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onExit,
            icon: const Icon(Icons.dashboard_rounded),
            label: const Text('Return to Dashboard'),
          ),
        ],
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String detail;
  final Color color;

  const _InstructionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 31),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 18,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detail,
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
      ),
    );
  }
}
