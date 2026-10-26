import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { ConfirmSummary, Crumbs, Dialog, ErrorBanner, ErrorState, MoneyText, ReasonField, StatusBadge } from "../components/ui";
import { dateOnly, dateTime, isPositiveAmount, latinDigits, shekel } from "../lib/format";
import { newIdempotencyKey, session } from "../services/apiClient";
import { useReturnSale, useSale, useVoidSale } from "../services/backoffice";
import { canManage, saleType } from "../lib/domain";

const TYPE_LABEL = { cash: "نقدي", partial: "جزئي", credit: "دين" };

const milli = (q) => {
  const [w, f = ""] = String(q ?? "0").replace("-", "").split(".");
  return Number(w || 0) * 1000 + Number(f.padEnd(3, "0").slice(0, 3));
};
const cents = (m) => {
  const [w, f = ""] = String(m ?? "0").split(".");
  return Number(w || 0) * 100 + Number(f.padEnd(2, "0").slice(0, 2));
};
const money = (c) => `${Math.floor(c / 100)}.${String(c % 100).padStart(2, "0")}`;

/** SCR-W-11 · sale detail: lines with returned quantities, payment and debt, returns, void. */
export default function SaleDetail() {
  const { id } = useParams();
  const manager = canManage(session.user());
  const sale = useSale(id);
  const [dialog, setDialog] = useState(null);

  if (sale.isError) return <ErrorState error={sale.error} title="تعذّر فتح الفاتورة" onRetry={() => sale.refetch()} />;
  if (sale.isPending) return <div className="card sk" style={{ height: 320 }} />;

  const s = sale.data;
  const voided = s.status === "voided";
  const opening = s.source === "opening_debt";
  const debt = s.debt;
  const paidLater = debt?.total_payments ?? "0.00";
  const hasReturns = (s.returns ?? []).length > 0;
  const voidBlock = hasReturns
    ? "لا يمكن إلغاء الفاتورة: عليها مرتجع. لتصحيح كمية، استخدم «مرتجع»."
    : isPositiveAmount(paidLater)
      ? "لا يمكن إلغاء الفاتورة: على دينها دفعات قائمة. اعكس الدفعات أولاً."
      : null;
  const returnable = (s.items ?? []).some((i) => i.product_id && milli(i.quantity) > milli(i.returned_quantity));
  const today = new Date().toISOString().slice(0, 10);

  return (
    <>
      <Crumbs items={[["المبيعات", "/sales"], [`#${s.id}`]]} />

      {voided ? (
        <div role="status" className="banner tone-voided">
          <Icon name="ban" size={20} />
          <span>
            أُلغيت هذه الفاتورة في <span className="m">{dateTime(s.voided_at)}</span>
            {s.voided_by_name ? ` بواسطة ${s.voided_by_name}` : ""}. أُعيدت الكميات إلى المخزون وأُلغي الدين.
            {s.void_reason ? <span className="sub">السبب: {s.void_reason}</span> : null}
          </span>
        </div>
      ) : null}

      <header className="card profile">
        <div>
          <div style={{ display: "flex", gap: 10, alignItems: "center", flexWrap: "wrap" }}>
            <h1 className="m" style={{ fontSize: 26 }}>
              #{s.id}
            </h1>
            <StatusBadge status={voided ? "voided" : "active"} />
            {!opening ? <StatusBadge status={saleType(s)} label={TYPE_LABEL[saleType(s)]} /> : <StatusBadge status="unpaid" label="دين افتتاحي" />}
          </div>
          <span className="cell-sub">
            <span className="m">{dateTime(s.created_at)}</span>
            {s.seller ? ` · البائع ${s.seller.name}` : ""} · {s.items?.length ?? 0} أصناف
          </span>
        </div>
        {manager && !voided && !opening ? (
          <div className="head-actions" style={{ display: "flex", gap: 8 }}>
            <button type="button" className="btn btn-s btn-sm" disabled={!returnable} onClick={() => setDialog("return")}>
              مرتجع
            </button>
            <button type="button" className="btn btn-dl btn-sm" disabled={Boolean(voidBlock)} aria-describedby={voidBlock ? "void-why" : undefined} onClick={() => setDialog("void")}>
              إلغاء الفاتورة
            </button>
          </div>
        ) : null}
      </header>
      {manager && !voided && voidBlock ? (
        <p id="void-why" className="field-hint" style={{ display: "flex", gap: 6, alignItems: "center" }}>
          <Icon name="info" size={16} color="var(--info-fg)" />
          {voidBlock}
        </p>
      ) : null}
      {!manager && !voided ? <p className="field-hint">المرتجع والإلغاء للمالك أو المدير.</p> : null}

      <div className="split">
        <section className="card panel" style={{ flex: "2 1 520px" }}>
          <h2 style={{ fontSize: 17 }}>الأصناف</h2>
          <div className="table-wrap">
            <table style={{ minWidth: 520 }}>
              <thead>
                <tr>
                  <th scope="col">الصنف</th>
                  <th scope="col" className="n">
                    الكمية
                  </th>
                  <th scope="col" className="n">
                    المرتجع
                  </th>
                  <th scope="col" className="n">
                    السعر
                  </th>
                  <th scope="col" className="n">
                    المجموع
                  </th>
                </tr>
              </thead>
              <tbody>
                {s.items.map((i) => (
                  <tr key={i.id}>
                    <td style={{ fontWeight: 600 }}>{i.item_name}</td>
                    <td className="n m">
                      {i.quantity}
                      {i.unit === "kg" ? " كغ" : i.pack_size ? " كرتونة" : ""}
                      {i.pack_size ? <span className="cell-sub">{i.base_quantity} قطعة</span> : null}
                    </td>
                    <td className="n m" style={{ color: "var(--warning-fg)", fontWeight: 600 }}>
                      {milli(i.returned_quantity) > 0 ? i.returned_quantity : "—"}
                    </td>
                    <td className="n">
                      <MoneyText value={i.unit_price} style={{ color: "var(--ink-muted)" }} />
                      {i.unit === "kg" || i.pack_size ? (
                        <span className="cell-sub" style={{ display: "inline" }}>
                          {i.pack_size ? ` / كرتونة (${i.pack_size} قطعة)` : " / كغ"}
                        </span>
                      ) : null}
                    </td>
                    <td className="n">
                      <MoneyText value={i.line_total} style={{ fontWeight: 700 }} />
                    </td>
                  </tr>
                ))}
              </tbody>
              <tfoot>
                <tr>
                  <td colSpan={4} style={{ fontWeight: 700 }}>
                    الإجمالي
                  </td>
                  <td className="n">
                    <MoneyText value={s.total_amount} style={{ fontWeight: 700, fontSize: 16 }} />
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        </section>

        <div style={{ flex: "1 1 300px", display: "flex", flexDirection: "column", gap: 16 }}>
          <section className="card panel">
            <h2 style={{ fontSize: 17 }}>الدفع والدين</h2>
            <ConfirmSummary
              rows={[
                ["إجمالي الفاتورة", shekel(s.total_amount)],
                ["دُفع عند البيع", shekel(s.paid_amount)],
                ...(debt && isPositiveAmount(debt.return_credit) ? [["مرتجعات خُصمت من الدين", `−${shekel(debt.return_credit)}`]] : []),
                ...(debt ? [["دفعات لاحقة", shekel(paidLater)]] : []),
              ]}
              total={debt ? [voided ? "الدين بعد الإلغاء" : "المتبقي على الفاتورة", shekel(debt.remaining_amount), voided ? "var(--voided-fg)" : "var(--debt-fg)"] : null}
            />
            {s.customer ? (
              <p style={{ fontSize: 14 }}>
                الزبون: <Link to={`/customers/${s.customer.id}`}>{s.customer.name}</Link>
                {debt?.due_date ? (
                  <>
                    {" "}
                    · الاستحقاق <span className="m">{dateOnly(debt.due_date)}</span>{" "}
                    {isPositiveAmount(debt.remaining_amount) && debt.due_date < today ? <StatusBadge status="overdue" /> : null}
                  </>
                ) : null}
              </p>
            ) : (
              <p className="field-hint">بيع بدون زبون.</p>
            )}
          </section>
          <section className="card panel">
            <h2 style={{ fontSize: 17 }}>المرتجعات</h2>
            {hasReturns ? (
              s.returns.map((r) => (
                <div key={r.id} style={{ display: "flex", justifyContent: "space-between", gap: 10, paddingTop: 8, borderTop: "1px solid var(--border)", fontSize: 14 }}>
                  <span>
                    <b className="m">{dateTime(r.created_at)}</b> · {(r.items ?? []).map((i) => `${i.quantity} × ${i.item_name}`).join("، ")}
                    <span className="cell-sub">
                      {r.created_by ?? ""} · السبب: {r.reason}
                    </span>
                  </span>
                  <span style={{ textAlign: "left" }}>
                    <MoneyText value={r.total_amount} style={{ fontWeight: 700 }} />
                    <span className="cell-sub">
                      {isPositiveAmount(r.debt_reduction) ? `من الدين ${shekel(r.debt_reduction)}` : ""}
                      {isPositiveAmount(r.refund_amount) ? ` · نقداً ${shekel(r.refund_amount)}` : ""}
                    </span>
                  </span>
                </div>
              ))
            ) : (
              <p className="field-hint">لا مرتجعات على هذه الفاتورة.</p>
            )}
          </section>
        </div>
      </div>

      {dialog === "return" ? <ReturnDialog sale={s} onClose={() => setDialog(null)} /> : null}
      {dialog === "void" ? <VoidDialog sale={s} onClose={() => setDialog(null)} /> : null}
    </>
  );
}

