/// One printed line: the item, how much of it at what price, and its amount.
class PrintRow {
  const PrintRow({required this.name, required this.amount, this.detail});

  final String name;
  final String? detail;
  final String amount;
}

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
    this.stamp,
    this.note,
    this.footer,
  });

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
