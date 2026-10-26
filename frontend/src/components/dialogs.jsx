import { useState } from "react";
import { newIdempotencyKey } from "../services/apiClient";
import { useOpeningDebt, usePayCustomer, useSaveCustomer } from "../services/backoffice";
import { DEFAULT_PAYMENT_METHOD, PAYMENT_METHODS } from "../lib/domain";
import { latinDigits, shekel } from "../lib/format";
import { ConfirmSummary, Dialog, ErrorBanner, Field } from "./ui";

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
