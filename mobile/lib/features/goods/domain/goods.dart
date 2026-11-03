import '../../../core/money/fixed_point.dart';
import '../../returns/domain/returns.dart';

/// Goods arrive by the carton or by weight. A carton always has a barcode; a weighed item never does.
enum GoodsKind {
  carton,
  weight;

  ProductUnit get unit => this == weight ? ProductUnit.kg : ProductUnit.piece;
}

/// One line of a delivery. Its buying and carton prices are added on the supplier step.
class GoodsLine {
  const GoodsLine({
    required this.name,
    required this.kind,
    required this.sellingPrice,
    this.productId,
    this.barcode,
    this.cartons = 0,
    this.packSize = 1,
    this.loosePieces = 0,
    this.kilos = Quantity.zero,
    this.buyPrice,
    this.cartonPrice,
  });

  final int? productId;
  final String name;
  final String? barcode;
  final GoodsKind kind;
  final int cartons;
  final int packSize;

  /// Pieces of an opened carton, next to the whole [cartons].
  final int loosePieces;
  final Quantity kilos;
  final String sellingPrice;

  /// Per carton, or per kilo for a weighed item. Null until it is typed.
  final Money? buyPrice;

  /// What a whole carton sells for, wholesale. Null until it is typed; never for a weighed item.
  final Money? cartonPrice;

  bool get isWeighed => kind == GoodsKind.weight;

  int get pieces => cartons * packSize + loosePieces;

  /// A "carton" of one piece has no wholesale price.
  bool get sellsByCarton => !isWeighed && packSize > 1;

  /// Half-up like the server, which recomputes it (the total is never sent).
  Money get total {
    final price = buyPrice ?? Money.zero;
    // Loose pieces cost their share of the carton price.
    if (!isWeighed) return Money.cents((price.cents * pieces * 2 + packSize) ~/ (packSize * 2));
    return Money.cents((price.cents * kilos.milli + 500) ~/ 1000);
  }

  /// What one piece costs, for the line under the carton price.
  Money? get pieceCost {
    final price = buyPrice;
    if (price == null || isWeighed || packSize < 1) return null;
    return Money.cents((price.cents * 2 + packSize) ~/ (packSize * 2));
  }

  /// The carton sells above one piece: a lower figure is the piece price in the wrong field.
  bool get cartonPriceOk {
    if (!sellsByCarton) return true;
    final price = cartonPrice;
    return price != null && price > Money.parse(sellingPrice);
  }

  GoodsLine withPrices({Money? buy, Money? carton}) => GoodsLine(
    name: name,
    kind: kind,
    sellingPrice: sellingPrice,
    productId: productId,
    barcode: barcode,
    cartons: cartons,
    packSize: packSize,
    loosePieces: loosePieces,
    kilos: kilos,
    buyPrice: buy,
    cartonPrice: carton,
  );

  Map<String, Object?> toApi() => {
    'product_id': ?productId,
    'name': name,
    'barcode': ?barcode,
    'unit': kind.unit.apiValue,
    if (isWeighed)
      'quantity': kilos.toString()
    else ...{'cartons': cartons, 'pack_size': packSize, if (loosePieces > 0) 'loose_pieces': loosePieces},
    'buy_price': buyPrice?.toApi(),
    'selling_price': sellingPrice,
    if (sellsByCarton) 'carton_price': cartonPrice?.toApi(),
  };
}

class Supplier {
  const Supplier({required this.id, required this.name, required this.balance});

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    balance: Money.parse(json['balance'] as String? ?? '0'),
  );

  final int id;
  final String name;

  /// What the store still owes this supplier.
  final Money balance;
}

/// A product bought from a supplier, with everything bought of it so far.
class SupplierProduct {
  const SupplierProduct({required this.id, required this.name, required this.total});

  factory SupplierProduct.fromJson(Map<String, dynamic> json) => SupplierProduct(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    total: Money.parse(json['total'] as String? ?? '0'),
  );

  final int id;
  final String name;
  final Money total;
}

DateTime _time(Object? value) => DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

/// A payment to the supplier: it lowers the total owed to them.
class SupplierPayment {
  const SupplierPayment({required this.at, required this.amount, required this.method, this.by});

  factory SupplierPayment.fromJson(Map<String, dynamic> json) => SupplierPayment(
    at: _time(json['at']),
    amount: Money.parse(json['amount'] as String? ?? '0'),
    method: json['method'] as String? ?? 'cash',
    by: json['by'] as String?,
  );

  final DateTime at;
  final Money amount;
  final String method;
  final String? by;
}

/// One supplier: what is owed in all, the products bought, and the payments made.
class SupplierDetail {
  const SupplierDetail({required this.supplier, required this.products, required this.payments, this.returns = const []});

  factory SupplierDetail.fromJson(Map<String, dynamic> json) => SupplierDetail(
    supplier: Supplier.fromJson(json),
    products: [
      for (final row in json['products'] as List<dynamic>? ?? const [])
        SupplierProduct.fromJson(row as Map<String, dynamic>),
    ],
    payments: [
      for (final row in json['payments'] as List<dynamic>? ?? const [])
        SupplierPayment.fromJson(row as Map<String, dynamic>),
    ],
    returns: [
      for (final row in json['returns'] as List<dynamic>? ?? const [])
        PurchaseReturnRecord.fromJson(row as Map<String, dynamic>),
    ],
  );

