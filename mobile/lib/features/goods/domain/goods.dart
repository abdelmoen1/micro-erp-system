import '../../../core/money/fixed_point.dart';

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
  final Quantity kilos;
  final String sellingPrice;

  /// Per carton, or per kilo for a weighed item. Null until it is typed.
  final Money? buyPrice;

  /// What a whole carton sells for, wholesale. Null until it is typed; never for a weighed item.
  final Money? cartonPrice;

  bool get isWeighed => kind == GoodsKind.weight;

  int get pieces => cartons * packSize;

  /// A "carton" of one piece has no wholesale price.
  bool get sellsByCarton => !isWeighed && packSize > 1;

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
    kilos: kilos,
    buyPrice: buy,
    cartonPrice: carton,
  );

  Map<String, Object?> toApi() => {
    'product_id': ?productId,
    'name': name,
    'barcode': ?barcode,
    'unit': kind.unit.apiValue,
    if (isWeighed) 'quantity': kilos.toString() else ...{'cartons': cartons, 'pack_size': packSize},
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

/// A product bought from a supplier, with what is left to pay for it.
class SupplierProduct {
  const SupplierProduct({required this.id, required this.name, required this.balance});

  factory SupplierProduct.fromJson(Map<String, dynamic> json) => SupplierProduct(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    balance: Money.parse(json['balance'] as String? ?? '0'),
  );

  final int id;
  final String name;
  final Money balance;
}

class SupplierDetail {
  const SupplierDetail({required this.supplier, required this.products});

  factory SupplierDetail.fromJson(Map<String, dynamic> json) => SupplierDetail(
    supplier: Supplier.fromJson(json),
    products: [
      for (final row in json['products'] as List<dynamic>? ?? const [])
        SupplierProduct.fromJson(row as Map<String, dynamic>),
    ],
  );

  final Supplier supplier;
  final List<SupplierProduct> products;
}

DateTime _time(Object? value) => DateTime.tryParse(value as String? ?? '')?.toLocal() ?? DateTime.now();

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
  final String? by;
}

class ProductPayment {
  const ProductPayment({required this.at, required this.amount, required this.method, this.by});

  factory ProductPayment.fromJson(Map<String, dynamic> json) => ProductPayment(
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

/// One product at one supplier: what is left, then its invoices and payments.
class ProductAccount {
  const ProductAccount({
    required this.productName,
    required this.weighed,
    required this.balance,
    required this.invoices,
    required this.payments,
  });

  factory ProductAccount.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    return ProductAccount(
      productName: product['name'] as String? ?? '',
      weighed: product['unit'] == 'kg',
      balance: Money.parse(json['balance'] as String? ?? '0'),
      invoices: [
        for (final row in json['invoices'] as List<dynamic>? ?? const [])
          ProductInvoice.fromJson(row as Map<String, dynamic>),
      ],
      payments: [
        for (final row in json['payments'] as List<dynamic>? ?? const [])
          ProductPayment.fromJson(row as Map<String, dynamic>),
      ],
    );
  }

  final String productName;
  final bool weighed;
  final Money balance;
  final List<ProductInvoice> invoices;
  final List<ProductPayment> payments;
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
