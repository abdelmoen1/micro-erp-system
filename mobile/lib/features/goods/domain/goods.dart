import '../../../core/money/fixed_point.dart';

/// Goods arrive by the carton or by weight; a weighed item has no barcode.
enum GoodsKind {
  carton,
  weight;

  ProductUnit get unit => this == weight ? ProductUnit.kg : ProductUnit.piece;
}

/// One line of a delivery. The buying price is added on the supplier step.
class GoodsLine {
  const GoodsLine({
    required this.name,
    required this.kind,
    required this.sellingPrice,
    this.productId,
    this.barcode,
    this.cartons = 0,
    this.packSize = 1,
    this.kilos = Quantity.zero,
    this.buyPrice,
  });

  final int? productId;
  final String name;
  final String? barcode;
  final GoodsKind kind;
  final int cartons;
  final int packSize;
  final Quantity kilos;
  final String sellingPrice;

  /// Per carton, or per kilo for a weighed item. Null until it is typed.
  final Money? buyPrice;

  bool get isWeighed => kind == GoodsKind.weight;

  int get pieces => cartons * packSize;

  /// Half-up like the server, which recomputes it (the total is never sent).
  Money get total {
    final price = buyPrice ?? Money.zero;
    if (!isWeighed) return Money.cents(price.cents * cartons);
    return Money.cents((price.cents * kilos.milli + 500) ~/ 1000);
  }

  /// What one piece costs, for the line under the carton price.
  Money? get pieceCost {
    final price = buyPrice;
    if (price == null || isWeighed || packSize < 1) return null;
    return Money.cents((price.cents * 2 + packSize) ~/ (packSize * 2));
  }

  GoodsLine withBuyPrice(Money? price) => GoodsLine(
    name: name,
    kind: kind,
    sellingPrice: sellingPrice,
    productId: productId,
    barcode: barcode,
    cartons: cartons,
    packSize: packSize,
    kilos: kilos,
    buyPrice: price,
  );

  Map<String, Object?> toApi() => {
    'product_id': ?productId,
    'name': name,
    'barcode': ?barcode,
    'unit': kind.unit.apiValue,
    if (isWeighed) 'quantity': kilos.toString() else ...{'cartons': cartons, 'pack_size': packSize},
    'buy_price': buyPrice?.toApi(),
    'selling_price': sellingPrice,
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

/// A line of the account: an invoice (adds to what is owed) or a payment (lowers it).
class SupplierEntry {
  const SupplierEntry({required this.isInvoice, required this.amount, required this.at, this.method});

  factory SupplierEntry.fromJson(Map<String, dynamic> json) => SupplierEntry(
    isInvoice: json['type'] == 'invoice',
    amount: Money.parse(json['amount'] as String? ?? '0'),
    at: DateTime.tryParse(json['at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    method: json['method'] as String?,
  );

  final bool isInvoice;
  final Money amount;
  final DateTime at;
  final String? method;
}

class SupplierAccount {
  const SupplierAccount({required this.supplier, required this.entries});

  factory SupplierAccount.fromJson(Map<String, dynamic> json) => SupplierAccount(
    supplier: Supplier.fromJson(json),
    entries: [
      for (final row in json['entries'] as List<dynamic>? ?? const [])
        SupplierEntry.fromJson(row as Map<String, dynamic>),
    ],
  );

  final Supplier supplier;
  final List<SupplierEntry> entries;
}

/// The server's answer to a recorded delivery.
class GoodsReceipt {
  const GoodsReceipt({
    required this.supplierId,
    required this.supplierName,
    required this.total,
    required this.paid,
    required this.remaining,
    required this.lines,
  });

  factory GoodsReceipt.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>;
    return GoodsReceipt(
      supplierId: (supplier['id'] as num).toInt(),
      supplierName: supplier['name'] as String? ?? '',
      total: Money.parse(json['total'] as String),
      paid: Money.parse(json['paid'] as String),
      remaining: Money.parse(json['remaining'] as String),
      lines: (json['lines'] as num).toInt(),
    );
  }

  final int supplierId;
  final String supplierName;
  final Money total;
  final Money paid;
  final Money remaining;
  final int lines;
}