  final Supplier supplier;
  final List<SupplierProduct> products;
  final List<SupplierPayment> payments;
  final List<PurchaseReturnRecord> returns;
}

/// One delivery of a product from the supplier.
class ProductInvoice {
  const ProductInvoice({
    required this.number,
    required this.at,
    required this.quantity,
    required this.buyPrice,
    required this.total,
    this.cartons,
    this.packSize,
    this.loosePieces = 0,
    this.by,
  });

  factory ProductInvoice.fromJson(Map<String, dynamic> json) => ProductInvoice(
    number: (json['invoice_id'] as num).toInt(),
    at: _time(json['at']),
    quantity: json['quantity'] as String? ?? '0',
    buyPrice: Money.parse(json['buy_price'] as String? ?? '0'),
    total: Money.parse(json['total'] as String? ?? '0'),
    cartons: (json['cartons'] as num?)?.toInt(),
    packSize: (json['pack_size'] as num?)?.toInt(),
    loosePieces: (json['loose_pieces'] as num?)?.toInt() ?? 0,
    by: json['by'] as String?,
  );

  final int number;
  final DateTime at;

  /// Pieces, or kg for a weighed product.
  final String quantity;

  /// Per carton, or per kilo for a weighed product.
  final Money buyPrice;
  final Money total;
  final int? cartons;
  final int? packSize;
  final int loosePieces;
  final String? by;
}

/// One product at one supplier: its invoices.
class ProductInvoices {
  const ProductInvoices({required this.weighed, required this.invoices});

  factory ProductInvoices.fromJson(Map<String, dynamic> json) => ProductInvoices(
    weighed: (json['product'] as Map<String, dynamic>)['unit'] == 'kg',
    invoices: [
      for (final row in json['invoices'] as List<dynamic>? ?? const [])
        ProductInvoice.fromJson(row as Map<String, dynamic>),
    ],
  );

  final bool weighed;
  final List<ProductInvoice> invoices;
}

/// A row of the purchases register.
class PurchaseRow {
  const PurchaseRow({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.total,
    required this.returned,
    required this.linesCount,
    required this.at,
    this.by,
  });

  factory PurchaseRow.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>? ?? const {};
    return PurchaseRow(
      id: (json['id'] as num).toInt(),
      supplierId: (supplier['id'] as num?)?.toInt() ?? 0,
      supplierName: supplier['name'] as String? ?? '',
      total: Money.parse(json['total'] as String? ?? '0'),
      returned: Money.parse(json['returned_amount'] as String? ?? '0'),
      linesCount: (json['lines_count'] as num?)?.toInt() ?? 0,
      at: _time(json['at']),
      by: json['by'] as String?,
    );
  }

  final int id;
  final int supplierId;
  final String supplierName;
  final Money total;
  final Money returned;
  final int linesCount;
  final DateTime at;
  final String? by;
}

/// One line of a purchase invoice. Quantities are pieces, or kg for a weighed product.
class PurchaseLine {
  const PurchaseLine({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.returned,
    required this.buyPrice,
    required this.total,
    this.cartons,
    this.loosePieces = 0,
  });

  factory PurchaseLine.fromJson(Map<String, dynamic> json) => PurchaseLine(
    id: (json['id'] as num).toInt(),
    name: json['item_name'] as String? ?? '',
    unit: ProductUnit.fromApi(json['unit']),
    quantity: Quantity.parse(json['quantity'] ?? '0'),
    returned: Quantity.parse(json['returned_quantity'] ?? '0'),
    buyPrice: Money.parse(json['buy_price'] as String? ?? '0'),
    total: Money.parse(json['line_total'] as String? ?? '0'),
    cartons: (json['cartons'] as num?)?.toInt(),
    loosePieces: (json['loose_pieces'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String name;
  final ProductUnit unit;
  final Quantity quantity;
  final Quantity returned;

  /// Per carton, or per kilo for a weighed product.
  final Money buyPrice;
  final Money total;
  final int? cartons;

  /// Pieces of an opened carton that came with the whole ones.
  final int loosePieces;

  Quantity get returnable => quantity - returned;

  /// This line's share for the preview, half-up; the server's figure is the final one.
  Money valueOf(Quantity part) => Money.cents((total.cents * part.milli * 2 + quantity.milli) ~/ (quantity.milli * 2));
}

/// A purchase invoice in full.
class PurchaseDetail {
  const PurchaseDetail({required this.row, required this.lines, required this.returns});

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) => PurchaseDetail(
    row: PurchaseRow.fromJson(json),
    lines: [for (final row in json['items'] as List<dynamic>? ?? const []) PurchaseLine.fromJson(row as Map<String, dynamic>)],
    returns: [
      for (final row in json['returns'] as List<dynamic>? ?? const [])
        PurchaseReturnRecord.fromJson(row as Map<String, dynamic>),
    ],
  );

  final PurchaseRow row;
  final List<PurchaseLine> lines;
  final List<PurchaseReturnRecord> returns;
}

/// The server's answer to a recorded delivery.
class GoodsReceipt {
  const GoodsReceipt({required this.supplierName, required this.total, required this.at});

  factory GoodsReceipt.fromJson(Map<String, dynamic> json) => GoodsReceipt(
    supplierName: (json['supplier'] as Map<String, dynamic>)['name'] as String? ?? '',
    total: Money.parse(json['total'] as String),
    at: _time(json['at']),
  );

  final String supplierName;
  final Money total;
  final DateTime at;
}
