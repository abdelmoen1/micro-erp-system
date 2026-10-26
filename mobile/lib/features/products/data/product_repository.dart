import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../../core/money/fixed_point.dart';
import '../domain/product.dart';

/// Read side of the product API for the POS (T-1301-7: scan → lookup) and low-stock lists.
/// The camera scanner itself waits for the US-1305 spike; any barcode source calls [lookupByBarcode].
class ProductRepository {
  ProductRepository(this._api);

  final ApiClient _api;

  /// The active product of my store with this barcode, or null when there is none
  /// (404, also for inactive products: US-0401 AC3). Other failures are thrown.
  Future<Product?> lookupByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    try {
      final body = await _api.get('/products/lookup', query: {'barcode': code});
      return Product.fromJson(body['data'] as Map<String, dynamic>);
    } on NotFound {
      return null;
    }
  }

  /// Shared catalog, before adding a product: my store's product with this barcode (any status)
  /// and the platform-wide item another store already saved. Either may be null.
  Future<CatalogMatch> catalogLookup(String barcode) async {
    final body = await _api.get('/products/catalog-lookup', query: {'barcode': barcode.trim()});
    final data = body['data'] as Map<String, dynamic>;
    final product = data['product'] as Map<String, dynamic>?;
    final item = data['catalog_product'] as Map<String, dynamic>?;
    return CatalogMatch(
      product: product == null ? null : Product.fromJson(product),
      catalogName: item?['name'] as String?,
      catalogUnit: item == null ? null : ProductUnit.fromApi(item['unit']),
    );
  }

  /// Active products whose name contains [query] (or whose barcode is exactly [query]), by name.
  /// M-02 «بحث بالاسم».
  Future<List<Product>> search(String query) async {
    final q = query.trim();
    final body = await _api.get('/products', query: {if (q.isNotEmpty) 'search': q});
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  /// Active products at or below their threshold, lowest stock first (US-0403). First page.
  Future<List<Product>> lowStock() async {
    final body = await _api.get('/products/low-stock');
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  /// M-11: active products by name or barcode; [stock] narrows to `low` or `negative`.
  Future<List<Product>> list({String query = '', String? stock}) async {
    final q = query.trim();
    final body = await _api.get('/products', query: {'per_page': 50, if (q.isNotEmpty) 'search': q, 'stock': ?stock});
    final data = body['data'] as List<dynamic>? ?? const [];
    return [for (final row in data) Product.fromJson(row as Map<String, dynamic>)];
  }

  Future<Product> product(int id) async {
    final body = await _api.get('/products/$id');
    return Product.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// The product's stock ledger, newest first (every role may read it). First 20 movements.
  Future<List<StockMove>> movements(int productId) async {
    final body = await _api.get('/products/$productId/movements');
    return [for (final row in body['data'] as List<dynamic>? ?? const []) StockMove.fromJson(row as Map<String, dynamic>)];
  }

  /// PATCH /products/{id} (Owner / Manager): only the fields given change; the stock never does
  /// (it moves by sales and adjustments only).
  Future<Product> update(int id, Map<String, Object?> fields) async {
    final body = await _api.patch('/products/$id', body: fields);
    return Product.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Stops selling the product; its history stays.
  Future<void> deactivate(int id) => _api.post('/products/$id/deactivate');

  /// Products sold below zero, with their last sales, for the owner's review (D-27).
  Future<List<NegativeStockItem>> negativeStock() async {
    final body = await _api.get('/products/negative-stock');
    return [
      for (final row in body['data'] as List<dynamic>? ?? const [])
        NegativeStockItem.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// S3 · QR add: POST /products (Owner / Manager). Field problems come back as `ValidationFailed`
  /// (a barcode already used, a fraction for a piece product, …) and an employee gets `Forbidden`.
  Future<Product> create(NewProduct draft) async {
    final body = await _api.post('/products', body: draft.toJson());
    return Product.fromJson((body['data'] ?? body['product']) as Map<String, dynamic>);
  }
}

/// GET /products/catalog-lookup: [product] is already in my store; otherwise [catalogName] and
/// [catalogUnit] are the shared details to prefill (the price, cost and stock stay the store's).
class CatalogMatch {
  const CatalogMatch({this.product, this.catalogName, this.catalogUnit});

  final Product? product;
  final String? catalogName;
  final ProductUnit? catalogUnit;

  bool get inCatalog => catalogName != null;
}

/// The fields of POST /products, as the owner confirmed them on the form.
class NewProduct {
  const NewProduct({
    required this.name,
    required this.unit,
    required this.sellingPrice,
    required this.currentStock,
    this.barcode,
    this.costPrice,
    this.minimumStock,
    this.packSize,
    this.packPrice,
  });

  final String name;
  final String? barcode;
  final ProductUnit unit;
  final String sellingPrice;
  final String? costPrice;
  final String currentStock;
  final String? minimumStock;

  /// Wholesale carton, sent only as a pair (piece products): pieces per carton and the carton price.
  final String? packSize;
  final String? packPrice;

  bool get _hasPack => (packSize?.trim().isNotEmpty ?? false) && (packPrice?.trim().isNotEmpty ?? false);

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'barcode': ?(barcode?.trim().isEmpty ?? true ? null : barcode!.trim()),
    'unit': unit.apiValue,
    'selling_price': sellingPrice.trim(),
    'cost_price': ?(costPrice?.trim().isEmpty ?? true ? null : costPrice!.trim()),
    'current_stock': currentStock.trim(),
    'minimum_stock': ?(minimumStock?.trim().isEmpty ?? true ? null : minimumStock!.trim()),
    if (_hasPack && unit == ProductUnit.piece) ...{'pack_size': packSize!.trim(), 'pack_price': packPrice!.trim()},
  };
}

/// One line of a product's stock ledger (GET /products/{id}/movements).
class StockMove {
  const StockMove({
    required this.type,
    required this.quantity,
    required this.balanceAfter,
    this.reason,
    this.invoiceId,
    this.createdAt,
  });

  factory StockMove.fromJson(Map<String, dynamic> json) => StockMove(
    type: json['type'] as String? ?? '',
    quantity: Quantity.parse(json['quantity'] ?? '0'),
    balanceAfter: Quantity.parse(json['balance_after'] ?? '0'),
    reason: json['reason'] as String?,
    invoiceId: json['reference_type'] == 'invoice' ? (json['reference_id'] as num?)?.toInt() : null,
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
  );

  /// `opening`, `sale`, `sale_void`, `sale_return`, `adjustment_in`, `adjustment_out`.
  final String type;

  /// Signed: negative when stock left the shelf.
  final Quantity quantity;
  final Quantity balanceAfter;
  final String? reason;
  final int? invoiceId;
  final DateTime? createdAt;
}

/// A product sold below zero and its latest sales (who sold how much, the balance after).
class NegativeStockItem {
  const NegativeStockItem({required this.product, required this.sales});

  factory NegativeStockItem.fromJson(Map<String, dynamic> json) => NegativeStockItem(
    product: Product.fromJson(json['product'] as Map<String, dynamic>),
    sales: [
      for (final s in json['sales'] as List<dynamic>? ?? const [])
        (
          invoiceId: ((s as Map<String, dynamic>)['invoice_id'] as num?)?.toInt(),
          quantity: s['quantity'] as String? ?? '',
          by: s['created_by'] as String?,
          at: DateTime.tryParse(s['created_at'] as String? ?? '')?.toLocal(),
        ),
    ],
  );

  final Product product;
  final List<({int? invoiceId, String quantity, String? by, DateTime? at})> sales;
}
