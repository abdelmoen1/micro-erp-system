import 'dart:math';

import '../storage/key_value_store.dart';

/// Persistent Idempotency-Key per pending financial operation (SP-03, US-1304).
///
/// A key is created once for an operation (e.g. one checkout) and kept until the
/// server answers, so a retry after a timeout or an app restart reuses the same
/// key and the server never records the operation twice (US-0101).
class IdempotencyKeyStore {
  IdempotencyKeyStore(this._store, {Random? random}) : _random = random ?? Random.secure();

  static const _prefix = 'idem.';

  final KeyValueStore _store;
  final Random _random;

  /// Returns the stored key for [operationId], creating and persisting one first if needed.
  Future<String> keyFor(String operationId) async {
    final existing = await _store.read('$_prefix$operationId');
    if (existing != null) return existing;

    final key = _uuidV4();
    await _store.write('$_prefix$operationId', key);
    return key;
  }

  /// Forgets the key once the server has answered (success or a definitive error).
  Future<void> complete(String operationId) => _store.delete('$_prefix$operationId');

  /// Operations that were started but never got an answer (to resume after restart).
  Future<List<String>> pendingOperations() async {
    final all = await _store.readAll();
    return [
      for (final k in all.keys)
        if (k.startsWith(_prefix)) k.substring(_prefix.length),
    ];
  }

  String _uuidV4() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }
}
