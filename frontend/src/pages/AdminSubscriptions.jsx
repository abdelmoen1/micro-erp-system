import { useState } from "react";
import { Dialog, EmptyState, ErrorBanner, ErrorState, Field, PageHeader, Pager, Segments } from "../components/ui";
import { dateTime } from "../lib/format";
import {
  monthsLabel,
  ORDER_STATUS,
  useAdminOrder,
  useAdminOrders,
  useAdminPlans,
  useConfirmPayment,
  useOrderNote,
  useOrderTransition,
  useUpdatePlan,
} from "../services/subscriptions";

const Pill = ({ status }) => {
  const [text, tone] = ORDER_STATUS[status] ?? [status, "pending"];
  return <span className={`pill tone-${tone}`}>{text}</span>;
};

const EVENT = { created: "إنشاء الطلب", status: "تغيير الحالة", note: "ملاحظة", payment: "تسجيل دفعة", activated: "تفعيل الاشتراك", provider_event: "إشعار مزوّد الدفع" };

/**
 * Platform admin: subscription requests and plans. A request is activated ONLY by «تأكيد الدفع»,
 * after the admin has independently checked that the money arrived (amount and currency must match).
 */
export default function AdminSubscriptions() {
  const [tab, setTab] = useState("orders");
  return (
    <>
      <PageHeader title="الاشتراكات" sub="طلبات الاشتراك والدفع اليدوي، والباقات" />
      <Segments label="القسم" value={tab} options={[["orders", "الطلبات"], ["plans", "الباقات"]]} onChange={setTab} />
      <div style={{ marginTop: 16 }}>{tab === "orders" ? <Orders /> : <Plans />}</div>
    </>
  );
}

