import { useState } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import Icon from "../components/Icon";
import { usePrint } from "../components/usePrint";
import { CancelReturnDialog, VoidRecordDialog } from "../components/dialogs";
import { ConfirmSummary, Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, Field, MoneyText, PageHeader, Pager, ReasonField, StatusBadge } from "../components/ui";
import { centsOf, dateTime, isPositiveAmount, latinDigits, milliOf, moneyOf, shekel } from "../lib/format";
import { purchaseDoc, purchaseReturnDoc } from "../lib/printDocs";
import { newIdempotencyKey } from "../services/apiClient";
import { usePurchase, usePurchases, useReturnPurchase, useSupplier, useVoidPurchase } from "../services/backoffice";

/** The purchases register: every supplier invoice, by date, or one supplier's from their page. */
export function Purchases() {
  const [params] = useSearchParams();
  const supplierId = params.get("supplier_id") ?? "";
  const [filters, setFilters] = useState({ from: params.get("from") ?? "", to: params.get("to") ?? "" });
  const [pageNo, setPageNo] = useState(1);
  const set = (patch) => {
    setFilters({ ...filters, ...patch });
    setPageNo(1);
  };
  const list = usePurchases({ ...filters, supplier_id: supplierId, page: pageNo, per_page: 20 });
  const rows = list.data?.data ?? [];

  const columns = [
    { key: "no", label: "الفاتورة", render: (p) => <Link to={`/purchases/${p.id}`} className="m">#{p.id}</Link> },
    { key: "at", label: "التاريخ", render: (p) => <span className="m">{dateTime(p.at)}</span> },
    { key: "sup", label: "المورد", render: (p) => <Link className="row-link" to={`/suppliers/${p.supplier.id}`}>{p.supplier.name}</Link> },
    { key: "by", label: "بواسطة", render: (p) => p.by ?? "—" },
    { key: "lines", label: "الأصناف", numeric: true, render: (p) => <span className="m">{p.lines_count}</span> },
    { key: "total", label: "الإجمالي", numeric: true, render: (p) => <MoneyText value={p.total} style={{ fontWeight: 700 }} /> },
    { key: "ret", label: "المرتجع", numeric: true, render: (p) => (p.status === "voided" ? <StatusBadge status="voided" label="ملغاة" /> : isPositiveAmount(p.returned_amount) ? <MoneyText value={p.returned_amount} style={{ color: "var(--warning-fg)", fontWeight: 600 }} /> : "—") },
  ];

  return (
    <>
      <PageHeader title="المشتريات" sub={list.data?.meta ? `${list.data.meta.total} فاتورة في هذه التصفية` : " "} />
      <div className="card panel">
        <div className="toolbar">
          <Field id="pu-from" label="من">
            <input id="pu-from" type="date" className="fld date-fld" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
          </Field>
          <Field id="pu-to" label="إلى">
            <input id="pu-to" type="date" className="fld date-fld" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
          </Field>
          <p className="field-hint grow">فواتير المشتريات تُسجَّل من تطبيق الجوال عند استلام البضاعة.</p>
        </div>
      </div>
      <DataTable
        query={list}
        rows={rows.map((p) => ({ ...p, __class: p.status === "voided" ? "voided" : undefined }))}
        columns={columns}
        caption="قائمة المشتريات"
        minWidth={760}
        empty={<EmptyState icon="truck" title="لا مشتريات تطابق هذه التصفية" text="وسّع نطاق التاريخ، أو سجّل بضاعة من تطبيق الجوال." />}
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
    </>
  );
}

/** A purchase invoice: its lines, what went back, print, and a return to the supplier. */
export function PurchaseDetail() {
  const { id } = useParams();
  const purchase = usePurchase(id);
  const [returning, setReturning] = useState(false);
  const [voiding, setVoiding] = useState(false);
  const [cancellingReturn, setCancellingReturn] = useState(null);
  const { print, sheet } = usePrint();

  if (purchase.isError) return <ErrorState error={purchase.error} title="تعذّر فتح الفاتورة" onRetry={() => purchase.refetch()} />;
  if (purchase.isPending) return <div className="card sk" style={{ height: 320 }} />;

  const p = purchase.data;
  const remainingItems = p.items.filter((i) => milliOf(i.remaining_quantity ?? (milliOf(i.quantity) - milliOf(i.returned_quantity))) > 0);
  const remainingAmount = remainingItems.reduce((sum, i) => sum + centsOf(i.remaining_line_value ?? i.line_total), 0);
  const voided = p.status === "voided";
  const returnable = remainingItems.length > 0 && !voided;
  const liveReturns = p.returns.filter((r) => r.status !== "voided").length;

  return (
    <>
      <Crumbs items={[["المشتريات", "/purchases"], [`#${p.id}`]]} />
      {voided ? (
        <div role="status" className="banner tone-voided">
          <Icon name="ban" size={20} />
          <span>
            أُلغيت هذه الفاتورة في <span className="m">{dateTime(p.voided_at)}</span>
            {p.voided_by_name ? ` بواسطة ${p.voided_by_name}` : ""}. خرجت بضاعتها من المخزون وأُلغيت دفعاتها، ولم تعد في رصيد المورد.
            {p.void_reason ? <span className="sub">السبب: {p.void_reason}</span> : null}
          </span>
        </div>
      ) : null}
      <header className="card profile">
        <div>
          <h1 className="m" style={{ fontSize: 26 }}>
            #{p.id}
          </h1>
          <span className="cell-sub">
            <span className="m">{dateTime(p.at)}</span> · المورد <Link to={`/suppliers/${p.supplier.id}`}>{p.supplier.name}</Link>
            {p.by ? ` · ${p.by}` : ""}
          </span>
        </div>
        <div className="head-actions" style={{ display: "flex", gap: 8 }}>
          <button type="button" className="btn btn-s btn-sm" onClick={() => print(purchaseDoc(p))}>
            <Icon name="print" size={16} /> طباعة
          </button>
          <button type="button" className="btn btn-p btn-sm" disabled={!returnable} onClick={() => setReturning(true)}>
            إرجاع للمورد
          </button>
          {!voided ? (
            <button
              type="button"
              className="btn btn-dl btn-sm"
              disabled={liveReturns > 0}
              aria-describedby={liveReturns > 0 ? "pv-why" : undefined}
              onClick={() => setVoiding(true)}
            >
              إلغاء الفاتورة
            </button>
          ) : null}
        </div>
      </header>
      {!voided && liveReturns > 0 ? (
        <p id="pv-why" className="field-hint">
          على هذه الفاتورة مرتجعات قائمة. ألغِ المرتجعات أولاً ثم ألغِ الفاتورة.
        </p>
      ) : null}

      <section className="card panel">
        <h2 style={{ fontSize: 17 }}>الأصناف المتبقية</h2>
        <div className="table-wrap">
          <table style={{ minWidth: 560 }}>
            <thead>
              <tr>
                <th scope="col">الصنف</th>
                <th scope="col" className="n">الكمية</th>
                <th scope="col" className="n">المرتجع</th>
                <th scope="col" className="n">سعر الشراء</th>
                <th scope="col" className="n">المجموع</th>
              </tr>
            </thead>
            <tbody>
              {remainingItems.length > 0 ? remainingItems.map((i) => {
                const remainingCartons = i.remaining_cartons ?? i.cartons;
                const remainingLoose = i.remaining_loose_pieces ?? i.loose_pieces;
                return (
                <tr key={i.id}>
                  <td style={{ fontWeight: 600 }}>{i.item_name}</td>
                  <td className="n m">
                    {i.remaining_quantity ?? i.quantity}
                    {i.unit === "kg" ? " كغ" : " قطعة"}
                    {remainingCartons || remainingLoose ? (
                      <span className="cell-sub">
                        {remainingCartons} كرتونة{remainingLoose ? ` + ${remainingLoose} قطعة` : ""}
                      </span>
                    ) : null}
                  </td>
                  <td className="n m" style={{ color: "var(--warning-fg)", fontWeight: 600 }}>
                    {i.returned_quantity && milliOf(i.returned_quantity) > 0 ? i.returned_quantity : "—"}
                  </td>
                  <td className="n">
                    <MoneyText value={i.buy_price} style={{ color: "var(--ink-muted)" }} />
                  </td>
                  <td className="n">
                    <MoneyText value={i.remaining_line_value ?? i.line_total} style={{ fontWeight: 700 }} />
                  </td>
                </tr>
                );
              }) : (
                <tr>
                  <td colSpan={5} className="empty">تم إرجاع جميع الأصناف من هذه الفاتورة.</td>
                </tr>
              )}
            </tbody>
            <tfoot>
              <tr>
                <td colSpan={4} style={{ fontWeight: 700 }}>
                  {remainingItems.length > 0 ? "المبلغ المتبقي" : ""}
                </td>
                <td className="n">
                  {remainingItems.length > 0 ? <MoneyText value={moneyOf(remainingAmount)} style={{ fontWeight: 700, fontSize: 16 }} /> : null}
                </td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <section className="card panel">
        <h2 style={{ fontSize: 17 }}>المرتجعات</h2>
        {p.returns.length > 0 ? (
          p.returns.map((r) => (
            <div key={r.id} className={`return-row${r.status === "voided" ? " voided" : ""}`}>
              <span>
                <b className="m">{dateTime(r.created_at)}</b> · {r.items.map((i) => `${i.quantity} × ${i.item_name}`).join("، ")}
                <span className="cell-sub">
                  {r.created_by ?? ""} · السبب: {r.reason}
                </span>
                {r.status === "voided" ? (
                  <span className="cell-sub">
                    <StatusBadge status="voided" label="ملغى" /> {dateTime(r.voided_at)}
                    {r.voided_by_name ? ` · ${r.voided_by_name}` : ""} — {r.void_reason}
                  </span>
                ) : null}
              </span>
              <span className="return-side">
                <MoneyText value={r.total_amount} style={{ fontWeight: 700 }} />
                <button type="button" className="text-btn" onClick={() => print(purchaseReturnDoc(r, p.supplier.name))}>
                  طباعة
                </button>
                {r.status !== "voided" ? (
                  <button type="button" className="text-btn danger" onClick={() => setCancellingReturn(r)}>
                    إلغاء المرتجع
                  </button>
                ) : null}
              </span>
            </div>
          ))
        ) : (
          <p className="field-hint">لا مرتجعات على هذه الفاتورة.</p>
        )}
      </section>

      {returning ? <ReturnDialog purchase={p} onClose={() => setReturning(false)} /> : null}
      {cancellingReturn ? <CancelReturnDialog ret={{ ...cancellingReturn, supplier: p.supplier }} kind="purchases" onClose={() => setCancellingReturn(null)} /> : null}
      {voiding ? (
        <VoidRecordDialog
          title={`إلغاء فاتورة المورد #${p.id} نهائياً؟`}
          rows={[
            ["الإجمالي", shekel(p.total)],
            ["تخرج من المخزون", `${p.items.length} أصناف كما استُلمت`],
            ...(isPositiveAmount(p.paid_amount) ? [["دفعات مع الفاتورة تُلغى", shekel(p.paid_amount)]] : []),
          ]}
          total={[`ينقص رصيد ${p.supplier.name}`, `−${shekel(moneyOf(centsOf(p.total) - centsOf(p.paid_amount ?? "0")))}`]}
          note="تبقى الفاتورة في السجل بحالة «ملغاة». إن بيع شيء من بضاعتها أو دُفع للمورد بعدها أكثر مما يبقى عليه، فلن يُقبل الإلغاء ويظهر السبب."
          confirmLabel="إلغاء الفاتورة نهائياً"
          useAction={useVoidPurchase}
          vars={{ id: p.id }}
          onClose={() => setVoiding(false)}
        />
      ) : null}
      {sheet}
    </>
  );
}

/** Quantities in pieces or kg, capped at what can still go back; the server's split is final. */
function ReturnDialog({ purchase, onClose }) {
  const remainingQuantity = (item) =>
    item.remaining_quantity == null ? milliOf(item.quantity) - milliOf(item.returned_quantity) : milliOf(item.remaining_quantity);
  const lines = purchase.items.filter((i) => remainingQuantity(i) > 0);
  const [qty, setQty] = useState({});
  const [offShelf, setOffShelf] = useState({});
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const supplier = useSupplier(purchase.supplier.id);
  const submitReturn = useReturnPurchase();

  const checked = lines.map((i) => {
    const text = String(qty[i.id] ?? "").trim();
    const max = remainingQuantity(i);
    const pattern = i.unit === "kg" ? /^\d{1,7}(\.\d{1,3})?$/ : /^\d{1,7}$/;
    const valid = text === "" || pattern.test(text);
    const m = valid && text ? milliOf(text) : 0;
    const value = Math.floor((centsOf(i.line_total) * m * 2 + milliOf(i.quantity)) / (milliOf(i.quantity) * 2));
    return { item: i, text, max, valid, over: m > max, m, value };
  });
  const chosen = checked.filter((c) => c.m > 0);
  const bad = checked.some((c) => !c.valid || c.over);
  const value = chosen.reduce((sum, c) => sum + c.value, 0);
  const owed = Math.max(0, centsOf(supplier.data?.balance));
  const toBalance = Math.min(value, owed);
  const refund = value - toBalance;

  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (bad || chosen.length === 0 || !reason.trim()) return;
    submitReturn.mutate(
      {
        id: purchase.id,
        key,
        reason: reason.trim(),
        items: chosen.map((c) => ({ purchase_item_id: c.item.id, quantity: c.text, ...(offShelf[c.item.id] ? { from_stock: false } : {}) })),
      },
      { onSuccess: onClose },
    );
  };

  return (
    <Dialog title={`إرجاع من الفاتورة #${purchase.id}`} onClose={onClose} wide>
      <form className="form-stack" onSubmit={submit} noValidate>
        <p className="field-hint">اكتب الكمية بالقطعة أو بالكيلو. البضاعة التي رجعت تالفة من زبون ليست في المخزن، فعلّمها حتى لا تُخصم منه.</p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">الصنف</th>
                <th scope="col" className="n">المتاح للإرجاع</th>
                <th scope="col">الكمية المرتجعة</th>
                <th scope="col">خارج المخزن</th>
              </tr>
            </thead>
            <tbody>
              {checked.map((c) => (
                <tr key={c.item.id}>
                  <td style={{ fontWeight: 600 }}>{c.item.item_name}</td>
                  <td className="n m">{c.item.unit === "kg" ? (c.max / 1000).toFixed(3) : c.max / 1000}</td>
                  <td>
                    <input
                      className={`fld ltr m${!c.valid || c.over ? " err" : ""}`}
                      style={{ width: 124, minHeight: 40 }}
                      inputMode="decimal"
                      aria-label={`الكمية المرتجعة من ${c.item.item_name}`}
                      value={c.text}
                      onChange={(e) => setQty({ ...qty, [c.item.id]: latinDigits(e.target.value) })}
                    />
                    {c.over ? <div className="field-error">الحد الأقصى {c.max / 1000}</div> : null}
                  </td>
                  <td>
                    <input
                      type="checkbox"
                      aria-label={`${c.item.item_name} خارج المخزن`}
                      checked={Boolean(offShelf[c.item.id])}
                      onChange={(e) => setOffShelf({ ...offShelf, [c.item.id]: e.target.checked })}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <ConfirmSummary
          rows={[
            ["قيمة المرتجع", shekel(moneyOf(value))],
            [`يُخصم من حساب المورد (عليك له ${shekel(moneyOf(owed))})`, `−${shekel(moneyOf(toBalance))}`],
          ]}
          total={["يردّه المورد نقداً", shekel(moneyOf(refund)), refund > 0 ? "var(--debt-fg)" : "var(--ink)"]}
        />
        <ReasonField id="pr-reason" label="سبب الإرجاع" value={reason} onChange={setReason} error={tried && !reason.trim() ? "اكتب سبب الإرجاع: تالفة، خلاف، صنف غلط." : submitReturn.error?.fieldError?.("reason")} />
        {tried && chosen.length === 0 ? <p className="field-error">اكتب كمية لصنف واحد على الأقل.</p> : null}
        <ErrorBanner error={submitReturn.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={submitReturn.isPending || bad || supplier.isPending}>
            {submitReturn.isPending ? "جارٍ التسجيل…" : "سجّل المرتجع"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}
