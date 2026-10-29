import '../api/api_failure.dart';
import 'offline_store.dart';

/// Read side of offline mode (US-1102): the server while it answers, the local cache when it is
/// known to be unreachable or the call never got through. Without a usable local store the
/// network failure is thrown as before R2.
class OfflineReads {
  const OfflineReads(this.local, this.isOnline);

  final OfflineStore? local;
  final bool Function() isOnline;

  Future<T> read<T>(Future<T> Function() remote, Future<T> Function(OfflineStore local) fromLocal) async {
    final store = local;
    if (store != null && !isOnline() && await store.available) return fromLocal(store);
    try {
      return await remote();
    } on NetworkFailure {
      if (store != null && await store.available) return fromLocal(store);
      rethrow;
    }
  }
}
