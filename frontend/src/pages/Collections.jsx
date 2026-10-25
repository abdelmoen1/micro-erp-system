import { useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { OpeningDebtDialog, RecordPaymentDialog } from "../components/dialogs";
import { ConfirmSummary, DataTable, Dialog, EmptyState, ErrorBanner, Field, MoneyText, PageHeader, Pager, ReasonField, StatusBadge } from "../components/ui";
import { dateOnly, dateTime, shekel } from "../lib/format";
import { newIdempotencyKey, session } from "../services/apiClient";
import { useBalances, useCustomers, useDebts, usePayments, useReversePayment } from "../services/backoffice";
import { canManage, methodLabel } from "../lib/domain";

const BUCKETS = [
  ["due_today", "مستحق اليوم"],
  ["this_week", "هذا الأسبوع"],
  ["overdue", "متأخر"],
  ["balance", "أعلى رصيد"],
  ["all", "الكل"],
];

const daysLate = (due) => Math.max(0, Math.round((Date.now() - new Date(`${due}T12:00:00`).getTime()) / 86_400_000));

/** SCR-W-13 · debts: due today, this week, overdue, highest balance, all; opening debt (US-0704). */
export function Debts() {
  const manager = canManage(session.user());
  const [bucket, setBucket] = useState("overdue");
  const [pageNo, setPageNo] = useState(1);
  const [dialog, setDialog] = useState(null);
  const byCustomer = bucket === "balance";
  const debts = useDebts({ bucket: byCustomer ? "open" : bucket, page: pageNo, per_page: 20 });
  const balances = useBalances(byCustomer);
  const customers = useCustomers({ status: "active", per_page: 50 });
  const counts = debts.data?.meta?.counts ?? {};
  const today = new Date().toISOString().slice(0, 10);

  const status = (d) => {
    if (d.status === "cancelled") return <StatusBadge status="cancelled" />;
    if (d.status === "paid") return <StatusBadge status="paid" />;
    if (d.due_date && d.due_date < today) return <StatusBadge status="overdue" label={`متأخر ${daysLate(d.due_date)} يوماً`} />;
    if (d.due_date === today) return <StatusBadge status="due_today" />;
    return <StatusBadge status={d.status} />;
  };

  const payButton = (customer, remaining) => (
    <button type="button" className="btn btn-t" onClick={() => setDialog({ pay: customer, remaining })}>
      تسجيل دفعة
    </button>
  );

  return (
    <>
      <PageHeader
        title="الديون"
        sub={
          debts.data?.meta ? (
            <>
              المتبقي في هذه القائمة <b className="m" style={{ color: "var(--debt-fg)" }}>{shekel(debts.data.meta.total_remaining)}</b>
            </>
          ) : (
            " "
          )
        }
      >
        {manager ? (
          <button type="button" className="btn btn-s btn-sm" onClick={() => setDialog({ opening: true })}>
            <Icon name="plus" size={16} strokeWidth={2.2} />
            دين افتتاحي
          </button>
        ) : null}
      </PageHeader>

      <section className="card panel">
        <div className="tabs" role="tablist" aria-label="قوائم الديون">
          {BUCKETS.map(([key, label]) => (
            <button
              key={key}
              type="button"
              role="tab"
              className="tab"
              aria-selected={bucket === key}
              onClick={() => {
                setBucket(key);
                setPageNo(1);
              }}
            >
              {label} {counts[key === "balance" ? "open" : key] !== undefined ? <span className="m seg-count">{counts[key === "balance" ? "open" : key]}</span> : null}
            </button>
          ))}
        </div>

        {byCustomer ? (
          <DataTable
            query={balances}
            rows={balances.data ?? []}
            rowKey={(r) => r.customer.id}
            minWidth={620}
            columns={[
              { key: "c", label: "الزبون", render: (r) => <Link className="row-link" to={`/customers/${r.customer.id}`}>{r.customer.name}</Link> },
              { key: "n", label: "ديون مفتوحة", numeric: true, render: (r) => <span className="m">{r.open_count}</span> },
              { key: "o", label: "أقدم استحقاق", numeric: true, render: (r) => <span className="m">{dateOnly(r.oldest_due)}</span> },
              { key: "t", label: "المتبقي", numeric: true, render: (r) => <MoneyText value={r.total_remaining} style={{ fontWeight: 700, color: "var(--debt-fg)" }} /> },
              { key: "a", label: "إجراء", numeric: true, render: (r) => payButton(r.customer, r.total_remaining) },
            ]}
            empty={<EmptyState icon="ok" title="لا ديون مفتوحة" />}
          />
        ) : (
          <DataTable
            query={debts}
            rows={debts.data?.data ?? []}
            minWidth={820}
            columns={[
              { key: "c", label: "الزبون", render: (d) => (d.customer ? <Link className="row-link" to={`/customers/${d.customer.id}`}>{d.customer.name}</Link> : "—") },
              { key: "s", label: "المصدر", render: (d) => (d.source === "opening_debt" ? "دين افتتاحي" : <Link to={`/sales/${d.invoice_id}`}>فاتورة #{d.invoice_id}</Link>) },
              { key: "due", label: "الاستحقاق", render: (d) => <span className="m">{dateOnly(d.due_date)}</span> },
              { key: "st", label: "الحالة", render: status },
              { key: "a", label: "الأصل", numeric: true, render: (d) => <MoneyText value={d.amount} style={{ color: "var(--ink-muted)" }} /> },
              { key: "r", label: "المتبقي", numeric: true, render: (d) => <MoneyText value={d.remaining_amount} style={{ fontWeight: 700, color: "var(--debt-fg)" }} /> },
              { key: "x", label: "إجراء", numeric: true, render: (d) => (d.customer && d.status !== "paid" && d.status !== "cancelled" ? payButton(d.customer, null) : null) },
            ]}
            empty={
              <EmptyState
                icon="ok"
                title={bucket === "due_today" ? "لا ديون مستحقة اليوم" : bucket === "overdue" ? "لا ديون متأخرة" : "لا ديون في هذه القائمة"}
                text="الاستحقاق محسوب بتوقيت المتجر."
              />
            }
          />
        )}
        {!byCustomer ? <Pager meta={debts.data?.meta} onPage={setPageNo} /> : null}
      </section>

      {dialog?.pay ? <PayFromList customer={dialog.pay} remaining={dialog.remaining} onClose={() => setDialog(null)} /> : null}
      {dialog?.opening ? <OpeningDebtDialog customers={customers.data?.data} onClose={() => setDialog(null)} /> : null}
    </>
  );
}

/** Opens the payment dialog once the customer's whole remaining balance is known. */
function PayFromList({ customer, remaining, onClose }) {
  const open = useDebts({ customer_id: customer.id, bucket: "open", per_page: 1 });
  const total = remaining ?? open.data?.meta?.total_remaining;
  if (!total) return null;
  return <RecordPaymentDialog customer={customer} remaining={total} onClose={onClose} />;
}

/** SCR-W-14 · payments: history with filters, record, reverse single or whole group (US-0704). */
export function Payments() {
  const manager = canManage(session.user());
  const [filters, setFilters] = useState({ from: "", to: "" });
  const [pageNo, setPageNo] = useState(1);
  const [reversing, setReversing] = useState(null);
  const setRange = (patch) => {
    setFilters({ ...filters, ...patch });
    setPageNo(1);
  };
  const payments = usePayments({ ...filters, page: pageNo, per_page: 20 });
  const rows = (payments.data?.data ?? []).map((p) => ({ ...p, __class: p.is_reversed ? "voided" : undefined }));

  const appliedTo = (p) => {
    const parts = (p.applied_to ?? []).map((a) => (a.source === "opening_debt" ? "دين افتتاحي" : `#${a.invoice_id}`));
    return p.type === "pay_all" ? (
      <>
        دفعة على {parts.length > 1 ? `${parts.length} ديون` : "الدين"}
        <span className="cell-sub m">{parts.join(" · ")}</span>
      </>
    ) : (
      parts[0] ?? "—"
    );
  };

  return (
    <>
      <PageHeader title="المدفوعات" sub={payments.data?.meta ? `${payments.data.meta.total} عملية` : " "} />
      <div className="card panel">
        <div className="toolbar">
          <Field id="pf-from" label="من">
            <input id="pf-from" type="date" className="fld date-fld" value={filters.from} onChange={(e) => setRange({ from: e.target.value })} />
          </Field>
          <Field id="pf-to" label="إلى">
            <input id="pf-to" type="date" className="fld date-fld" value={filters.to} onChange={(e) => setRange({ to: e.target.value })} />
          </Field>
          <p className="field-hint grow">لتسجيل دفعة افتح ملف الزبون أو قائمة الديون.</p>
        </div>
      </div>
      <DataTable
        query={payments}
        rows={rows}
        rowKey={(p) => p.payment_group_id ?? `s${p.id}`}
        minWidth={860}
        caption="سجل المدفوعات"
        columns={[
          { key: "at", label: "التاريخ", render: (p) => <span className="m">{dateTime(p.paid_at)}</span> },
          { key: "c", label: "الزبون", render: (p) => (p.customer ? <Link className="row-link" to={`/customers/${p.customer.id}`}>{p.customer.name}</Link> : "—") },
          { key: "on", label: "على", render: appliedTo },
          { key: "by", label: "استلمها", render: (p) => `${p.created_by ?? "—"} · ${methodLabel(p.method)}` },
          {
            key: "st",
            label: "الحالة",
            render: (p) => (
              <>
                <StatusBadge status={p.is_reversed ? "reversed" : "active"} />
                {p.is_reversed && p.reversal_reason ? <span className="cell-sub">{p.reversal_reason}</span> : null}
              </>
            ),
          },
          { key: "amt", label: "المبلغ", numeric: true, render: (p) => <MoneyText className="strike" value={p.total_amount} style={{ fontWeight: 700 }} /> },
          {
            key: "x",
            label: "إجراء",
            numeric: true,
            render: (p) =>
              manager && !p.is_reversed ? (
                <button type="button" className="btn btn-t danger" onClick={() => setReversing(p)}>
                  {p.type === "pay_all" && (p.applied_to ?? []).length > 1 ? "عكس العملية كاملة" : "عكس"}
                </button>
              ) : null,
          },
        ]}
        empty={<EmptyState icon="payments" title="لا مدفوعات في هذه الفترة" />}
      />
      <Pager meta={payments.data?.meta} onPage={setPageNo} />
      {reversing ? <ReverseDialog operation={reversing} onClose={() => setReversing(null)} /> : null}
    </>
  );
}

function ReverseDialog({ operation, onClose }) {
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const reverse = useReversePayment();
  const group = (operation.applied_to ?? []).length > 1;
  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (!reason.trim()) return;
    reverse.mutate({ operation, reason: reason.trim(), key }, { onSuccess: onClose });
  };
  return (
    <Dialog title={group ? `عكس دفعة ${operation.customer?.name ?? ""} الجماعية؟` : `عكس دفعة ${operation.customer?.name ?? ""}؟`} role="alertdialog" tone="warning" onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        {group ? (
          <div role="note" className="banner tone-info">
            <Icon name="info" size={20} />
            <span>هذه الدفعة سُجّلت مرة واحدة ووُزّعت على {operation.applied_to.length} ديون، فتُعكس كاملة معاً. لا يمكن عكس جزء منها.</span>
          </div>
        ) : null}
        <ConfirmSummary
          rows={(operation.applied_to ?? []).map((a) => [a.source === "opening_debt" ? "دين افتتاحي" : `فاتورة #${a.invoice_id}`, shekel(a.amount)])}
          total={["يعود إلى دين الزبون", shekel(operation.total_amount), "var(--debt-fg)"]}
        />
        <ReasonField id="rv-reason" label="سبب العكس" value={reason} onChange={setReason} error={tried && !reason.trim() ? "اكتب سبب العكس." : reverse.error?.fieldError?.("reason")} />
        <p className="field-hint">يبقى أثر الدفعة في السجل بحالة «معكوسة» مع السبب واسمك.</p>
        <ErrorBanner error={reverse.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-dd" disabled={reverse.isPending}>
            {reverse.isPending ? "جارٍ العكس…" : group ? `عكس العملية كاملة (${operation.applied_to.length} دفعات)` : "عكس الدفعة"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            رجوع
          </button>
        </div>
      </form>
    </Dialog>
  );
}
