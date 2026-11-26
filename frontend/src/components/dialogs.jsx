import { useState } from "react";
import { newIdempotencyKey } from "../services/apiClient";
import { useOpeningDebt, usePayCustomer, useSaveCustomer, useVoidPurchaseReturn, useVoidSaleReturn } from "../services/backoffice";
import { DEFAULT_PAYMENT_METHOD, PAYMENT_METHODS } from "../lib/domain";
import { isPositiveAmount, latinDigits, shekel } from "../lib/format";
import { ConfirmSummary, Dialog, ErrorBanner, Field, ReasonField } from "./ui";

// Dialogs shared by several back-office screens (W-07, W-13, W-14).


const AMOUNT = /^\d{1,8}(\.\d{1,2})?$/;

/** Cents as an integer from a 2-decimal string, for comparisons only (never shown). */
const cents = (value) => {
  const [whole, fraction = ""] = String(value ?? "0").split(".");
  return Number(whole) * 100 + Number(fraction.padEnd(2, "0").slice(0, 2));
};
const fromCents = (n) => `${Math.floor(n / 100)}.${String(n % 100).padStart(2, "0")}`;

/**
 * W-14 / M-09 record payment: the whole remaining balance by default, or another amount that the
 * server allocates to the oldest due debts first. The summary shows what remains before confirm.
 */
