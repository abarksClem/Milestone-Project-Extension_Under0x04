import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/flash_dash_persistence_models.dart';
import 'flash_dash_results_repository.dart';

typedef FlashDashRpcInvoker = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> parameters,
);

class SupabaseFlashDashResultsRepository
    implements FlashDashResultsRepository {
  final SupabaseClient? _client;
  final FlashDashRpcInvoker? _rpcInvoker;
  final Random _random;

  SupabaseFlashDashResultsRepository({
    SupabaseClient? client,
    FlashDashRpcInvoker? rpcInvoker,
    Random? random,
  })  : _client = client,
        _rpcInvoker = rpcInvoker,
        _random = random ?? Random.secure();

  @override
  String createSessionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    // RFC 4122 UUID version 4 and variant bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final encoded = bytes.map(hex).join();

    return '${encoded.substring(0, 8)}-'
        '${encoded.substring(8, 12)}-'
        '${encoded.substring(12, 16)}-'
        '${encoded.substring(16, 20)}-'
        '${encoded.substring(20)}';
  }

  @override
  Future<FlashDashSavedSession> saveSession(
    FlashDashSessionSaveRequest request,
  ) async {
    try {
      final response = await _invokeRpc(
        'save_flash_dash_session',
        request.toRpcParameters(),
      );

      final sessionId = response?.toString();
      if (sessionId == null || sessionId.isEmpty) {
        throw const FlashDashResultsRepositoryException(
          'Flash Dash returned an empty session id after saving.',
        );
      }

      return FlashDashSavedSession(sessionId);
    } on FlashDashResultsRepositoryException {
      rethrow;
    } catch (error) {
      throw FlashDashResultsRepositoryException(
        'Your Flash Dash result could not be saved. Your summary is still available.',
        cause: error,
      );
    }
  }

  Future<dynamic> _invokeRpc(
    String functionName,
    Map<String, dynamic> parameters,
  ) {
    final injectedInvoker = _rpcInvoker;
    if (injectedInvoker != null) {
      return injectedInvoker(functionName, parameters);
    }

    final client = _client ?? Supabase.instance.client;
    return client.rpc(functionName, params: parameters);
  }
}
