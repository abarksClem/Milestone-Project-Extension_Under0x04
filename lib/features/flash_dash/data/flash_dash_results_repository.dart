import '../models/flash_dash_persistence_models.dart';

abstract class FlashDashResultsRepository {
  String createSessionId();

  Future<FlashDashSavedSession> saveSession(
    FlashDashSessionSaveRequest request,
  );
}

class FlashDashResultsRepositoryException implements Exception {
  final String message;
  final Object? cause;

  const FlashDashResultsRepositoryException(this.message, {this.cause});

  @override
  String toString() => message;
}