/** SCR-W-12 · return: quantities capped at what is returnable, a preview, a mandatory reason. */
function ReturnDialog({ sale, onClose }) {
  const lines = sale.items.filter((i) => i.product_id && milli(i.quantity) > milli(i.returned_quantity));
  const [qty, setQty] = useState(() => Object.fromEntries(lines.map((i) => [i.id, ""])));
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const submitReturn = useReturnSale();

  const checked = lines.map((i) => {
    const text = String(qty[i.id] ?? "").trim();
    const max = milli(i.quantity) - milli(i.returned_quantity);
    const pattern = i.unit === "kg" ? /^\d{1,7}(\.\d{1,3})?$/ : /^\d{1,7}$/;
    const valid = text === "" || pattern.test(text);
    const m = valid && text ? milli(text) : 0;
    // line value = qty × unit price, rounded half-up to cents (the server is authoritative)
    const value = Math.floor((m * cents(i.unit_price) + 500) / 1000);
    return { item: i, text, max, valid, over: m > max, m, value };
  });
  const chosen = checked.filter((c) => c.m > 0);
  const bad = checked.some((c) => !c.valid || c.over);
  const value = chosen.reduce((sum, c) => sum + c.value, 0);
  const open = sale.debt && sale.debt.status !== "cancelled" ? cents(sale.debt.remaining_amount) : 0;
  const toDebt = Math.min(value, open);
  const refund = value - toDebt;

  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (bad || chosen.length === 0 || !reason.trim()) return;
    submitReturn.mutate(
      {
        id: sale.id,
        key,
        reason: reason.trim(),
        items: chosen.map((c) => ({ invoice_item_id: c.item.id, quantity: c.text })),
      },
      { onSuccess: onClose },
    );
  };

  const step = (c, delta) => setQty({ ...qty, [c.item.id]: String(Math.min(c.max / 1000, Math.max(0, Number(c.text || 0) + delta))) });

  return (
    <Dialog title={`مرتجع من الفاتورة #${sale.id}`} onClose={onClose} wide>
      <form className="form-stack" onSubmit={submit} noValidate>
        <p className="field-hint">اختر الكمية المرتجعة لكل صنف. الحد الأقصى هو المبيع ناقص ما أُرجع سابقاً.</p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th scope="col">الصنف</th>
                <th scope="col" className="n">
                  المتاح للإرجاع
                </th>
                <th scope="col">الكمية المرتجعة</th>
              </tr>
            </thead>
            <tbody>
              {checked.map((c) => (
                <tr key={c.item.id}>
                  <td style={{ fontWeight: 600 }}>
                    {c.item.item_name}{" "}
                    {c.item.unit === "kg" ? (
                      <span className="field-hint">(كغ)</span>
                    ) : c.item.pack_size ? (
                      <span className="field-hint">(بالكرتونة، {c.item.pack_size} قطعة)</span>
                    ) : null}
                  </td>
                  <td className="n m">{c.item.unit === "kg" ? (c.max / 1000).toFixed(3) : c.max / 1000}</td>
                  <td>
                    {c.item.unit === "kg" ? (
                      <input
                        className={`fld ltr m${!c.valid || c.over ? " err" : ""}`}
                        style={{ width: 124, minHeight: 40 }}
                        inputMode="decimal"
                        aria-label={`الكمية المرتجعة من ${c.item.item_name} بالكغ`}
                        value={c.text}
                        onChange={(e) => setQty({ ...qty, [c.item.id]: latinDigits(e.target.value) })}
                      />
                    ) : (
                      <div className="qty">
                        <button type="button" aria-label={`إنقاص ${c.item.item_name}`} disabled={c.m <= 0} onClick={() => step(c, -1)}>
                          −
                        </button>
                        <span>{c.text || "0"}</span>
                        <button type="button" aria-label={`زيادة ${c.item.item_name}`} disabled={c.m >= c.max} onClick={() => step(c, 1)}>
                          +
                        </button>
                      </div>
                    )}
                    {c.over ? <div className="field-error">الحد الأقصى {c.item.unit === "kg" ? (c.max / 1000).toFixed(3) : c.max / 1000}</div> : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <ConfirmSummary
          rows={[
            ["قيمة المرتجع", shekel(money(value))],
            [`يُخصم من دين الفاتورة (المتبقي ${shekel(money(open))})`, `−${shekel(money(toDebt))}`],
          ]}
          total={["يُعاد للزبون نقداً", shekel(money(refund)), refund > 0 ? "var(--debt-fg)" : "var(--ink)"]}
        />
        <ReasonField id="rt-reason" label="سبب الإرجاع" value={reason} onChange={setReason} error={tried && !reason.trim() ? "اكتب سبب الإرجاع. يظهر في سجل الفاتورة." : submitReturn.error?.fieldError?.("reason")} />
        {tried && chosen.length === 0 ? <p className="field-error">اختر كمية لصنف واحد على الأقل.</p> : null}
        <p className="field-hint">المخزون يزيد بالكميات المرتجعة. الأرقام هنا تقدير؛ الخادم يحسبها نهائياً عند التأكيد.</p>
        <ErrorBanner error={submitReturn.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={submitReturn.isPending || bad}>
            {submitReturn.isPending ? "جارٍ التسجيل…" : "تأكيد المرتجع"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}

function VoidDialog({ sale, onClose }) {
  const [reason, setReason] = useState("");
  const [tried, setTried] = useState(false);
  const [key] = useState(newIdempotencyKey);
  const voidSale = useVoidSale();
  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (!reason.trim()) return;
    voidSale.mutate({ id: sale.id, reason: reason.trim(), key }, { onSuccess: onClose });
  };
  return (
    <Dialog title={`إلغاء الفاتورة #${sale.id} نهائياً؟`} role="alertdialog" tone="danger" onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <ConfirmSummary
          rows={[
            ["الإجمالي", shekel(sale.total_amount)],
            ["الكميات تعود إلى المخزون", `${sale.items.length} أصناف`],
            ...(sale.debt ? [[`دين ${sale.customer?.name ?? "الزبون"} ينقص`, `−${shekel(sale.debt.remaining_amount)}`]] : []),
          ]}
        />
        <p style={{ fontSize: 14 }}>تبقى الفاتورة في السجل بحالة «ملغاة» ولا يمكن التراجع عن الإلغاء.</p>
        <ReasonField id="vd-reason" label="سبب الإلغاء" value={reason} onChange={setReason} error={tried && !reason.trim() ? "يجب كتابة سبب إلغاء الفاتورة." : voidSale.error?.fieldError?.("reason")} />
        <ErrorBanner error={voidSale.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-dd" disabled={voidSale.isPending}>
            {voidSale.isPending ? "جارٍ الإلغاء…" : "إلغاء الفاتورة نهائياً"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            رجوع
          </button>
        </div>
      </form>
    </Dialog>
  );
}
