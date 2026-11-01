import '../../../core/money/fixed_point.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/app_user.dart';
import '../../goods/domain/goods.dart';
import '../../returns/domain/returns.dart';
import '../../sale/data/sale_repository.dart';
import '../../sale/presentation/checkout_screen.dart' show paymentMethodLabel;
import '../../sale/presentation/sale_widgets.dart' show dayMonthYear, shekel;
import '../domain/print_document.dart';

String _stamp(DateTime at) =>
    '${dayMonthYear(at)}  ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

PrintDocument _document({
  required AppUser? user,
  required String title,
  required String number,
  required List<(String, String)> facts,
  required List<PrintRow> rows,
  required List<PrintTotal> totals,
  String? stamp,
  String? note,
  String? footer,
}) => PrintDocument(
  title: title,
  number: number,
  storeName: user?.storeName ?? '',
  storePhone: user?.storePhone,
  storeAddress: user?.storeAddress,
  facts: facts,
  rows: rows,
  totals: totals,
  stamp: stamp,
  note: note,
  footer: footer,
);

String _quantity(AppLocalizations t, Quantity quantity, ProductUnit unit) =>
    unit == ProductUnit.kg ? '${quantity.format(unit)} ${t.kgShort}' : quantity.format(unit);

PrintDocument saleDocument(AppLocalizations t, SaleReceipt r, AppUser? user) {
  String detail(SaleLine line) {
    final unit = line.isPack ? t.packWord : (line.unit == ProductUnit.kg ? t.kgShort : t.pieceWord);
    return '${line.quantity.format(line.unit)} $unit × ${shekel(line.unitPrice)}';
  }

  final returned = r.returned;
  return _document(
    user: user,
    title: t.docSale,
    number: r.isPending ? r.localRef! : '#${r.id}',
    stamp: r.isVoided ? t.voidedStamp : null,
    facts: [
      if (r.createdAt != null) (t.receiptDate, _stamp(r.createdAt!)),
      if ((r.sellerName ?? user?.name) != null) (t.receiptSeller, r.sellerName ?? user!.name),
      if (r.customerName != null) (t.customerLabel, r.customerName!),
    ],
    rows: [for (final line in r.lines) PrintRow(name: line.name, detail: detail(line), amount: shekel(line.lineTotal))],
    totals: [
      PrintTotal(t.totalWord, shekel(r.total), strong: true),
      if (r.paid.isPositive) PrintTotal('${t.paidWord} · ${paymentMethodLabel(t, r.paymentMethod)}', shekel(r.paid)),
      if (r.debt.isPositive) PrintTotal(t.remainingAsDebt, shekel(r.debt)),
      if (returned != null && returned.isPositive) PrintTotal(t.docReturned, shekel(returned)),
    ],
    footer: t.docThanks,
  );
}

PrintDocument saleReturnDocument(AppLocalizations t, SaleReturnRecord r, AppUser? user) => _document(
  user: user,
  title: t.docSaleReturn,
  number: '#${r.id}',
  facts: [
    (t.docForInvoice, '#${r.invoiceId}'),
    (t.receiptDate, _stamp(r.at)),
    if (r.customerName != null) (t.customerLabel, r.customerName!),
    if (r.by != null) (t.supplierBy, r.by!),
  ],
  rows: [
    for (final line in r.lines)
      PrintRow(
        name: line.name,
        detail: [_quantity(t, line.quantity, line.unit), if (line.flagged) t.docDamaged].join(' · '),
        amount: shekel(line.total),
      ),
  ],
  totals: [
    PrintTotal(t.totalWord, shekel(r.total), strong: true),
    if (r.toDebt.isPositive) PrintTotal(t.docToDebt, shekel(r.toDebt)),
    if (r.refund.isPositive) PrintTotal(t.docRefunded, shekel(r.refund)),
  ],
  note: t.docReason(r.reason),
);

PrintDocument purchaseDocument(AppLocalizations t, PurchaseDetail p, AppUser? user) => _document(
  user: user,
  title: t.docPurchase,
  number: '#${p.row.id}',
  facts: [
    (t.docSupplier, p.row.supplierName),
    (t.receiptDate, _stamp(p.row.at)),
    if (p.row.by != null) (t.supplierBy, p.row.by!),
  ],
  rows: [
    for (final line in p.lines)
      PrintRow(
        name: line.name,
        detail: line.cartons == null
            ? '${_quantity(t, line.quantity, line.unit)} × ${shekel(line.buyPrice)}'
            : '${line.cartons} ${t.packWord} × ${shekel(line.buyPrice)}',
        amount: shekel(line.total),
      ),
  ],
  totals: [
    PrintTotal(t.totalWord, shekel(p.row.total), strong: true),
    if (p.row.returned.isPositive) PrintTotal(t.docReturned, shekel(p.row.returned)),
  ],
);

PrintDocument purchaseReturnDocument(AppLocalizations t, PurchaseReturnRecord r, AppUser? user) => _document(
  user: user,
  title: t.docPurchaseReturn,
  number: '#${r.id}',
  facts: [
    if (r.supplierName != null) (t.docSupplier, r.supplierName!),
    (t.docForInvoice, '#${r.invoiceId}'),
    (t.receiptDate, _stamp(r.at)),
    if (r.by != null) (t.supplierBy, r.by!),
  ],
  rows: [
    for (final line in r.lines)
      PrintRow(
        name: line.name,
        detail: [_quantity(t, line.quantity, line.unit), if (line.flagged) t.docOffShelf].join(' · '),
        amount: shekel(line.total),
      ),
  ],
  totals: [
    PrintTotal(t.totalWord, shekel(r.total), strong: true),
    if (r.toBalance.isPositive) PrintTotal(t.docToBalance, shekel(r.toBalance)),
    if (r.refund.isPositive) PrintTotal(t.docRefundFromSupplier, shekel(r.refund)),
  ],
  note: t.docReason(r.reason),
);
