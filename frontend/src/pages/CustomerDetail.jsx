import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { CustomerFormDialog, OpeningDebtDialog, RecordPaymentDialog } from "../components/dialogs";
import { Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, MoneyText, StatusBadge } from "../components/ui";
import { dateOnly, dateTime, initialOf, isPositiveAmount, shekel } from "../lib/format";
import { session } from "../services/apiClient";
import { useCustomer, useCustomerStatus, useCustomerSummary, useDebts, usePayments, useSales, useStatement } from "../services/backoffice";
import { canManage, methodLabel } from "../lib/domain";

const TABS = [
  ["statement", "كشف الحساب"],
  ["debts", "الديون"],
  ["payments", "المدفوعات"],
  ["sales", "المبيعات"],
];

/** What a statement line is, in the shop's words. */
function describe(e) {
  switch (e.type) {
    case "opening_debt":
      return ["دين افتتاحي", null];
    case "sale": {
      if (e.voided) return ["فاتورة ملغاة", `لا أثر على الرصيد${e.void_reason ? ` · السبب: ${e.void_reason}` : ""}`];
      const paid = isPositiveAmount(e.paid_at_sale);
      if (!isPositiveAmount(e.debit)) return ["بيع نقدي", "مدفوع بالكامل"];
      return [paid ? "بيع جزئي" : "بيع بالدين", paid ? `الإجمالي ${shekel(e.total_amount)} · دُفع عند البيع ${shekel(e.paid_at_sale)}` : e.due_date ? `استحقاق ${dateOnly(e.due_date)}` : null];
    }
    case "payment":
      return [e.payment_group_id ? "دفعة على عدة ديون" : "دفعة", [methodLabel(e.method), e.by ? `استلمها: ${e.by}` : null].filter(Boolean).join(" · ")];
    case "payment_reversal":
      return ["عكس دفعة", e.reason ? `السبب: ${e.reason}` : null];
    case "return":
      return ["مرتجع", isPositiveAmount(e.refund_amount) ? `القيمة ${shekel(e.total_amount)} · أُعيد نقداً ${shekel(e.refund_amount)}` : `خُصم من الدين${e.reason ? ` · ${e.reason}` : ""}`];
    default:
      return [e.type, null];
  }
}

