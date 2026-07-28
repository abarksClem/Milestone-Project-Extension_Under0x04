import 'package:readright/models/word.dart';

class FlashDashWordSet {
  final String listId;
  final String listTitle;
  final int listOrder;
  final List<Word> words;

  FlashDashWordSet({
    required this.listId,
    required this.listTitle,
    required this.listOrder,
    required List<Word> words,
  }) : words = List<Word>.unmodifiable(words);
}

abstract class FlashDashWordRepository {
  Future<FlashDashWordSet> loadCurrentWordSet();
}

class FlashDashRepositoryException implements Exception {
  final String message;

  const FlashDashRepositoryException(this.message);

  @override
  String toString() => message;
}
