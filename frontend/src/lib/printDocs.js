import { dateTime, isPositiveAmount, shekel } from "./format";
import { methodLabel } from "./domain";

// What each document prints, for components/PrintSheet.jsx. The same documents as the mobile app:
// a table of item, quantity, price and amount, then the totals with the one that matters boxed.

const qty = (quantity, unit) => (unit === "kg" ? `${quantity} كغ` : String(quantity));

/** A table cell under a header that already says it is money: `1,245.50`. */
const amount = (value) => shekel(value).replace("₪ ", "");

const cartons = (i) => (i.loose_pieces ? `${i.cartons} كرتونة + ${i.loose_pieces} قطعة` : `${i.cartons} كرتونة`);

export function saleDoc(s) {
  return {
    title: "فاتورة مبيعات",
    number: `#${s.id}`,
    stamp: s.status === "voided" ? "ملغاة" : null,
    facts: [
      ["التاريخ", dateTime(s.created_at)],
      ...(s.seller ? [["البائع", s.seller.name]] : []),
      ...(s.customer ? [["الزبون", s.customer.name]] : []),
    ],
    rows: (s.items ?? []).map((i) => ({
      name: i.item_name,
      detail: i.pack_size ? `= ${Number(i.quantity) * i.pack_size} قطعة` : null,
      quantity: i.pack_size ? `${i.quantity} كرتونة` : qty(i.quantity, i.unit),
      price: amount(i.unit_price),
      amount: amount(i.line_total),
    })),
    totals: [
      ...(isPositiveAmount(s.discount_amount)
        ? [
            ["المجموع", shekel(s.subtotal_amount)],
            ["الخصم", shekel(s.discount_amount)],
          ]
        : []),
      ["الإجمالي", shekel(s.total_amount), true],
      ...(isPositiveAmount(s.paid_amount) ? [[`المدفوع · ${methodLabel(s.payment_method)}`, shekel(s.paid_amount)]] : []),
      ...(isPositiveAmount(s.debt_amount) ? [["المتبقي دين", shekel(s.debt_amount)]] : []),
      ...(isPositiveAmount(s.returned_amount) ? [["المرتجعات", shekel(s.returned_amount)]] : []),
    ],
    footer: `عدد الأصناف: ${(s.items ?? []).length} · شكراً لتعاملكم معنا`,
  };
}

export function saleReturnDoc(r, invoiceId = r.invoice_id, customerName = r.customer?.name) {
  return {
    title: "مرتجع مبيعات",
    number: `#${r.id}`,
    facts: [
      ["عن الفاتورة", `#${invoiceId}`],
      ["التاريخ", dateTime(r.created_at)],
      ...(customerName ? [["الزبون", customerName]] : []),
      ...(r.created_by ? [["بواسطة", r.created_by]] : []),
    ],
    rows: (r.items ?? []).map((i) => ({
      name: i.item_name,
      detail: i.damaged ? "تالفة" : null,
      quantity: qty(i.quantity, i.unit),
      amount: amount(i.total),
    })),
    totals: [
      ["الإجمالي", shekel(r.total_amount), true],
      ...(isPositiveAmount(r.debt_reduction) ? [["يُخصم من الدين", shekel(r.debt_reduction)]] : []),
      ...(isPositiveAmount(r.refund_amount) ? [["يُعاد للزبون نقداً", shekel(r.refund_amount)]] : []),
    ],
    note: `السبب: ${r.reason}`,
  };
}

export function purchaseDoc(p) {
  return {
    title: "فاتورة مشتريات",
    number: `#${p.id}`,
    facts: [["المورد", p.supplier.name], ["التاريخ", dateTime(p.at)], ...(p.by ? [["بواسطة", p.by]] : [])],
    rows: (p.items ?? []).map((i) => ({
      name: i.item_name,
      quantity: i.cartons != null ? cartons(i) : qty(i.quantity, i.unit),
      price: amount(i.buy_price),
      amount: amount(i.line_total),
    })),
    totals: [
      ["الإجمالي", shekel(p.total), true],
      ...(isPositiveAmount(p.returned_amount) ? [["المرتجعات", shekel(p.returned_amount)]] : []),
    ],
  };
}

export function purchaseReturnDoc(r, supplierName = r.supplier?.name) {
  return {
    title: "مرتجع مشتريات",
    number: `#${r.id}`,
    facts: [
      ...(supplierName ? [["المورد", supplierName]] : []),
      ["عن الفاتورة", `#${r.purchase_invoice_id}`],
      ["التاريخ", dateTime(r.created_at)],
      ...(r.created_by ? [["بواسطة", r.created_by]] : []),
    ],
    rows: (r.items ?? []).map((i) => ({
      name: i.item_name,
      detail: i.from_stock ? null : "خارج المخزن",
      quantity: qty(i.quantity, i.unit),
      amount: amount(i.total),
    })),
    totals: [
      ["الإجمالي", shekel(r.total_amount), true],
      ...(isPositiveAmount(r.balance_reduction) ? [["يُخصم من حساب المورد", shekel(r.balance_reduction)]] : []),
      ...(isPositiveAmount(r.refund_amount) ? [["يردّه المورد نقداً", shekel(r.refund_amount)]] : []),
    ],
    note: `السبب: ${r.reason}`,
  };
}