/** SCR-W-07 · customer detail: summary, chronological statement, debts, payments (US-0303). */
export default function CustomerDetail() {
  const { id } = useParams();
  const user = session.user();
  const manager = canManage(user);
  const [tab, setTab] = useState("statement");
  const [range, setRange] = useState({ from: "", to: "" });
  const [dialog, setDialog] = useState(null);

  const customer = useCustomer(id);
  const summary = useCustomerSummary(id);
  const status = useCustomerStatus();

  if (customer.isError) return <ErrorState error={customer.error} title="تعذّر فتح ملف الزبون" onRetry={() => customer.refetch()} />;
  const c = customer.data;
  const s = summary.data;
  const inactive = c?.status === "inactive";

  const kpis = [
    ["إجمالي الدين", s?.total_debt, "var(--ink)"],
    ["المدفوع", s?.paid, "var(--success-fg)"],
    ["المرتجع", s?.returned, "var(--ink)"],
    ["المتبقي", s?.remaining, "var(--debt-fg)"],
    ["المتأخر", s?.overdue, isPositiveAmount(s?.overdue) ? "var(--error-fg)" : "var(--ink)"],
  ];

  return (
    <>
      <Crumbs items={[["الزبائن", "/customers"], [c?.name ?? "…"]]} />

      {inactive ? (
        <div role="status" className="banner tone-voided">
          <Icon name="ban" size={20} />
          <span style={{ flex: 1 }}>هذا الزبون موقوف: لا يظهر عند البيع الجديد. كشف حسابه ودفعاته متاحة كالمعتاد.</span>
          {manager ? (
            <button type="button" className="btn btn-s btn-sm" disabled={status.isPending} onClick={() => status.mutate({ id, active: true })}>
              إعادة تفعيل
            </button>
          ) : null}
        </div>
      ) : null}

      <header className="card profile">
        <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
          <span className="avatar-lg" aria-hidden="true">
            {initialOf(c?.name ?? "")}
          </span>
          <div>
            <h1 style={{ fontSize: 24 }}>{c?.name ?? <span className="sk" style={{ width: 160, height: 24 }} />}</h1>
            <span className="cell-sub m" style={{ textAlign: "right" }}>
              {c?.phone}
            </span>
          </div>
        </div>
        <div>
          <span className="field-label" style={{ color: "var(--ink-muted)" }}>
            حد الدين
          </span>
          <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
            <b className="m" style={{ fontSize: 18 }}>
              {c?.credit_limit ? shekel(c.credit_limit) : "بلا حد"}
            </b>
            {manager ? (
              <button type="button" className="btn btn-g btn-sm" onClick={() => setDialog("edit")}>
                تعديل
              </button>
            ) : (
              <span className="field-hint">للعرض فقط</span>
            )}
          </div>
        </div>
        <div className="head-actions" style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
          <button type="button" className="btn btn-p btn-sm" disabled={!isPositiveAmount(s?.remaining)} onClick={() => setDialog("pay")}>
            تسجيل دفعة
          </button>
          {manager ? (
            <>
              <button type="button" className="btn btn-s btn-sm" onClick={() => setDialog("opening")}>
                دين افتتاحي
              </button>
              {!inactive ? (
                <button type="button" className="btn btn-dl btn-sm" onClick={() => setDialog("deactivate")}>
                  إيقاف الزبون
                </button>
              ) : null}
            </>
          ) : null}
        </div>
      </header>

      <div className="kpi-strip" aria-busy={summary.isPending}>
        {kpis.map(([label, value, color]) => (
          <div key={label} className="card mini">
            <span className="label">{label}</span>
            {summary.isPending ? <span className="sk" style={{ height: 24, width: "70%" }} /> : <MoneyText className="value" value={value} style={{ color }} />}
          </div>
        ))}
      </div>

      <section className="card panel">
        <div className="tabs" role="tablist" aria-label="تفاصيل الزبون">
          {TABS.map(([key, label]) => (
            <button key={key} type="button" role="tab" className="tab" aria-selected={tab === key} onClick={() => setTab(key)}>
              {label}
            </button>
          ))}
        </div>
        {tab === "statement" ? <StatementTab id={id} name={c?.name} range={range} setRange={setRange} /> : null}
        {tab === "debts" ? <DebtsTab id={id} /> : null}
        {tab === "payments" ? <PaymentsTab id={id} /> : null}
        {tab === "sales" ? <SalesTab id={id} /> : null}
      </section>

      {dialog === "pay" && c ? <RecordPaymentDialog customer={c} remaining={s?.remaining ?? "0.00"} onClose={() => setDialog(null)} /> : null}
      {dialog === "opening" && c ? <OpeningDebtDialog customer={c} onClose={() => setDialog(null)} /> : null}
      {dialog === "edit" && c ? <CustomerFormDialog customer={c} canSetLimit={manager} onClose={() => setDialog(null)} /> : null}
      {dialog === "deactivate" && c ? (
        <Dialog title={`إيقاف ${c.name}؟`} role="alertdialog" onClose={() => setDialog(null)}>
          <p>الإيقاف يخفيه من البيع الجديد فقط:</p>
          <ul style={{ margin: 0, paddingRight: 20, lineHeight: 1.9 }}>
            <li>
              دينه المتبقي <b className="m">{shekel(s?.remaining)}</b> يبقى مستحقاً ويمكن استلام دفعاته.
            </li>
            <li>كشف حسابه يبقى كما هو.</li>
            <li>يمكن إعادة تفعيله في أي وقت. العمليتان تُسجَّلان في سجل التدقيق.</li>
          </ul>
          <ErrorBanner error={status.error} />
          <div className="dlg-actions">
            <button type="button" className="btn btn-dd" disabled={status.isPending} onClick={() => status.mutate({ id, active: false }, { onSuccess: () => setDialog(null) })}>
              إيقاف الزبون
            </button>
            <button type="button" className="btn btn-g" onClick={() => setDialog(null)}>
              إلغاء
            </button>
          </div>
        </Dialog>
      ) : null}
    </>
  );
}

function StatementTab({ id, name, range, setRange }) {
  const statement = useStatement(id, range);
  const st = statement.data;
  const rows = (st?.events ?? []).map((e, i) => ({ ...e, __key: i, __class: e.voided ? "voided" : undefined }));
  const columns = [
    { key: "at", label: "التاريخ", render: (e) => <span className="m">{dateTime(e.at)}</span> },
    {
      key: "what",
      label: "الحركة",
      render: (e) => {
        const [what, note] = describe(e);
        const ref = e.invoice_id ?? e.invoice_ids?.[0];
        return (
          <>
            <b className="strike" style={{ fontWeight: 600 }}>
              {what}
            </b>{" "}
            {ref ? (
              <Link to={`/sales/${ref}`} className="m">
                #{ref}
              </Link>
            ) : null}
            {note ? <span className="cell-sub">{note}</span> : null}
          </>
        );
      },
    },
    { key: "debit", label: "عليه (+)", numeric: true, render: (e) => (isPositiveAmount(e.debit) ? <MoneyText className="debit" value={e.debit} /> : "") },
    { key: "credit", label: "له (−)", numeric: true, render: (e) => (isPositiveAmount(e.credit) ? <MoneyText className="credit" value={e.credit} /> : "") },
    { key: "balance", label: "الرصيد", numeric: true, render: (e) => <MoneyText value={e.balance} /> },
  ];

  return (
    <>
      <div className="toolbar" style={{ justifyContent: "space-between" }}>
        <span className="field-hint">كل الحركات بترتيب حدوثها، والرصيد بعد كل حركة في العمود الأخير.</span>
        <div className="toolbar">
          <label className="field">
            <span className="field-label">من</span>
            <input type="date" className="fld date-fld" value={range.from} onChange={(e) => setRange({ ...range, from: e.target.value })} />
          </label>
          <label className="field">
            <span className="field-label">إلى</span>
            <input type="date" className="fld date-fld" value={range.to} onChange={(e) => setRange({ ...range, to: e.target.value })} />
          </label>
        </div>
      </div>
      {st && isPositiveAmount(st.opening_balance) ? (
        <p className="field-hint">
          رصيد سابق قبل {dateOnly(range.from)}: <b className="m">{shekel(st.opening_balance)}</b>
        </p>
      ) : null}
      <div className="ledger">
        <DataTable
          query={statement}
          rows={rows}
          columns={columns}
          rowKey={(r) => r.__key}
          caption={`كشف حساب ${name ?? ""}`}
          empty={<EmptyState icon="info" title="لا حركات في هذه الفترة" text="البيع بالدين والدفعات والمرتجعات تظهر هنا بترتيب حدوثها." />}
        />
      </div>
      {st ? (
        <p style={{ textAlign: "left", fontWeight: 700 }}>
          الرصيد في نهاية الفترة <MoneyText value={st.closing_balance} style={{ color: "var(--debt-fg)", fontSize: 18 }} />
        </p>
      ) : null}
    </>
  );
}

