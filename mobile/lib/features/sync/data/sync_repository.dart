import '../../../core/api/api_client.dart';
import '../../../core/offline/offline_store.dart';

/// One page of `GET /sync/bootstrap` (doc 16 §3.1).
class BootstrapPage {
  const BootstrapPage({required this.rows, required this.nextAfterId, required this.serverTime});

  final List<Map<String, dynamic>> rows;
  final int? nextAfterId;

  /// The server's clock when the page was read: the next `since`.
  final String serverTime;
}

/// The server's answer for one queued item (05 §4.2).
class SyncResult {
  const SyncResult({required this.clientTransactionId, required this.status, this.serverId, this.flags = const [], this.errorCode, this.errorMessage});

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    final error = json['error'] is Map<String, dynamic> ? json['error'] as Map<String, dynamic> : null;
    return SyncResult(
      clientTransactionId: json['client_transaction_id'] as String,
      status: json['status'] as String,
      serverId: json['server_id']?.toString(),
      flags: [for (final f in json['flags'] as List<dynamic>? ?? const []) f as String],
      errorCode: error?['code'] as String?,
      errorMessage: error?['message'] as String?,
    );
  }

  final String clientTransactionId;

  /// `applied`, `duplicate`, `flagged`, `conflict` or `rejected_validation`.
  final String status;
  final String? serverId;
  final List<String> flags;
  final String? errorCode;
  final String? errorMessage;

  /// Held on the server for a manager (D-03, BR-10): kept on the phone as "needs review".
  bool get held => status == 'conflict' || status == 'rejected_validation';
}

class SyncRepository {
  SyncRepository(this._api);

  final ApiClient _api;

  Future<BootstrapPage> bootstrap(String entity, {String? since, int afterId = 0}) async {
    final body = await _api.get(
      '/sync/bootstrap',
      query: {'entity': entity, 'since': ?since, if (afterId > 0) 'after_id': afterId},
    );
    return BootstrapPage(
      rows: [for (final row in body['data'] as List<dynamic>? ?? const []) row as Map<String, dynamic>],
      nextAfterId: (body['next_after_id'] as num?)?.toInt(),
      serverTime: body['server_time'] as String,
    );
  }

  /// POST /sync/batch. Results come back for the items the server processed, in order; a
  /// technical failure on the server stops it early, and the rest are resent later.
  Future<List<SyncResult>> batch(String deviceId, List<OutboxItem> items) async {
    final body = await _api.post(
      '/sync/batch',
      body: {
        'device_id': deviceId,
        'items': [
          for (final item in items)
            {
              'client_transaction_id': item.clientTransactionId,
              'seq': item.seq,
              'type': item.type,
              'occurred_at': item.occurredAt.toUtc().toIso8601String(),
              'payload': item.payload,
              if (item.charged.isNotEmpty) 'charged': item.charged,
            },
        ],
      },
    );
    return [for (final row in body['results'] as List<dynamic>? ?? const []) SyncResult.fromJson(row as Map<String, dynamic>)];
  }
}
