import '../../../core/money/fixed_point.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/app_user.dart';
import '../../goods/domain/goods.dart';
import '../../returns/domain/returns.dart';
import '../../sale/data/sale_repository.dart';
import '../../sale/presentation/checkout_screen.dart' show paymentMethodLabel;
import '../../sale/presentation/sale_widgets.dart' show amountOnly, dayMonthYear, shekel;
import '../domain/print_document.dart';

String _stamp(DateTime at) =>
    '${dayMonthYear(at)}  ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

PrintDocument _document({
  required AppLocalizations t,
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
  columns: (t.invItem, t.invQty, t.invPrice, t.invAmount),
  rows: rows,
  totals: totals,
  stamp: stamp,
  note: note,
  footer: footer,
);

String _quantity(AppLocalizations t, Quantity quantity, ProductUnit unit) =>
    unit == ProductUnit.kg ? '${quantity.format(unit)} ${t.kgShort}' : quantity.format(unit);

/// The sales invoice: one table row per line, then subtotal, discount, the boxed total, what was
/// paid and what is left on credit.
PrintDocument saleDocument(AppLocalizations t, SaleReceipt r, AppUser? user) {
  // Pieces are the plain count, as on any shop invoice; kilos and cartons say their unit.
  String quantity(SaleLine line) => line.isPack
      ? '${line.quantity.format(line.unit)} ${t.packWord}'
      : _quantity(t, line.quantity, line.unit);

  final returned = r.returned;
  return _document(
    t: t,
    user: user,
    title: t.docSale,
    number: r.isPending ? r.localRef! : '#${r.id}',
    stamp: r.isVoided ? t.voidedStamp : null,
    facts: [
      if (r.createdAt != null) (t.receiptDate, _stamp(r.createdAt!)),
      if ((r.sellerName ?? user?.name) != null) (t.receiptSeller, r.sellerName ?? user!.name),
      if (r.customerName != null) (t.customerLabel, r.customerName!),
    ],
    rows: [
      for (final line in r.lines)
        PrintRow(
          name: line.name,
          detail: line.isPack ? t.packEquals(line.baseQuantity.format(ProductUnit.piece)) : null,
          quantity: quantity(line),
          price: amountOnly(line.unitPrice),
          amount: amountOnly(line.lineTotal),
        ),
    ],
    totals: [
      if (r.discount.isPositive) ...[
        PrintTotal(t.subtotalWord, shekel(r.subtotal)),
        PrintTotal(t.discountWord, shekel(r.discount)),
      ],
      PrintTotal(t.totalWord, shekel(r.total), strong: true),
      if (r.paid.isPositive) PrintTotal('${t.paidWord} · ${paymentMethodLabel(t, r.paymentMethod)}', shekel(r.paid)),
      if (r.debt.isPositive) PrintTotal(t.remainingAsDebt, shekel(r.debt)),
      if (returned != null && returned.isPositive) PrintTotal(t.docReturned, shekel(returned)),
    ],
    footer: '${t.invItemsCount(r.lines.length)} · ${t.docThanks}',
  );
}

PrintDocument saleReturnDocument(AppLocalizations t, SaleReturnRecord r, AppUser? user) => _document(
  t: t,
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
        detail: line.flagged ? t.docDamaged : null,
        quantity: _quantity(t, line.quantity, line.unit),
        amount: amountOnly(line.total),
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
  t: t,
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
        quantity: line.cartons == null
            ? _quantity(t, line.quantity, line.unit)
            : line.loosePieces > 0
            ? t.purchaseCartonsLoose('${line.cartons}', '${line.loosePieces}')
            : '${line.cartons} ${t.packWord}',
        price: amountOnly(line.buyPrice),
        amount: amountOnly(line.total),
      ),
  ],
  totals: [
    PrintTotal(t.totalWord, shekel(p.row.total), strong: true),
    if (p.row.returned.isPositive) PrintTotal(t.docReturned, shekel(p.row.returned)),
  ],
);

PrintDocument purchaseReturnDocument(AppLocalizations t, PurchaseReturnRecord r, AppUser? user) => _document(
  t: t,
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
        detail: line.flagged ? t.docOffShelf : null,
        quantity: _quantity(t, line.quantity, line.unit),
        amount: amountOnly(line.total),
      ),
  ],
  totals: [
    PrintTotal(t.totalWord, shekel(r.total), strong: true),
    if (r.toBalance.isPositive) PrintTotal(t.docToBalance, shekel(r.toBalance)),
    if (r.refund.isPositive) PrintTotal(t.docRefundFromSupplier, shekel(r.refund)),
  ],
  note: t.docReason(r.reason),
);
