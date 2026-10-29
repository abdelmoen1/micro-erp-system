import { useState } from "react";
import { Link } from "react-router-dom";
import { ConfirmSummary, DataTable, Dialog, EmptyState, ErrorBanner, PageHeader, Pager, ReasonField, Segments, StatusBadge } from "../components/ui";
import { canManage, methodLabel } from "../lib/domain";
import { dateTime, shekel } from "../lib/format";
import { newIdempotencyKey, session } from "../services/apiClient";
import { useResolveSyncConflict, useSyncConflicts } from "../services/backoffice";

// SCR-W-18 · offline sync review (US-1106, D-03, doc 16 §6). What the phones sent while offline and
// the server could not take as it was: a sale recorded with a warning, a payment held because it no
// longer fits the balance, or an item that could not be recorded. Nothing here was deleted (BR-10).

const KIND = {
  flagged: ["سُجّل مع تنبيه", "low"],
  conflict: ["دفعة موقوفة", "error"],
  rejected: ["لم يُسجَّل", "error"],
};

const REASON = {
  NEGATIVE_STOCK: "بيع أكثر من المخزون المسجّل.",
  CREDIT_LIMIT_EXCEEDED: "تجاوز سقف دين الزبون، ولم يُؤكَّد التجاوز على الهاتف.",
  PRICE_CHANGED: "تغيّر السعر بعد آخر تحديث للهاتف؛ سُجّل بالسعر الذي دفعه الزبون.",
  PRODUCT_INACTIVE: "الصنف أُوقف بعد آخر تحديث للهاتف.",
  CUSTOMER_INACTIVE: "الزبون أُوقف بعد آخر تحديث للهاتف.",
  PAYMENT_EXCEEDS_REMAINING: "الدفعة أكبر مما على الزبون الآن، فلم تُسجَّل.",
  NOTHING_TO_PAY: "لا شيء على الزبون الآن، فلم تُسجَّل الدفعة.",
  OCCURRED_AT_OUT_OF_RANGE: "وقت العملية خارج المدة المسموحة. قد تكون ساعة الهاتف خاطئة.",
};

const RESOLUTION = {
  acknowledged: "تم الاطلاع",
  applied: "سُجّلت على ديون الزبون",
  refunded: "أُعيد المبلغ للزبون",
  voided: "أُلغيت",
};

/** Every reason of a flagged sale (several flags may apply), or the held item's own reason. */
function reasonsOf(item) {
  const codes = item.flags?.length ? item.flags : [item.reason];
  return codes.map((code) => REASON[code] ?? item.message ?? code);
}

function whatOf(item) {
  if (item.type === "payment") return `دفعة${item.payment_method ? ` · ${methodLabel(item.payment_method)}` : ""}`;
  return item.items_count ? `بيع · ${item.items_count} أصناف` : "بيع";
}

export default function SyncReview() {
  const user = session.user();
  const manager = canManage(user);
  const [status, setStatus] = useState("open");
  const [pageNo, setPageNo] = useState(1);
  const [open, setOpen] = useState(null);
  const query = useSyncConflicts({ status, page: pageNo }, manager);
  const rows = query.data?.data ?? [];
  const resolve = useResolveSyncConflict();
  const [ackKeys] = useState(() => new Map());

  if (!manager) {
    return (
      <>
        <PageHeader title="مراجعة المزامنة" />
        <EmptyState icon="lock" title="هذه الصفحة للمالك أو المدير" text="اطلب منهما مراجعة العمليات التي أرسلتها الهواتف دون اتصال." />
      </>
    );
  }

  const acknowledge = (item) => {
    // One key per item, kept if the first click times out, so a second click is the same request.
    if (!ackKeys.has(item.id)) ackKeys.set(item.id, newIdempotencyKey());
    resolve.mutate({ id: item.id, resolution: "acknowledged", key: ackKeys.get(item.id) });
  };

  const columns = [
    {
      key: "what",
      label: "العملية",
      render: (item) => (
        <div className="cell-stack">
          <b>{whatOf(item)}</b>
          <StatusBadge status={KIND[item.kind]?.[1] ?? "pending"} label={KIND[item.kind]?.[0] ?? item.kind} />
        </div>
      ),
    },
    {
      key: "customer",
      label: "الزبون",
      render: (item) =>
        item.customer ? (
          <Link to={`/customers/${item.customer.id}`}>{item.customer.name}</Link>
        ) : (
          <span className="cell-sub">زبون نقدي</span>
        ),
    },
    {
      key: "when",
      label: "متى ومن",
      render: (item) => (
        <div className="cell-stack">
          <span className="m">{dateTime(item.occurred_at)}</span>
          <span className="cell-sub">{item.user?.name ?? "—"}</span>
        </div>
      ),
    },
    { key: "amount", label: "المبلغ", numeric: true, render: (item) => <span className="m">{item.amount ? shekel(item.amount) : "—"}</span> },
    {
      key: "reason",
      label: "لماذا هو هنا",
      render: (item) => (
        <ul className="reason-list">
          {reasonsOf(item).map((text) => (
            <li key={text}>{text}</li>
          ))}
        </ul>
      ),
    },
    {
      key: "action",
      label: "المعالجة",
      render: (item) =>
        item.status === "resolved" ? (
          <div className="cell-stack">
            <StatusBadge status="ok" label={RESOLUTION[item.resolution] ?? item.resolution} />
            <span className="cell-sub">
              {item.resolver?.name ?? ""} {item.resolved_at ? `· ${dateTime(item.resolved_at)}` : ""}
            </span>
            {item.resolution_note ? <span className="cell-sub">{item.resolution_note}</span> : null}
          </div>
        ) : item.kind === "flagged" ? (
          <div className="row-actions">
            {item.invoice_id ? (
              <Link className="btn btn-g btn-sm" to={`/sales/${item.invoice_id}`}>
                فتح الفاتورة #{item.invoice_id}
              </Link>
            ) : null}
            <button type="button" className="btn btn-p btn-sm" disabled={resolve.isPending} onClick={() => acknowledge(item)}>
              تم الاطلاع
            </button>
          </div>
        ) : (
          <button type="button" className="btn btn-p btn-sm" onClick={() => setOpen(item)}>
            {item.kind === "conflict" ? "معالجة الدفعة" : "إلغاء مع سبب"}
          </button>
        ),
    },
  ];

  const openCount = query.data?.open_count;

  return (
    <>
      <PageHeader
        title="مراجعة المزامنة"
        sub="عمليات أرسلتها الهواتف بعد انقطاع الإنترنت ولم يقبلها الخادم كما هي. لم يُحذف شيء منها، وكل معالجة تُسجَّل في سجل التدقيق."
      />
      <Segments
        label="الحالة"
        value={status}
        onChange={(value) => {
          setStatus(value);
          setPageNo(1);
        }}
        options={[
          ["open", "بانتظار المعالجة", openCount],
          ["resolved", "تمت معالجتها"],
          ["all", "الكل"],
        ]}
      />
      <ErrorBanner error={resolve.error && !open ? resolve.error : null} />
      <DataTable
        query={query}
        rows={rows}
        columns={columns}
        caption="عمليات المزامنة للمراجعة"
        minWidth={960}
        empty={
          <EmptyState
            icon="ok"
            title={status === "open" ? "لا شيء بانتظار المعالجة" : "لا عمليات هنا"}
            text="عندما يرسل هاتف عملية لا تطابق ما على الخادم، تظهر هنا لتقرر ما يحدث لها."
          />
        }
      />
      <Pager meta={query.data?.meta} onPage={setPageNo} />
      {open ? <ResolveDialog item={open} onClose={() => setOpen(null)} /> : null}
    </>
  );
}