function DebtsTab({ id }) {
  const debts = useDebts({ customer_id: id, bucket: "all", sort: "due", per_page: 50 });
  const rows = debts.data?.data ?? [];
  const today = new Date().toISOString().slice(0, 10);
  return (
    <DataTable
      query={debts}
      rows={rows}
      minWidth={620}
      columns={[
        { key: "src", label: "المصدر", render: (d) => (d.source === "opening_debt" ? "دين افتتاحي" : <Link to={`/sales/${d.invoice_id}`}>فاتورة #{d.invoice_id}</Link>) },
        { key: "due", label: "الاستحقاق", render: (d) => <span className="m">{dateOnly(d.due_date)}</span> },
        { key: "status", label: "الحالة", render: (d) => <StatusBadge status={isPositiveAmount(d.remaining_amount) && d.due_date && d.due_date < today ? "overdue" : d.status} /> },
        { key: "amount", label: "الأصل", numeric: true, render: (d) => <MoneyText value={d.amount} /> },
        { key: "rem", label: "المتبقي", numeric: true, render: (d) => <MoneyText value={d.remaining_amount} style={{ fontWeight: 700, color: "var(--debt-fg)" }} /> },
      ]}
      empty={<EmptyState icon="ok" title="لا ديون على هذا الزبون" />}
    />
  );
}

function PaymentsTab({ id }) {
  const payments = usePayments({ customer_id: id, per_page: 50 });
  const rows = payments.data?.data ?? [];
  return (
    <DataTable
      query={payments}
      rows={rows.map((p) => ({ ...p, __class: p.is_reversed ? "voided" : undefined }))}
      rowKey={(p) => p.payment_group_id ?? p.id}
      minWidth={560}
      columns={[
        { key: "at", label: "التاريخ", render: (p) => <span className="m">{dateTime(p.paid_at)}</span> },
        { key: "by", label: "استلمها", render: (p) => `${p.created_by ?? "—"} · ${methodLabel(p.method)}` },
        { key: "st", label: "الحالة", render: (p) => <StatusBadge status={p.is_reversed ? "reversed" : "active"} /> },
        { key: "amt", label: "المبلغ", numeric: true, render: (p) => <MoneyText className="strike" value={p.total_amount} style={{ fontWeight: 700 }} /> },
      ]}
      empty={<EmptyState icon="payments" title="لا دفعات بعد" />}
    />
  );
}

function SalesTab({ id }) {
  const sales = useSales({ customer_id: id, per_page: 50 });
  const rows = sales.data?.data ?? [];
  return (
    <DataTable
      query={sales}
      rows={rows.map((s) => ({ ...s, __class: s.status === "voided" ? "voided" : undefined }))}
      minWidth={560}
      columns={[
        { key: "no", label: "الفاتورة", render: (s) => <Link to={`/sales/${s.id}`} className="m">#{s.id}</Link> },
        { key: "at", label: "التاريخ", render: (s) => <span className="m">{dateTime(s.created_at)}</span> },
        { key: "st", label: "الحالة", render: (s) => <StatusBadge status={s.status === "voided" ? "voided" : s.source === "opening_debt" ? "unpaid" : s.has_debt ? (isPositiveAmount(s.paid_amount) ? "partial" : "credit") : "cash"} label={s.source === "opening_debt" ? "دين افتتاحي" : undefined} /> },
        { key: "total", label: "الإجمالي", numeric: true, render: (s) => <MoneyText className="strike" value={s.total_amount} style={{ fontWeight: 700 }} /> },
      ]}
      empty={<EmptyState icon="sales" title="لا مبيعات لهذا الزبون" />}
    />
  );
}
