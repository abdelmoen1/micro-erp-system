import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/customers/domain/customer.dart';
import '../../features/products/domain/product.dart';
import '../api/idempotency_key_store.dart';
import '../money/fixed_point.dart';

/// Where a queued item stands (doc 16 §3). `done` = applied, duplicate or flagged on the server;
/// `review` = held by the server (conflict / rejected), resolved by a manager on the web.
enum OutboxState { pending, done, review }

/// A sale or payment committed on the phone and waiting for, or past, the sync (US-1103).
class OutboxItem {
  const OutboxItem({
    required this.seq,
    required this.clientTransactionId,
    required this.userId,
    required this.type,
    required this.payload,
    required this.occurredAt,
    required this.state,
    required this.summary,
    this.charged = const [],
    this.attempts = 0,
    this.lastError,
    this.serverId,
    this.flags = const [],
  });

  factory OutboxItem._fromRow(Map<String, Object?> row) => OutboxItem(
    seq: row['seq']! as int,
    clientTransactionId: row['ctid']! as String,
    userId: row['user_id'] as int?,
    type: row['type']! as String,
    payload: jsonDecode(row['payload']! as String) as Map<String, dynamic>,
    charged: [for (final c in jsonDecode(row['charged'] as String? ?? '[]') as List<dynamic>) c as Map<String, dynamic>],
    occurredAt: DateTime.parse(row['occurred_at']! as String),
    state: OutboxState.values.byName(row['state']! as String),
    summary: jsonDecode(row['summary'] as String? ?? '{}') as Map<String, dynamic>,
    attempts: row['attempts'] as int? ?? 0,
    lastError: row['last_error'] as String?,
    serverId: row['server_id'] as String?,
    flags: [for (final f in jsonDecode(row['flags'] as String? ?? '[]') as List<dynamic>) f as String],
  );

  /// FIFO position (BR-05): SQLite's autoincrement, never reused.
  final int seq;

  /// The Idempotency-Key of this operation on the server.
  final String clientTransactionId;
  final int? userId;

  /// `sale` or `payment` (CR-02: nothing else is queued).
  final String type;

  /// The exact body of the online request (`POST /sales` or pay-all, plus `customer_id`).
  final Map<String, dynamic> payload;

  /// Sales only: the unit prices the cashier charged (doc 16 decision A).
  final List<Map<String, dynamic>> charged;

  /// BR-08: when it happened on the phone.
  final DateTime occurredAt;
  final OutboxState state;

  /// What the lists show without parsing the payload: `total`, `paid`, `debt`, `amount`,
  /// `customer_name`, `method`.
  final Map<String, dynamic> summary;
  final int attempts;

  /// `CODE: message` of the last failure (held reason, or the technical error).
  final String? lastError;
  final String? serverId;
  final List<String> flags;

  /// D-18: more than 10 technical failures: listed as stuck.
  bool get stuck => state == OutboxState.pending && attempts > 10;

  /// A short reference shown on an offline receipt until the server number exists.
  String get localRef => clientTransactionId.substring(0, 8).toUpperCase();

  Money get amount => Money.parse('${summary[type == 'sale' ? 'total' : 'amount'] ?? '0.00'}');
}

/// The stock and balance a queued item moves on the phone, until the server's own numbers include it.
class OutboxEffect {
  OutboxEffect.stock(this.refId, Quantity delta) : kind = 'stock', delta = delta.milli;

  OutboxEffect.balance(this.refId, Money delta) : kind = 'balance', delta = delta.cents;

  final String kind;
  final int refId;

  /// Thousandths for stock, agorot for balance.
  final int delta;
}

/// Thrown when the queue already holds [limit] unsynced items (FR-68, BR-12).
class QueueFull implements Exception {
  const QueueFull(this.pending);

  final int pending;
}

/// Counts behind the sync indicator (FR-67).
class OutboxCounts {
  const OutboxCounts({this.pending = 0, this.review = 0, this.stuck = 0});

  final int pending;
  final int review;
  final int stuck;
}

/// R2 local database (doc 16 §2, sqflite / CR-11): the catalog and customer cache, and the FIFO
/// queue of offline sales and payments. A local commit is one SQLite transaction (NFR-05), and
/// shown stock and balances are the server's numbers plus the effects of queued items (an
/// overlay), so nothing is counted twice when the server's own numbers arrive.
class OfflineStore {
  OfflineStore(this._factory, {this._path});

  static const fileName = 'hisbah_offline.db';