function Orders() {
  const [filters, setFilters] = useState({ status: "open", page: 1 });
  const [openId, setOpenId] = useState(null);
  const orders = useAdminOrders(filters);

  return (
    <>
      <Segments
        label="الحالة"
        value={filters.status}
        options={[["open", "مفتوحة"], ["paid", "مدفوعة"], ["rejected", "مرفوضة"], ["cancelled", "ملغاة"], ["", "الكل"]]}
        onChange={(status) => setFilters({ status, page: 1 })}
      />
      {orders.isError ? (
        <ErrorState error={orders.error} onRetry={() => orders.refetch()} />
      ) : orders.data?.data?.length === 0 ? (
        <EmptyState title="لا توجد طلبات" text="تظهر هنا طلبات الاشتراك من الموقع (واتساب أو الدفع الإلكتروني)." />
      ) : (
        <div className="card table-card" style={{ marginTop: 12, overflowX: "auto" }}>
          <table className="tbl">
            <caption className="sr-only">طلبات الاشتراك</caption>
            <thead>
              <tr>
                <th>رقم الطلب</th>
                <th>المتجر</th>
                <th>الباقة</th>
                <th>المبلغ</th>
                <th>الطريقة</th>
                <th>الحالة</th>
                <th>التاريخ</th>
              </tr>
            </thead>
            <tbody>
              {(orders.data?.data ?? []).map((o) => (
                <tr key={o.id}>
                  <td>
                    <button type="button" className="btn btn-t" onClick={() => setOpenId(o.id)}>
                      <span className="m">{o.reference}</span>
                    </button>
                  </td>
                  <td>{o.store?.name}</td>
                  <td>{o.plan?.name}</td>
                  <td>
                    <span className="m">{o.amount}</span> {o.currency}
                  </td>
                  <td>{o.channel === "manual_whatsapp" ? "واتساب" : "إلكتروني"}</td>
                  <td>
                    <Pill status={o.status} />
                  </td>
                  <td>{dateTime(o.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <Pager meta={orders.data?.meta} onPage={(page) => setFilters((f) => ({ ...f, page }))} />
      {openId ? <OrderDialog id={openId} onClose={() => setOpenId(null)} /> : null}
    </>
  );
}

function OrderDialog({ id, onClose }) {
  const order = useAdminOrder(id);
  const move = useOrderTransition();
  const note = useOrderNote();
  const confirm = useConfirmPayment();
  const [text, setText] = useState("");
  const [pay, setPay] = useState({ payment_method: "", transaction_reference: "", paid_at: "", note: "", payment_verified: false });
  const o = order.data;

  const confirmPayment = (e) => {
    e.preventDefault();
    confirm.mutate({ id, amount: o.amount, currency: o.currency, ...pay, paid_at: pay.paid_at || undefined });
  };

  return (
    <Dialog title={o ? `طلب ${o.reference}` : "طلب اشتراك"} onClose={onClose} wide>
      {order.isError ? <ErrorBanner error={order.error} /> : null}
      {!o ? (
        <div className="sk" style={{ height: 120 }} />
      ) : (
        <div className="form-stack">
          <p style={{ margin: 0 }}>
            <Pill status={o.status} /> · {o.store?.name} {o.store?.deleted ? "(محذوف)" : ""} {o.store?.phone ? <span className="m ltr-inline">{o.store.phone}</span> : null}
            <br />
            {o.plan?.name} · {monthsLabel(o.duration_months)} · <b className="m">{o.amount}</b> {o.currency} · {o.channel === "manual_whatsapp" ? "طلب عبر واتساب" : `دفع إلكتروني (${o.provider})`}
            {o.period_ends_at ? (
              <>
                <br />
                الفترة: {dateTime(o.period_starts_at)} ← {dateTime(o.period_ends_at)}
              </>
            ) : null}
          </p>
          {o.whatsapp_url ? (
            <a className="btn btn-s btn-sm" href={o.whatsapp_url} target="_blank" rel="noopener noreferrer">
              فتح محادثة الطلب في واتساب
            </a>
          ) : null}

          {o.allowed_transitions.length ? (
            <div className="head-actions">
              {o.allowed_transitions.map((s) => (
                <button key={s} type="button" className={s === "rejected" || s === "cancelled" ? "btn btn-dl btn-sm" : "btn btn-g btn-sm"} disabled={move.isPending} onClick={() => move.mutate({ id, status: s, note: text || undefined })}>
                  نقل إلى: {ORDER_STATUS[s]?.[0]}
                </button>
              ))}
            </div>
          ) : null}
          {move.isError ? <ErrorBanner error={move.error} /> : null}

          {o.can_confirm_payment ? (
            <form className="card panel form-stack" onSubmit={confirmPayment} aria-label="تأكيد الدفع">
              <b>تأكيد الدفع وتفعيل الاشتراك</b>
              <p className="field-hint" style={{ margin: 0 }}>
                المبلغ المطلوب <b className="m">{o.amount}</b> {o.currency}. لا تؤكّد إلا بعد التحقق بنفسك من وصول المبلغ. صورة إيصال أو رسالة وحدها لا تكفي.
              </p>
              <Field id="pay-method" label="طريقة الدفع">
                <input id="pay-method" className="fld" value={pay.payment_method} onChange={(e) => setPay({ ...pay, payment_method: e.target.value })} placeholder="مثلاً: تحويل بنكي، جوال باي، نقداً" />
              </Field>
              <Field id="pay-ref" label="رقم العملية / المرجع">
                <input id="pay-ref" className="fld m" dir="ltr" value={pay.transaction_reference} onChange={(e) => setPay({ ...pay, transaction_reference: e.target.value })} />
              </Field>
              <Field id="pay-at" label="تاريخ الدفع" optional>
                <input id="pay-at" type="datetime-local" className="fld" value={pay.paid_at} onChange={(e) => setPay({ ...pay, paid_at: e.target.value })} />
              </Field>
              <Field id="pay-note" label="ملاحظة داخلية" optional>
                <input id="pay-note" className="fld" value={pay.note} onChange={(e) => setPay({ ...pay, note: e.target.value })} />
              </Field>
              <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                <input type="checkbox" checked={pay.payment_verified} onChange={(e) => setPay({ ...pay, payment_verified: e.target.checked })} />
                <span>تحققت بنفسي من وصول المبلغ كاملاً</span>
              </label>
              {confirm.isError ? <ErrorBanner error={confirm.error} /> : null}
              <button type="submit" className="btn btn-p btn-sm" disabled={confirm.isPending || !pay.payment_verified || !pay.payment_method || !pay.transaction_reference}>
                تأكيد الدفع وتفعيل الاشتراك
              </button>
            </form>
          ) : null}

          <form
            className="toolbar"
            onSubmit={(e) => {
              e.preventDefault();
              note.mutate({ id, note: text }, { onSuccess: () => setText("") });
            }}
          >
            <Field id="order-note" label="ملاحظة داخلية (تُرفق أيضاً بتغيير الحالة)">
              <input id="order-note" className="fld" value={text} onChange={(e) => setText(e.target.value)} />
            </Field>
            <button type="submit" className="btn btn-g btn-sm" disabled={!text.trim() || note.isPending}>
              أضف ملاحظة
            </button>
          </form>

          {o.payments.length ? (
            <div>
              <b>المدفوعات</b>
              <ul>
                {o.payments.map((p, i) => (
                  <li key={i}>
                    {p.kind === "payment" ? "دفعة" : p.kind} · <span className="m">{p.amount}</span> {p.currency} · {p.method} · <span className="m">{p.transaction_reference}</span> · {dateTime(p.paid_at)}
                    {p.recorded_by ? ` · سجّلها ${p.recorded_by.name}` : " · مزوّد الدفع"}
                  </li>
                ))}
              </ul>
            </div>
          ) : null}

          <div>
            <b>السجل</b>
            <ol style={{ paddingInlineStart: 18 }}>
              {o.events.map((e, i) => (
                <li key={i}>
                  {dateTime(e.created_at)} · {EVENT[e.type] ?? e.type}
                  {e.to ? ` → ${ORDER_STATUS[e.to]?.[0] ?? e.to}` : ""} · {e.actor?.name ?? "النظام"}
                  {e.note ? ` — ${e.note}` : ""}
                  {e.data?.transaction_reference ? ` (مرجع ${e.data.transaction_reference})` : ""}
                </li>
              ))}
            </ol>
          </div>
        </div>
      )}
    </Dialog>
  );
}

function Plans() {
  const plans = useAdminPlans();
  if (plans.isError) return <ErrorState error={plans.error} onRetry={() => plans.refetch()} />;
  if (!plans.data) return <div className="sk" style={{ height: 160 }} />;
  const meta = plans.data.meta;
  return (
    <div className="form-stack">
      <p className="field-hint">تُحدّث الباقات هنا دون تحديث التطبيق. الباقة غير المسعّرة لا تظهر للمتاجر ولا يمكن تفعيلها.</p>
      {plans.data.data.map((p) => (
        <PlanForm key={p.id} plan={p} meta={meta} />
      ))}
    </div>
  );
}

function PlanForm({ plan, meta }) {
  const update = useUpdatePlan();
  const [form, setForm] = useState({
    name: plan.name,
    description: plan.description ?? "",
    price: plan.price ?? "",
    currency: plan.currency ?? meta.currencies[0],
    is_active: plan.is_active,
    sort_order: plan.sort_order,
    all: plan.features_all,
    features: plan.features,
    max_employees: plan.limits?.max_employees ?? "",
    max_products: plan.limits?.max_products ?? "",
  });
  const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.type === "checkbox" ? e.target.checked : e.target.value }));
  const toggle = (code) => setForm((f) => ({ ...f, features: f.features.includes(code) ? f.features.filter((c) => c !== code) : [...f.features, code] }));

  const save = (e) => {
    e.preventDefault();
    const num = (v) => (v === "" ? null : Number(v));
    update.mutate({
      id: plan.id,
      name: form.name,
      description: form.description || null,
      price: form.price === "" ? null : form.price,
      currency: form.currency,
      is_active: form.is_active,
      sort_order: Number(form.sort_order),
      features: form.all ? null : form.features,
      limits: { max_employees: num(form.max_employees), max_products: num(form.max_products) },
    });
  };

  return (
    <form className="card panel form-stack" onSubmit={save} aria-label={`باقة ${plan.name}`}>
      <b>
        {plan.code} · {monthsLabel(plan.duration_months)} {plan.orderable ? "· معروضة للبيع" : "· غير معروضة"}
      </b>
      <div className="toolbar" style={{ flexWrap: "wrap" }}>
        <Field id={`pn-${plan.id}`} label="الاسم">
          <input id={`pn-${plan.id}`} className="fld" value={form.name} onChange={set("name")} />
        </Field>
        <Field id={`pp-${plan.id}`} label="السعر">
          <input id={`pp-${plan.id}`} className="fld m" dir="ltr" inputMode="decimal" value={form.price} onChange={set("price")} placeholder="—" />
        </Field>
        <Field id={`pc-${plan.id}`} label="العملة">
          <select id={`pc-${plan.id}`} className="fld" value={form.currency} onChange={set("currency")}>
            {meta.currencies.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </Field>
        <Field id={`po-${plan.id}`} label="الترتيب">
          <input id={`po-${plan.id}`} className="fld m" type="number" min={0} value={form.sort_order} onChange={set("sort_order")} />
        </Field>
      </div>
      <Field id={`pd-${plan.id}`} label="الوصف" optional>
        <input id={`pd-${plan.id}`} className="fld" value={form.description} onChange={set("description")} />
      </Field>
      <fieldset style={{ border: 0, padding: 0 }}>
        <legend className="field-hint">الميزات</legend>
        <label style={{ display: "flex", gap: 8 }}>
          <input type="checkbox" checked={form.all} onChange={set("all")} /> كل الميزات
        </label>
        {!form.all
          ? Object.entries(meta.features).map(([code, label]) => (
              <label key={code} style={{ display: "flex", gap: 8 }}>
                <input type="checkbox" checked={form.features.includes(code)} onChange={() => toggle(code)} /> {label}
              </label>
            ))
          : null}
      </fieldset>
      <div className="toolbar">
        <Field id={`pe-${plan.id}`} label="أقصى عدد موظفين" optional>
          <input id={`pe-${plan.id}`} className="fld m" type="number" min={0} value={form.max_employees} onChange={set("max_employees")} placeholder="بلا حد" />
        </Field>
        <Field id={`pm-${plan.id}`} label="أقصى عدد أصناف" optional>
          <input id={`pm-${plan.id}`} className="fld m" type="number" min={1} value={form.max_products} onChange={set("max_products")} placeholder="بلا حد" />
        </Field>
      </div>
      <label style={{ display: "flex", gap: 8 }}>
        <input type="checkbox" checked={form.is_active} onChange={set("is_active")} /> معروضة للبيع
      </label>
      {update.isError ? <ErrorBanner error={update.error} /> : null}
      {update.isSuccess ? <p role="status" className="field-hint">حُفظت الباقة.</p> : null}
      <div>
        <button type="submit" className="btn btn-p btn-sm" disabled={update.isPending}>
          حفظ الباقة
        </button>
      </div>
    </form>
  );
}
