import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { usePrint } from "../components/usePrint";
import { ConfirmSummary, Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, Field, MoneyText, PageHeader } from "../components/ui";
import { DEFAULT_PAYMENT_METHOD, PAYMENT_METHODS, methodLabel } from "../lib/domain";
import { centsOf, dateTime, isPositiveAmount, latinDigits, moneyOf, shekel } from "../lib/format";
import { purchaseReturnDoc } from "../lib/printDocs";
import { newIdempotencyKey } from "../services/apiClient";
import { usePaySupplier, useSupplier, useSuppliers } from "../services/backoffice";

/** Every supplier with what the store still owes them. */
export function Suppliers() {
  const [search, setSearch] = useState("");
  const list = useSuppliers({ search });
  const rows = list.data ?? [];

  const columns = [
    { key: "name", label: "المورد", render: (s) => <Link className="row-link" to={`/suppliers/${s.id}`}>{s.name}</Link> },
    { key: "phone", label: "الهاتف", render: (s) => <span className="m">{s.phone ?? "—"}</span> },
    {
      key: "balance",
      label: "المستحق للمورد",
      numeric: true,
      render: (s) => <MoneyText value={s.balance} style={{ fontWeight: 700, color: isPositiveAmount(s.balance) ? "var(--debt-fg)" : "var(--ink-muted)" }} />,
    },
  ];

  return (
    <>
      <PageHeader title="الموردين" sub={list.data ? `${rows.length} مورد` : " "} />
      <div className="card panel">
        <div className="toolbar">
          <Field id="su-search" label="بحث">
            <input id="su-search" className="fld" placeholder="اسم المورد" value={search} onChange={(e) => setSearch(e.target.value)} />
          </Field>
        </div>
      </div>
      <DataTable
        query={list}
        rows={rows}
        columns={columns}
        caption="قائمة الموردين"
        minWidth={520}
        empty={<EmptyState icon="truck" title="ما في موردين لسّا" text="يظهر المورد هنا بعد أول فاتورة مشتريات من تطبيق الجوال." />}
      />
    </>
  );
}

/** One supplier: what is owed in all, the products bought, the payments and the goods sent back. */
export function SupplierDetail() {
  const { id } = useParams();
  const supplier = useSupplier(id);
  const [paying, setPaying] = useState(false);
  const { print, sheet } = usePrint();

  if (supplier.isError) return <ErrorState error={supplier.error} title="تعذّر فتح المورد" onRetry={() => supplier.refetch()} />;
  if (supplier.isPending) return <div className="card sk" style={{ height: 320 }} />;

  const s = supplier.data;

  return (
    <>
      <Crumbs items={[["الموردين", "/suppliers"], [s.name]]} />
      <header className="card profile">
        <div>
          <h1 style={{ fontSize: 24 }}>{s.name}</h1>
          <span className="cell-sub">المستحق للمورد</span>
          <MoneyText value={s.balance} style={{ fontSize: 26, fontWeight: 700, color: isPositiveAmount(s.balance) ? "var(--debt-fg)" : "var(--ink)" }} />
        </div>
        <div className="head-actions" style={{ display: "flex", gap: 8 }}>
          <Link className="btn btn-s btn-sm" to={`/purchases?supplier_id=${s.id}`}>
            <Icon name="sales" size={16} /> فواتير المورد
          </Link>
          <button type="button" className="btn btn-p btn-sm" disabled={!isPositiveAmount(s.balance)} onClick={() => setPaying(true)}>
            سجّل دفعة
          </button>
        </div>
      </header>

      <div className="split">
        <section className="card panel" style={{ flex: "1 1 320px" }}>
          <h2 style={{ fontSize: 17 }}>الأصناف المشتراة</h2>
          <ul className="list">
            {s.products.map((p) => (
              <li key={p.id}>
                <Link className="row-link" to={`/products/${p.id}`}>
                  {p.name}
                </Link>
                <MoneyText value={p.total} style={{ fontWeight: 700 }} />
              </li>
            ))}
          </ul>
        </section>
        <section className="card panel" style={{ flex: "1 1 320px" }}>
          <h2 style={{ fontSize: 17 }}>الدفعات</h2>
          {s.payments.length > 0 ? (
            <ul className="list">
              {s.payments.map((p) => (
                <li key={p.id}>
                  <span>
                    {methodLabel(p.method)}
                    <span className="cell-sub m">{dateTime(p.at)}</span>
                  </span>
                  <MoneyText value={p.amount} style={{ fontWeight: 700, color: "var(--ok)" }} />
                </li>
              ))}
            </ul>
          ) : (
            <p className="field-hint">لا دفعات بعد.</p>
          )}
        </section>
      </div>

      {s.returns.length > 0 ? (
        <section className="card panel">
          <h2 style={{ fontSize: 17 }}>المرتجعات</h2>
          {s.returns.map((r) => (
            <div key={r.id} className="return-row">
              <span>
                <b className="m">{dateTime(r.created_at)}</b> · {r.items.map((i) => `${i.quantity} × ${i.item_name}`).join("، ")}
                <span className="cell-sub">السبب: {r.reason}</span>
              </span>
              <span className="return-side">
                <MoneyText value={r.total_amount} style={{ fontWeight: 700 }} />
                <button type="button" className="text-btn" onClick={() => print(purchaseReturnDoc(r, s.name))}>
                  طباعة
                </button>
              </span>
            </div>
          ))}
        </section>
      ) : null}

      {paying ? <PayDialog supplier={s} onClose={() => setPaying(false)} /> : null}
      {sheet}
    </>
  );
}

function PayDialog({ supplier, onClose }) {
  const [amount, setAmount] = useState("");
  const [method, setMethod] = useState(DEFAULT_PAYMENT_METHOD);
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const pay = usePaySupplier();

  const valid = /^\d{1,8}(\.\d{1,2})?$/.test(amount);
  const owed = centsOf(supplier.balance);
  const paying = valid ? centsOf(amount) : 0;
  const error = !tried ? null : !valid || paying === 0 ? "اكتب المبلغ." : paying > owed ? "الدفعة أكبر من المبلغ المتبقي." : null;

  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (!valid || paying === 0 || paying > owed) return;
    pay.mutate({ id: supplier.id, amount, method, key }, { onSuccess: onClose });
  };

  return (
    <Dialog title={`دفعة للمورد ${supplier.name}`} onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <Field id="sp-amount" label="المبلغ" error={error ?? pay.error?.fieldError?.("amount")}>
          <input id="sp-amount" className="fld ltr m" inputMode="decimal" value={amount} onChange={(e) => setAmount(latinDigits(e.target.value))} />
        </Field>
        <Field id="sp-method" label="طريقة الدفع">
          <select id="sp-method" className="fld" value={method} onChange={(e) => setMethod(e.target.value)}>
            {PAYMENT_METHODS.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </Field>
        <ConfirmSummary rows={[["المستحق الآن", shekel(supplier.balance)]]} total={["يبقى للمورد", shekel(moneyOf(Math.max(0, owed - paying)))]} />
        <ErrorBanner error={pay.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={pay.isPending}>
            {pay.isPending ? "جارٍ الحفظ…" : "سجّل الدفعة"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}
