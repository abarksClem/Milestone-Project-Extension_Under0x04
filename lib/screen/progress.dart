import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:readright/config/config.dart';
import 'package:readright/features/flash_dash/data/flash_dash_progress_repository.dart';
import 'package:readright/features/flash_dash/data/supabase_flash_dash_progress_repository.dart';
import 'package:readright/features/flash_dash/models/flash_dash_progress_models.dart';
import 'package:readright/features/flash_dash/widgets/flash_dash_progress_history_card.dart';
import 'package:readright/services/databaseHelper.dart';
import 'package:readright/widgets/student_base_scaffold.dart';

class ProgressPage extends StatefulWidget {
  final SupabaseClient? testClient;
  final FlashDashProgressRepository? flashDashProgressRepository;
  final bool skipLoad;
  final bool testStartLoaded;

  const ProgressPage({
    super.key,
    this.testClient,
    this.flashDashProgressRepository,
    this.skipLoad = false,
    this.testStartLoaded = false,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> attempts = [];

  bool isLoading = true;
  String? pronunciationError;

  bool flashDashLoading = true;
  String? flashDashError;
  FlashDashProgressSnapshot? flashDashProgress;

  late final FlashDashProgressRepository _flashDashRepository;

  final List<String> dolchLists = [
    'Pre-Primer',
    'Primer',
    '1st Grade',
    '2nd Grade',
    '3rd Grade',
  ];

  @override
  void initState() {
    super.initState();

    _flashDashRepository = widget.flashDashProgressRepository ??
        SupabaseFlashDashProgressRepository(client: widget.testClient);

    if (widget.testStartLoaded) {
      isLoading = false;
      flashDashLoading = false;
      return;
    }

    if (!widget.skipLoad) {
      _loadProgress();
    }
  }

  Future<void> _loadProgress() async {
    final supabase = widget.testClient ?? Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        flashDashLoading = false;
        pronunciationError = 'Sign in to see your progress.';
        flashDashError = 'Sign in to see your Flash Dash progress.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        flashDashLoading = true;
        pronunciationError = null;
        flashDashError = null;
      });
    }

    await Future.wait<void>([
      _loadPronunciationProgress(currentUser.id),
      _loadFlashDashProgress(),
    ]);
  }

  Future<void> _loadPronunciationProgress(String userId) async {
    try {
      final db = DatabaseHelper.instance;
      final userStats = await db.getUserProgressStats(userId);
      final userAttempts = await db.fetchAttemptsByUser(userId);

      if (!mounted) return;
      setState(() {
        stats = userStats;
        attempts = userAttempts;
        pronunciationError = null;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        pronunciationError = 'Pronunciation progress could not be loaded.';
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pronunciation progress: $error')),
      );
    }
  }

  Future<void> _loadFlashDashProgress() async {
    if (mounted) {
      setState(() {
        flashDashLoading = true;
        flashDashError = null;
      });
    }

    try {
      final loaded = await _flashDashRepository.loadCurrentStudentProgress();
      if (!mounted) return;

      setState(() {
        flashDashProgress = loaded;
        flashDashError = null;
        flashDashLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        flashDashError = error is FlashDashProgressRepositoryException
            ? error.message
            : 'Flash Dash progress could not be loaded. Please try again.';
        flashDashLoading = false;
      });
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy • h:mm a').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StudentBaseScaffold(
      currentIndex: 3,
      pageTitle: 'Progress',
      pageIcon: Icons.insights,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _loadProgress,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummary(context),
                const SizedBox(height: 20),
                _buildBadgesSection(context),
                const SizedBox(height: 20),
                FlashDashProgressHistoryCard(
                  isLoading: flashDashLoading,
                  errorMessage: flashDashError,
                  snapshot: flashDashProgress,
                  onRetry: _loadFlashDashProgress,
                ),
                const SizedBox(height: 16),
                _buildAttemptsCard(context),
                const SizedBox(height: 16),
                _buildStatsCard(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    if (pronunciationError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 10),
            Text(
              pronunciationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadProgress,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final avgScore = (stats['avgScore'] ?? 0).toDouble();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Pronunciation Progress',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildAverageScore(avgScore.round()),
          const SizedBox(height: 8),
          Text(
            'Average pronunciation score '
                '(${stats['totalAttempts'] ?? 0} attempts)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection(BuildContext context) {
    final rawCurrentList = stats['currentList'];
    final currentList = rawCurrentList is int
        ? rawCurrentList
        : int.tryParse(rawCurrentList?.toString() ?? '') ?? 1;

    return _buildCard(
      context: context,
      icon: Icons.emoji_events,
      title: 'Dolch List Badges',
      content: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(dolchLists.length, (index) {
            final unlocked = (index + 1) < currentList;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: unlocked
                        ? Color(AppConfig.primaryColor)
                        : Colors.grey.shade300,
                    child: Icon(
                      Icons.star,
                      color: unlocked ? Colors.white : Colors.grey.shade500,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dolchLists[index],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: unlocked
                          ? Color(AppConfig.primaryColor)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAttemptsCard(BuildContext context) {
    return _buildCard(
      context: context,
      icon: Icons.mic_rounded,
      title: 'Recent Pronunciation Practice',
      content: attempts.isEmpty
          ? const Text('No pronunciation attempts yet.')
          : Column(
        children: attempts.take(5).map((attempt) {
          final wordText = attempt['words']?['text'] ??
              attempt['word_text'] ??
              'Unknown';
          final score = ((attempt['score'] ?? 0) as num).round();
          final feedback = attempt['feedback'] ?? 'No feedback';
          return _buildAttemptRow(
            context,
            wordText.toString(),
            score,
            feedback.toString(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context) {
    return _buildCard(
      context: context,
      icon: Icons.assessment_rounded,
      title: 'Pronunciation Stats',
      content: Column(
        children: [
          _buildStatRow(
            context,
            'Total Attempts',
            '${stats['totalAttempts'] ?? 0}',
          ),
          _buildStatRow(
            context,
            'Average Score',
            stats['avgScore'] != null
                ? (stats['avgScore'] as num).toStringAsFixed(1)
                : '0',
          ),
          _buildStatRow(
            context,
            'Last Attempt',
            formatDate(stats['lastAttempt']?.toString()),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
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
                  Icon(icon, color: Color(AppConfig.secondaryColor)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAverageScore(int score) => Container(
    width: 100,
    height: 100,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color(AppConfig.primaryColor).withOpacity(0.1),
      border: Border.all(color: Color(AppConfig.primaryColor), width: 4),
    ),
    child: Center(
      child: Text(
        '$score',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Color(AppConfig.primaryColor),
        ),
      ),
    ),
  );

  Widget _buildAttemptRow(
      BuildContext context,
      String word,
      int score,
      String feedback,
      ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                word,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '$score',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(AppConfig.primaryColor),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                feedback,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildStatRow(
      BuildContext context,
      String label,
      String value,
      ) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Color(AppConfig.primaryColor),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
}