  /// D-18 / FR-68.
  static const warnAt = 800;
  static const limit = 1000;

  /// Null where sqflite has no plugin (desktop, web, host tests): offline mode is off there.
  final DatabaseFactory? _factory;
  final String? _path;
  Future<Database>? _db;

  Future<Database> get _database => _db ??= _open();

  Future<Database> _open() async {
    final factory = _factory;
    if (factory == null) throw UnsupportedError('No SQLite on this platform');
    final path = _path ?? '${await factory.getDatabasesPath()}/$fileName';
    return factory.openDatabase(
      path,
      // A given path (tests: an in-memory database) is never shared between stores.
      options: OpenDatabaseOptions(version: 1, onCreate: (db, _) => _create(db), singleInstance: _path == null),
    );
  }

  /// True when SQLite opened (false in a host test without a database, or on a broken device):
  /// the app then behaves as before R2, online only.
  Future<bool> get available async {
    if (_factory == null) return false;
    try {
      await _database;
      return true;
    } catch (_) {
      _db = null;
      return false;
    }
  }

  static Future<void> _create(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY, search_key TEXT NOT NULL, barcode TEXT, status TEXT NOT NULL,
          stock_milli INTEGER NOT NULL, json TEXT NOT NULL)''')
      ..execute('CREATE INDEX products_barcode ON products (barcode)')
      ..execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY, search_key TEXT NOT NULL, phone TEXT NOT NULL, status TEXT NOT NULL,
          balance_cents INTEGER NOT NULL, json TEXT NOT NULL)''')
      ..execute('''
        CREATE TABLE outbox (
          seq INTEGER PRIMARY KEY AUTOINCREMENT, ctid TEXT NOT NULL UNIQUE, user_id INTEGER,
          type TEXT NOT NULL, payload TEXT NOT NULL, charged TEXT, occurred_at TEXT NOT NULL,
          state TEXT NOT NULL, summary TEXT, attempts INTEGER NOT NULL DEFAULT 0, last_error TEXT,
          server_id TEXT, flags TEXT, created_at INTEGER NOT NULL, synced_at INTEGER,
          overlay INTEGER NOT NULL DEFAULT 1)''')
      ..execute('CREATE INDEX outbox_state ON outbox (state, seq)')
      ..execute('CREATE TABLE effects (seq INTEGER NOT NULL, kind TEXT NOT NULL, ref_id INTEGER NOT NULL, delta INTEGER NOT NULL)')
      ..execute('CREATE INDEX effects_ref ON effects (kind, ref_id)')
      ..execute('CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)');
    await batch.commit(noResult: true);
  }

  // ---- meta ----

  Future<String?> meta(String key) async {
    final rows = await (await _database).query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String? value) async {
    final db = await _database;
    if (value == null) {
      await db.delete('meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// One id per installation, sent with every batch.
  Future<String> deviceId() async {
    final existing = await meta('device_id');
    if (existing != null) return existing;
    final id = IdempotencyKeyStore.newUuid();
    await setMeta('device_id', id);
    return id;
  }

  /// The cache belongs to one store: another store signing in on this phone starts from empty.
  /// Queued items are kept (logout is refused while any are pending).
  Future<void> useStore(int storeId) async {
    if (await meta('store_id') == '$storeId') return;
    await clearCatalog();
    await setMeta('store_id', '$storeId');
  }

  Future<void> clearCatalog() async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('products');
      await txn.delete('customers');
      await txn.delete('meta', where: "key LIKE 'since.%' OR key = 'store_id'");
    });
  }

  // ---- catalog cache (sync-down) ----

  Future<void> upsertProducts(List<Map<String, dynamic>> rows) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('products', {
        'id': row['id'],
        'search_key': searchKey(row['name'] as String? ?? ''),
        'barcode': row['barcode'],
        'status': row['status'] ?? 'active',
        'stock_milli': Quantity.parse(row['current_stock'] ?? 0).milli,
        'json': jsonEncode(row),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> upsertCustomers(List<Map<String, dynamic>> rows) async {
    final db = await _database;
    final batch = db.batch();
    for (final row in rows) {
      if (row['deleted'] == true) {
        batch.delete('customers', where: 'id = ?', whereArgs: [row['id']]);
        continue;
      }
      batch.insert('customers', {
        'id': row['id'],
        'search_key': searchKey(row['name'] as String? ?? ''),
        'phone': row['phone'] ?? '',
        'status': row['status'] ?? 'active',
        'balance_cents': Money.parse('${row['balance'] ?? '0.00'}').cents,
        'json': jsonEncode(row),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static const _stockOverlay = '''
    p.stock_milli + COALESCE((SELECT SUM(e.delta) FROM effects e JOIN outbox o ON o.seq = e.seq
      WHERE e.kind = 'stock' AND e.ref_id = p.id AND o.overlay = 1), 0)''';

  static const _balanceOverlay = '''
    c.balance_cents + COALESCE((SELECT SUM(e.delta) FROM effects e JOIN outbox o ON o.seq = e.seq
      WHERE e.kind = 'balance' AND e.ref_id = c.id AND o.overlay = 1), 0)''';

  /// NFR-03: active products whose name contains [query] or whose barcode is exactly [query].
  Future<List<Product>> searchProducts(String query, {int limit = 50}) async {
    final q = query.trim();
    final rows = await (await _database).rawQuery(
      'SELECT p.json, $_stockOverlay AS stock FROM products p '
      "WHERE p.status = 'active' ${q.isEmpty ? '' : 'AND (p.search_key LIKE ? OR p.barcode = ?)'} "
      'ORDER BY p.search_key LIMIT ?',
      [if (q.isNotEmpty) ...['%${searchKey(q)}%', q], limit],
    );
    return [for (final row in rows) _product(row)];
  }

  Future<Product?> productByBarcode(String barcode) async {
    final rows = await (await _database).rawQuery(
      "SELECT p.json, $_stockOverlay AS stock FROM products p WHERE p.barcode = ? AND p.status = 'active' LIMIT 1",
      [barcode.trim()],
    );
    return rows.isEmpty ? null : _product(rows.first);
  }

  /// By name or phone; [all] includes inactive customers (the customer tab).
  Future<List<Customer>> searchCustomers(String query, {bool all = false, int limit = 30}) async {
    final q = query.trim();
    final phone = q.replaceAll(RegExp(r'\s+'), '');
    final rows = await (await _database).rawQuery(
      'SELECT c.json, $_balanceOverlay AS balance FROM customers c WHERE 1 = 1 '
      "${all ? '' : "AND c.status = 'active' "}"
      "${q.isEmpty ? '' : 'AND (c.search_key LIKE ? OR c.phone LIKE ?) '}"
      'ORDER BY c.id DESC LIMIT ?',
      [if (q.isNotEmpty) ...['%${searchKey(q)}%', '%$phone%'], limit],
    );
    return [for (final row in rows) _customer(row)];
  }

  Future<Customer?> customer(int id) async {
    final rows = await (await _database).rawQuery(
      'SELECT c.json, $_balanceOverlay AS balance FROM customers c WHERE c.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _customer(rows.first);
  }

  static Product _product(Map<String, Object?> row) {
    final json = jsonDecode(row['json']! as String) as Map<String, dynamic>;
    final product = Product.fromJson(json);
    final stock = Quantity.milli(row['stock']! as int);
    return Product(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      unit: product.unit,
      sellingPrice: product.sellingPrice,
      costPrice: product.costPrice,
      currentStock: stock,
      minimumStock: product.minimumStock,
      isLowStock: stock <= product.minimumStock,
      isActive: product.isActive,
      packSize: product.packSize,
      packPrice: product.packPrice,
    );
  }

  static Customer _customer(Map<String, Object?> row) {
    final json = jsonDecode(row['json']! as String) as Map<String, dynamic>;
    return Customer.fromJson({...json, 'balance': Money.cents(row['balance']! as int).toApi()});
  }

  // ---- outbox (offline writes) ----

  /// US-1103 local commit: the queued item and its stock / balance effects in one transaction.
  /// Refused at [limit] unsynced items (BR-12); nothing is ever dropped to make room.
  Future<OutboxItem> enqueue({
    required String clientTransactionId,
    required int? userId,
    required String type,
    required Map<String, dynamic> payload,
    required Map<String, dynamic> summary,
    required List<OutboxEffect> effects,
    List<Map<String, dynamic>> charged = const [],
    DateTime? occurredAt,
  }) async {
    final db = await _database;
    final at = occurredAt ?? DateTime.now();
    return db.transaction((txn) async {
      final pending = Sqflite.firstIntValue(
            await txn.rawQuery("SELECT COUNT(*) FROM outbox WHERE state = 'pending'"),
          ) ??
          0;
      if (pending >= limit) throw QueueFull(pending);

      final seq = await txn.insert('outbox', {
        'ctid': clientTransactionId,
        'user_id': userId,
        'type': type,
        'payload': jsonEncode(payload),
        'charged': jsonEncode(charged),
        'occurred_at': _iso(at),
        'state': OutboxState.pending.name,
        'summary': jsonEncode(summary),
        'created_at': DateTime.now().microsecondsSinceEpoch,
      });
      for (final effect in effects) {
        await txn.insert('effects', {'seq': seq, 'kind': effect.kind, 'ref_id': effect.refId, 'delta': effect.delta});
      }
      final rows = await txn.query('outbox', where: 'seq = ?', whereArgs: [seq]);
      return OutboxItem._fromRow(rows.first);
    });
  }

  /// The oldest pending items of [userId], in FIFO order.
  Future<List<OutboxItem>> pending({int? userId, int limit = 50}) async {
    final rows = await (await _database).query(
      'outbox',
      where: "state = 'pending'${userId == null ? '' : ' AND user_id = ?'}",
      whereArgs: [?userId],
      orderBy: 'seq',
      limit: limit,
    );
    return [for (final row in rows) OutboxItem._fromRow(row)];
  }

  /// The sync screen (SCR-M-16): pending and held items, newest first.
  Future<List<OutboxItem>> items({required Set<OutboxState> states, int limit = 200}) async {
    final rows = await (await _database).query(
      'outbox',
      where: 'state IN (${List.filled(states.length, '?').join(', ')})',
      whereArgs: [for (final s in states) s.name],
      orderBy: 'seq DESC',
      limit: limit,
    );
    return [for (final row in rows) OutboxItem._fromRow(row)];
  }

  Future<OutboxCounts> counts() async {
    final rows = await (await _database).rawQuery(
      "SELECT SUM(state = 'pending') AS pending, SUM(state = 'review') AS review, "
      "SUM(state = 'pending' AND attempts > 10) AS stuck FROM outbox",
    );
    final row = rows.first;
    return OutboxCounts(
      pending: (row['pending'] as int?) ?? 0,
      review: (row['review'] as int?) ?? 0,
      stuck: (row['stuck'] as int?) ?? 0,
    );
  }

  /// The server answered for this item: applied / duplicate / flagged → done; held → review.
  Future<void> settle(String clientTransactionId, {required OutboxState state, String? serverId, List<String> flags = const [], String? error}) async {
    await (await _database).update(
      'outbox',
      {
        'state': state.name,
        'server_id': serverId,
        'flags': jsonEncode(flags),
        'last_error': error,
        'synced_at': DateTime.now().microsecondsSinceEpoch,
      },
      where: 'ctid = ?',
      whereArgs: [clientTransactionId],
    );
  }

  /// A technical failure: the item stays pending and counts towards "stuck" (D-18).
  Future<void> failed(Iterable<String> clientTransactionIds, String error) async {
    final ids = clientTransactionIds.toList();
    if (ids.isEmpty) return;
    await (await _database).rawUpdate(
      'UPDATE outbox SET attempts = attempts + 1, last_error = ? WHERE ctid IN (${List.filled(ids.length, '?').join(', ')})',
      [error, ...ids],
    );
  }

  /// A refresh that started at [refreshStartedAt] already holds the server's numbers for every
  /// item answered before it, so their local effects stop counting. Old answered items are pruned.
  Future<void> releaseEffects(DateTime refreshStartedAt) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE outbox SET overlay = 0 WHERE state != 'pending' AND synced_at IS NOT NULL AND synced_at <= ?",
        [refreshStartedAt.microsecondsSinceEpoch],
      );
      final cutoff = DateTime.now().subtract(const Duration(days: 7)).microsecondsSinceEpoch;
      await txn.rawDelete(
        "DELETE FROM effects WHERE seq IN (SELECT seq FROM outbox WHERE state = 'done' AND overlay = 0 AND synced_at < ?)",
        [cutoff],
      );
      await txn.rawDelete("DELETE FROM outbox WHERE state = 'done' AND overlay = 0 AND synced_at < ?", [cutoff]);
    });
  }

  Future<void> close() async {
    final db = _db;
    _db = null;
    if (db != null) await (await db).close();
  }

  /// The business time as sent to the server (BR-08).
  static String _iso(DateTime value) => value.toUtc().toIso8601String();

  /// Lower case, without tashkeel or tatweel, with one alef / yaa / haa form: «أحمد» finds «احمد».
  static String searchKey(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}
