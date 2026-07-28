import '../models/flash_dash_progress_models.dart';

abstract class FlashDashProgressRepository {
  Future<FlashDashProgressSnapshot> loadCurrentStudentProgress();
}

class FlashDashProgressRepositoryException implements Exception {
  final String message;
  final Object? cause;

  const FlashDashProgressRepositoryException(
      this.message, {
        this.cause,
      });

  @override
  String toString() => message;
}