/** A held payment: apply it, record it as refunded, or void it; a rejected item: void it. */
function ResolveDialog({ item, onClose }) {
  const payment = item.kind === "conflict";
  const [choice, setChoice] = useState(payment ? "applied" : "voided");
  const [note, setNote] = useState("");
  const [tried, setTried] = useState(false);
  // A changed choice is a different request, so each choice keeps its own key (05 §4.1).
  const [keys] = useState(() => ({ applied: newIdempotencyKey(), refunded: newIdempotencyKey(), voided: newIdempotencyKey() }));
  const resolve = useResolveSyncConflict();
  const needsReason = choice === "voided";

  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (needsReason && !note.trim()) return;
    resolve.mutate({ id: item.id, resolution: choice, note: note.trim() || null, key: keys[choice] }, { onSuccess: onClose });
  };

  const options = payment
    ? [
        ["applied", "تسجيلها على ديون الزبون", "تُوزَّع على ديونه المفتوحة من الأقدم استحقاقاً، بتاريخ استلامها. تنجح فقط إن كان عليه الآن ما يكفي."],
        ["refunded", "أُعيد المبلغ للزبون", "لا تُسجَّل دفعة؛ يُحفظ أن المبلغ رُدّ له نقداً."],
        ["voided", "إلغاؤها", "لا تُسجَّل دفعة. اكتب السبب، مثلاً: سُجّلت على الزبون الخطأ."],
      ]
    : [["voided", "إلغاء العملية", "لم تُسجَّل على الخادم. إن كانت حقيقية فأدخلها يدوياً، ثم ألغِ هذا البند مع السبب."]];

  return (
    <Dialog title={payment ? `دفعة موقوفة من ${item.customer?.name ?? "زبون"}` : "عملية لم تُسجَّل"} role="alertdialog" tone="warning" onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <ConfirmSummary
          rows={[
            ["المبلغ", item.amount ? shekel(item.amount) : "—"],
            ["طريقة الدفع", item.payment_method ? methodLabel(item.payment_method) : "—"],
            ["وقت العملية على الهاتف", dateTime(item.occurred_at)],
            ["السبب", reasonsOf(item).join(" ")],
          ]}
        />
        <fieldset className="field resolve-options">
          <legend className="field-label">ماذا يحدث لها؟</legend>
          {options.map(([key, label, hint]) => (
            <label key={key} className={`resolve-option${choice === key ? " is-on" : ""}`}>
              <input type="radio" name="resolution" value={key} checked={choice === key} onChange={() => setChoice(key)} />
              <span>
                <b>{label}</b>
                <span className="field-hint">{hint}</span>
              </span>
            </label>
          ))}
        </fieldset>
        <ReasonField
          id="sync-note"
          label={needsReason ? "سبب الإلغاء" : "ملاحظة (اختياري)"}
          value={note}
          onChange={setNote}
          error={tried && needsReason && !note.trim() ? "اكتب سبب الإلغاء. يظهر في سجل التدقيق." : resolve.error?.fieldError?.("note")}
        />
        <ErrorBanner error={resolve.error && !resolve.error.fieldError?.("note") ? resolve.error : null} />
        <div className="dlg-actions">
          <button type="submit" className={needsReason ? "btn btn-dd" : "btn btn-p"} disabled={resolve.isPending}>
            {resolve.isPending ? "جارٍ الحفظ…" : options.find(([key]) => key === choice)?.[1]}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            رجوع
          </button>
        </div>
      </form>
    </Dialog>
  );
}