export function RecordPaymentDialog({ customer, remaining, onClose, onDone }) {
  const [full, setFull] = useState(true);
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState(DEFAULT_PAYMENT_METHOD);
  const [key] = useState(newIdempotencyKey);
  const pay = usePayCustomer();

  const value = full ? remaining : amount.trim();
  const invalid = !full && (!AMOUNT.test(value) || cents(value) === 0);
  const over = !full && !invalid && cents(value) > cents(remaining);
  const after = invalid || over ? "—" : shekel(fromCents(cents(remaining) - cents(value)));

  const submit = (e) => {
    e.preventDefault();
    if (invalid || over) return;
    pay.mutate(
      { customerId: customer.id, amount: full ? null : value, method, key },
      { onSuccess: (r) => (onDone ?? onClose)(r) },
    );
  };

  return (
    <Dialog title={`تسجيل دفعة من ${customer.name}`} onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <p className="field-hint">
          المتبقي عليه <b className="m">{shekel(remaining)}</b>
        </p>
        <div className="chips" role="group" aria-label="المبلغ">
          <button type="button" className="chip" aria-pressed={full} onClick={() => setFull(true)}>
            كامل المتبقي
          </button>
          <button type="button" className="chip" aria-pressed={!full} onClick={() => setFull(false)}>
            مبلغ آخر
          </button>
        </div>
        {!full ? (
          <Field id="pay-amount" label="المبلغ" required error={over ? `المبلغ أكبر من المتبقي (${shekel(remaining)}).` : amount && invalid ? "أدخل مبلغاً صحيحاً بخانتين عشريتين على الأكثر." : pay.error?.fieldError?.("amount")}>
            <input id="pay-amount" className="fld ltr m" inputMode="decimal" value={amount} onChange={(e) => setAmount(latinDigits(e.target.value))} autoComplete="off" />
          </Field>
        ) : null}
        <div className="field">
          <span className="field-label" id="pay-method">
            طريقة الدفع
          </span>
          <div className="chips" role="group" aria-labelledby="pay-method">
            {PAYMENT_METHODS.map(([key2, label]) => (
              <button key={key2} type="button" className="chip" aria-pressed={method === key2} onClick={() => setMethod(key2)}>
                {label}
              </button>
            ))}
          </div>
        </div>
        <ConfirmSummary
          rows={[
            ["المتبقي الآن", shekel(remaining)],
            ["الدفعة", invalid ? "—" : `−${shekel(value)}`],
          ]}
          total={["المتبقي بعد الدفعة", after, "var(--debt-fg)"]}
        />
        {!full ? <p className="field-hint">تُوزَّع الدفعة على الديون من الأقدم استحقاقاً.</p> : null}
        <ErrorBanner error={pay.error && !pay.error.fieldError?.("amount") ? pay.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={pay.isPending || invalid || over}>
            {pay.isPending ? "جارٍ التسجيل…" : "تسجيل الدفعة"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}

const plusDays = (days) => {
  const d = new Date();
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
};

/** W-13 opening debt: a legacy debt from the paper book; it does not touch stock. */
export function OpeningDebtDialog({ customers, customer, onClose }) {
  const [customerId, setCustomerId] = useState(customer?.id ?? "");
  const [amount, setAmount] = useState("");
  const [due, setDue] = useState(plusDays(30));
  const [key] = useState(newIdempotencyKey);
  const save = useOpeningDebt();
  const invalid = !AMOUNT.test(amount.trim()) || cents(amount) === 0;

  const submit = (e) => {
    e.preventDefault();
    if (invalid || !customerId) return;
    save.mutate({ customer_id: Number(customerId), amount: amount.trim(), due_date: due || null, key }, { onSuccess: onClose });
  };

  return (
    <Dialog title="دين افتتاحي" onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <p className="field-hint">لدين قديم من الدفتر الورقي قبل استخدام حِسبة. لا يغيّر المخزون.</p>
        {customer ? (
          <p>
            الزبون: <b>{customer.name}</b>
          </p>
        ) : (
          <Field id="od-customer" label="الزبون" required error={save.error?.fieldError?.("customer_id")}>
            <select id="od-customer" className="fld" value={customerId} onChange={(e) => setCustomerId(e.target.value)}>
              <option value="">اختر الزبون</option>
              {(customers ?? []).map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name} — {c.phone}
                </option>
              ))}
            </select>
          </Field>
        )}
        <Field id="od-amount" label="المبلغ" required error={amount && invalid ? "أدخل مبلغاً صحيحاً." : save.error?.fieldError?.("amount")}>
          <input id="od-amount" className="fld ltr m" inputMode="decimal" value={amount} onChange={(e) => setAmount(latinDigits(e.target.value))} />
        </Field>
        <Field id="od-due" label="تاريخ الاستحقاق" optional error={save.error?.fieldError?.("due_date")}>
          <div className="chips">
            <button type="button" className="chip" aria-pressed={due === plusDays(7)} onClick={() => setDue(plusDays(7))}>
              بعد أسبوع
            </button>
            <button type="button" className="chip" aria-pressed={due === plusDays(30)} onClick={() => setDue(plusDays(30))}>
              بعد 30 يوماً
            </button>
            <input id="od-due" type="date" className="fld date-fld" value={due} onChange={(e) => setDue(e.target.value)} />
          </div>
        </Field>
        <ErrorBanner error={save.error && !Object.keys(save.error.errors ?? {}).length ? save.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={save.isPending || invalid || !customerId}>
            {save.isPending ? "جارٍ الحفظ…" : "حفظ الدين"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/** W-06 create / edit customer. A duplicate phone comes back as a field error. */
export function CustomerFormDialog({ customer, canSetLimit, onClose, onSaved }) {
  const [name, setName] = useState(customer?.name ?? "");
  const [phone, setPhone] = useState(customer?.phone ?? "");
  const [limit, setLimit] = useState(customer?.credit_limit ?? "");
  const save = useSaveCustomer();
  const err = (field) => save.error?.fieldError?.(field);

  const submit = (e) => {
    e.preventDefault();
    const body = { name: name.trim(), phone: phone.replace(/\s+/g, "") };
    if (canSetLimit) body.credit_limit = String(limit).trim() === "" ? null : String(limit).trim();
    save.mutate(customer ? { id: customer.id, ...body } : body, { onSuccess: (saved) => (onSaved ?? onClose)(saved) });
  };

  return (
    <Dialog title={customer ? `تعديل ${customer.name}` : "زبون جديد"} onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <Field id="cf-name" label="الاسم" required error={err("name")}>
          <input id="cf-name" className="fld" value={name} onChange={(e) => setName(e.target.value)} autoComplete="off" />
        </Field>
        <Field id="cf-phone" label="رقم الهاتف" required error={err("phone")} hint="10 أرقام، يبدأ بـ 05">
          <input id="cf-phone" className="fld ltr m" inputMode="numeric" value={phone} onChange={(e) => setPhone(latinDigits(e.target.value))} autoComplete="off" />
        </Field>
        {canSetLimit ? (
          <Field id="cf-limit" label="حد الدين" optional error={err("credit_limit")} hint="فارغ = بلا حد">
            <input id="cf-limit" className="fld ltr m" inputMode="decimal" value={limit ?? ""} onChange={(e) => setLimit(latinDigits(e.target.value))} />
          </Field>
        ) : null}
        <ErrorBanner error={save.error && !Object.keys(save.error.errors ?? {}).length ? save.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={save.isPending || !name.trim() || !phone.trim()}>
            {save.isPending ? "جارٍ الحفظ…" : "حفظ الزبون"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/**
 * Cancel a posted record (a return, a supplier invoice or payment, a stock adjustment): the effect
 * first, a required reason, and a red button that names the action. `useAction` is the mutation
 * hook; it gets `{ ...vars, reason, key }` with a key made once when the dialog opened, so a
 * double click or a retry after a timeout never reverses anything twice. The button stays
 * disabled while the request runs; the server's refusal (stock already used, payments in the way)
 * is shown as it came.
 */
export function VoidRecordDialog({ title, rows, total, note, confirmLabel, useAction, vars, onClose, onDone, reasonLabel = "سبب الإلغاء" }) {
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const action = useAction();
  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (!reason.trim() || action.isPending) return;
    action.mutate({ ...vars, reason: reason.trim(), key }, { onSuccess: (r) => (onDone ? onDone(r) : onClose()) });
  };
  const missing = tried && !reason.trim() ? "يجب كتابة سبب الإلغاء." : null;
  return (
    <Dialog title={title} role="alertdialog" tone="danger" onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        {rows?.length ? <ConfirmSummary rows={rows} total={total} /> : null}
        {note ? <p style={{ fontSize: 14 }}>{note}</p> : null}
        <ReasonField id="vr-reason" label={reasonLabel} value={reason} onChange={setReason} error={missing ?? action.error?.fieldError?.("reason")} />
        <ErrorBanner error={action.error && !action.error.fieldError?.("reason") ? action.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-dd" disabled={action.isPending}>
            {action.isPending ? "جارٍ الإلغاء…" : confirmLabel}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            رجوع
          </button>
        </div>
      </form>
    </Dialog>
  );
}

/**
 * Cancels a return made by mistake. The summary says exactly what goes back: the goods to (or off)
 * the shelf, the amount back onto the customer's debt or the supplier's balance, and any cash that
 * was refunded and must now be collected back.
 */
export function CancelReturnDialog({ ret, kind, onClose }) {
  const sale = kind === "sales";
  const goods = (ret.items ?? []).filter((i) => (sale ? !i.damaged : i.from_stock));
  const rows = [
    ["قيمة المرتجع", shekel(ret.total_amount)],
    [sale ? "تخرج من المخزون مرة أخرى" : "تعود إلى المخزون", goods.length ? goods.map((i) => `${i.quantity} × ${i.item_name}`).join("، ") : "لا شيء"],
    ...(sale
      ? isPositiveAmount(ret.debt_reduction)
        ? [[`يعود على دين ${ret.customer?.name ?? "الزبون"}`, `+${shekel(ret.debt_reduction)}`]]
        : []
      : isPositiveAmount(ret.balance_reduction)
        ? [[`يعود لرصيد ${ret.supplier?.name ?? "المورد"}`, `+${shekel(ret.balance_reduction)}`]]
        : []),
    ...(isPositiveAmount(ret.refund_amount) ? [[sale ? "مبلغ رُدّ للزبون نقداً: استرجعه منه" : "مبلغ ردّه المورد: أعده إليه", shekel(ret.refund_amount)]] : []),
  ];
  return (
    <VoidRecordDialog
      title={`إلغاء المرتجع على الفاتورة #${ret.invoice_id ?? ret.purchase_invoice_id}؟`}
      rows={rows}
      note="يبقى المرتجع في السجل بحالة «ملغى» مع السبب. إن كانت البضاعة المرتجعة قد بيعت بعده فلن يُقبل الإلغاء حتى يُصحَّح المخزون."
      confirmLabel="إلغاء المرتجع"
      useAction={sale ? useVoidSaleReturn : useVoidPurchaseReturn}
      vars={{ id: ret.id }}
      onClose={onClose}
    />
  );
}
