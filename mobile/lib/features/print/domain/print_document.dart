/// One printed line: the item, how much of it at what price, and its amount. With a [quantity] it
/// fills the columns of the invoice table; [detail] is a small line under the item's name.
class PrintRow {
  const PrintRow({required this.name, required this.amount, this.detail, this.quantity, this.price});

  final String name;
  final String? detail;
  final String? quantity;
  final String? price;
  final String amount;
}

/// The headers of the invoice table, in reading order: item, quantity, price, amount.
typedef PrintColumns = (String item, String quantity, String price, String amount);

/// A figure under the lines. [strong] is the one the reader looks for first.
class PrintTotal {
  const PrintTotal(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;
}

/// What goes on paper, whatever the document and the printer: an invoice or a return, for a roll
/// or an A4 sheet. Every text is already in the shop's language and formatted.
class PrintDocument {
  const PrintDocument({
    required this.title,
    required this.number,
    required this.storeName,
    required this.facts,
    required this.rows,
    required this.totals,
    this.storePhone,
    this.storeAddress,
    this.columns,
    this.stamp,
    this.note,
    this.footer,
  });

  /// Rows are printed as a table under these headers; without them, one item under another.
  final PrintColumns? columns;

  final String title;

  /// `#12`, or the local reference of a sale still on the phone.
  final String number;
  final String storeName;
  final String? storePhone;
  final String? storeAddress;

  /// Date, seller, customer or supplier: (label, value).
  final List<(String, String)> facts;
  final List<PrintRow> rows;
  final List<PrintTotal> totals;

  /// «ملغاة» across a voided invoice.
  final String? stamp;

  /// The reason of a return.
  final String? note;
  final String? footer;

  /// The print job's name in the phone's print queue.
  String get jobName => '$title $number';
}
