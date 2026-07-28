import 'package:readright/models/word.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'flash_dash_word_repository.dart';

class SupabaseFlashDashWordRepository implements FlashDashWordRepository {
  final SupabaseClient _client;

  SupabaseFlashDashWordRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<FlashDashWordSet> loadCurrentWordSet() async {
    final authenticatedUser = _client.auth.currentUser;
    if (authenticatedUser == null) {
      throw const FlashDashRepositoryException(
        'Please sign in again before starting Flash Dash.',
      );
    }

    final userRow = await _client
        .from('users')
        .select('current_list_int')
        .eq('id', authenticatedUser.id)
        .maybeSingle();

    if (userRow == null) {
      throw const FlashDashRepositoryException(
        'We could not find your student profile.',
      );
    }

    final rawListOrder = userRow['current_list_int'];
    final listOrder = rawListOrder is num
        ? rawListOrder.toInt()
        : int.tryParse(rawListOrder?.toString() ?? '');

    if (listOrder == null || listOrder <= 0) {
      throw const FlashDashRepositoryException(
        'Your current Dolch list is not set yet.',
      );
    }

    final dynamic rawListRows = await _client
        .from('word_lists')
        .select('id, title, list_order, category')
        .eq('list_order', listOrder);

    final List<Map<String, dynamic>> listRows = rawListRows is List
        ? rawListRows
            .map(
              (dynamic row) => Map<String, dynamic>.from(row as Map),
            )
            .toList(growable: false)
        : const <Map<String, dynamic>>[];

    if (listRows.isEmpty) {
      throw FlashDashRepositoryException(
        'Dolch list $listOrder could not be found.',
      );
    }

    final dolchRows = listRows.where((row) {
      return row['category']?.toString().trim().toLowerCase() == 'dolch';
    }).toList(growable: false);

    final candidates = dolchRows.isNotEmpty ? dolchRows : listRows;
    if (candidates.length != 1) {
      throw FlashDashRepositoryException(
        'More than one Dolch list uses list order $listOrder.',
      );
    }

    final listRow = candidates.single;
    if (listRow['id'] == null) {
      throw FlashDashRepositoryException(
        'Dolch list $listOrder is missing its id.',
      );
    }

    final listId = listRow['id'].toString();
    final listTitle = listRow['title']?.toString().trim();

    final dynamic rawRows = await _client
        .from('words')
        .select('id, text, type, sentences')
        .eq('list_id', listId)
        .order('text', ascending: true);

    final List<dynamic> rows = rawRows is List
        ? List<dynamic>.from(rawRows)
        : const <dynamic>[];

    final words = rows.map<Word>((dynamic rawRow) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final rawSentences = row['sentences'];
      final sentences = rawSentences is List
          ? rawSentences
              .where((dynamic value) => value != null)
              .map((dynamic value) => value.toString())
              .toList(growable: false)
          : const <String>[];

      return Word(
        id: row['id']?.toString() ?? '',
        text: row['text']?.toString() ?? '',
        type: row['type']?.toString() ?? 'Dolch',
        sentences: sentences,
      );
    }).toList(growable: false);

    if (words.isEmpty) {
      final displayTitle = listTitle?.isNotEmpty == true
          ? listTitle!
          : 'This Dolch list';
      throw FlashDashRepositoryException(
        '$displayTitle has no words yet.',
      );
    }

    return FlashDashWordSet(
      listId: listId,
      listTitle: listTitle?.isNotEmpty == true
          ? listTitle!
          : 'Dolch List $listOrder',
      listOrder: listOrder,
      words: words,
    );
  }
}
