import { useDeferredValue, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { AccessSwitch } from "../components/platform";
import { ROLE_LABEL, daysAgo, daysLeftLabel } from "../lib/platform";
import { Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, Field, MoneyText, PageHeader, Pager, QtyText, ReasonField, StatusBadge } from "../components/ui";
import { dateOnly, dateTime } from "../lib/format";
import { stockState } from "../lib/domain";
import { useAdminStore, useAdminStoreProducts, useSetSubscription } from "../services/admin";

const HISTORY = {
  "store.suspended": "أُوقف حساب المتجر",
  "store.reactivated": "أُعيد تفعيل حساب المتجر",
  "store.subscription_activated": "فُعّل الاشتراك",
  "store.subscription_deactivated": "أُوقف الاشتراك",
};

/** Platform owner · one store: access and subscription controls, contact, members, history, products. */
export default function AdminStore() {
  const { id } = useParams();
  const store = useAdminStore(id);
  const [dialog, setDialog] = useState(null);

  if (store.isError) return <ErrorState error={store.error} onRetry={() => store.refetch()} />;
  const s = store.data;
  if (!s) {
    return (
      <div className="card state-card" aria-busy="true">
        <span className="sk" style={{ height: 22, width: 220 }} />
        <span className="sk" style={{ height: 14, width: 320 }} />
      </div>
    );
  }

  return (
    <>
      <Crumbs items={[["المتاجر", "/admin"], [s.name]]} />
      <PageHeader title={s.name} sub={`سُجّل في ${dateOnly(s.created_at)}، ${daysAgo(s.days_since_registration)}`} />

      <div className="state-panels">
        <AccessPanel store={s} />
        <SubscriptionPanel store={s} onActivate={() => setDialog("subscribe")} onDeactivate={() => setDialog("unsubscribe")} />
      </div>
      <p className="data-note">
        الحالتان منفصلتان: إيقاف الحساب لا يغيّر الاشتراك، وتفعيل الاشتراك لا يعيد فتح حساب موقوف. بعد انتهاء الفترة التجريبية أو الاشتراك، يرى أعضاء المتجر شاشة التجديد فقط وتبقى بياناتهم كما هي.
      </p>

      <div className="platform-grid">
        <section className="card panel" aria-labelledby="store-info">
          <div className="panel-head">
            <h2 id="store-info">بيانات المتجر</h2>
          </div>
          <dl className="facts">
            <Fact label="المالك" value={s.owner ? s.owner.name : "بلا مالك مسجّل"} />
            <Fact label="بريد المالك" value={s.owner?.email} ltr />
            <Fact label="هاتف المالك" value={s.owner?.phone} ltr />
            <Fact label="هاتف المتجر" value={s.phone} ltr />
            <Fact label="العنوان" value={s.address} />
            <Fact label="المنطقة الزمنية" value={s.timezone} ltr />
            <Fact label="المنتجات" value={`${s.products_count} (${s.active_products_count} نشطة)`} />
            <Fact label="الأعضاء" value={String(s.users_count)} />
          </dl>
        </section>

        <section className="card panel" aria-labelledby="store-members">
          <div className="panel-head">
            <h2 id="store-members">أعضاء المتجر</h2>
          </div>
          <ul className="list">
            {s.members.map((m) => (
              <li key={m.id}>
                <span>
                  <b>{m.name}</b>
                  <span className="cell-sub m" style={{ textAlign: "right" }}>
                    {m.email}
                  </span>
                </span>
                <span className="member-meta">
                  {ROLE_LABEL[m.role] ?? m.role}
                  {m.status === "inactive" ? <StatusBadge status="inactive" label="موقوف" /> : null}
                </span>
              </li>
            ))}
          </ul>
        </section>
      </div>

      <section className="card panel" aria-labelledby="store-history">
        <div className="panel-head">
          <h2 id="store-history">سجل التغييرات</h2>
        </div>
        {s.history.length === 0 ? (
          <p className="cell-sub">لم تتغير حالة الحساب أو الاشتراك منذ التسجيل.</p>
        ) : (
          <ol className="list history">
            {s.history.map((h) => (
              <li key={h.id}>
                <span>
                  <b>{HISTORY[h.action] ?? h.action}</b>
                  <span className="cell-sub">{historyDetail(h.metadata)}</span>
                </span>
                <span className="cell-sub">
                  <span className="m">{dateTime(h.at)}</span>
                  {h.by ? ` — ${h.by.name}` : ""}
                </span>
              </li>
            ))}
          </ol>
        )}
      </section>

      <StoreProducts storeId={s.id} storeName={s.name} />

      {dialog === "subscribe" ? <SubscribeDialog store={s} onClose={() => setDialog(null)} /> : null}
      {dialog === "unsubscribe" ? <UnsubscribeDialog store={s} onClose={() => setDialog(null)} /> : null}
    </>
  );
}

function historyDetail(meta = {}) {
  const parts = [];
  if (meta.reason) parts.push(`السبب: ${meta.reason}`);
  if (meta.expires_at) parts.push(`ينتهي ${dateOnly(meta.expires_at)}`);
  if (meta.note) parts.push(`ملاحظة: ${meta.note}`);
  return parts.join("، ");
}

function Fact({ label, value, ltr }) {
  return (
    <div>
      <dt>{label}</dt>
      <dd className={ltr && value ? "m" : undefined}>{value || "—"}</dd>
    </div>
  );
}

function Changed({ at, by }) {
  if (!at) return <span>لم تتغير منذ التسجيل</span>;
  return (
    <span>
      آخر تغيير <span className="m">{dateTime(at)}</span>
      {by ? ` بواسطة ${by.name}` : ""}
    </span>
  );
}

function AccessPanel({ store }) {
  const suspended = store.status === "suspended";
  return (
    <section className={`card state-panel ${suspended ? "is-off" : "is-on"}`} aria-labelledby="access-title">
      <div className="state-head">
        <h2 id="access-title">حساب المتجر</h2>
        <AccessSwitch store={store} />
      </div>
      <p className="state-word">
        <Icon name={suspended ? "ban" : "ok"} size={26} strokeWidth={2} />
        {suspended ? "موقوف" : "مفعّل"}
      </p>
      <p className="state-means">{suspended ? "لا يستطيع المالك ولا الموظفون الدخول أو استخدام التطبيق." : "المالك والموظفون يدخلون ويعملون كالمعتاد."}</p>
      <dl className="state-facts">
        {suspended && store.suspension_reason ? (
          <div>
            <dt>السبب</dt>
            <dd>{store.suspension_reason}</dd>
          </div>
        ) : null}
        <div>
          <dt>التغيير</dt>
          <dd>
            <Changed at={store.status_changed_at} by={store.status_changed_by} />
          </dd>
        </div>
      </dl>
    </section>
  );
}

function SubscriptionPanel({ store, onActivate, onDeactivate }) {
  const sub = store.subscription;
  const word = { active: "فعّال", trial: "فترة تجريبية", expired: "منتهٍ", inactive: "غير مشترك" }[sub.state];
  const tone = { active: "is-on", trial: "is-trial", expired: "is-warn", inactive: "is-off" }[sub.state];
  return (
    <section className={`card state-panel ${tone}`} aria-labelledby="sub-title">
      <h2 id="sub-title">الاشتراك</h2>
      <p className="state-word">
        <Icon name={sub.state === "active" ? "ok" : sub.state === "inactive" ? "ban" : "clock"} size={26} strokeWidth={2} />
        {word}
      </p>
      <p className="state-means">
        {sub.state === "active"
          ? sub.expires_at
            ? "مدفوع ومفعّل حتى تاريخ الانتهاء."
            : "مدفوع ومفعّل بلا تاريخ انتهاء."
          : sub.state === "trial"
            ? `${sub.trial_ends_at ? `${daysLeftLabel(sub.trial_ends_at)} من الفترة المجانية` : "فترة مجانية"}، ثم يحتاج المتجر اشتراكاً ليستمر.`
            : sub.state === "expired"
              ? "انتهى الاشتراك: الأعضاء يرون شاشة التجديد فقط. جدّد بعد التحقق من الدفع."
              : "انتهت الفترة التجريبية بلا اشتراك: الأعضاء يرون شاشة التجديد فقط."}
      </p>
      <dl className="state-facts">
        <div>
          <dt>نهاية الفترة التجريبية</dt>
          <dd className="m">{sub.trial_ends_at ? dateTime(sub.trial_ends_at) : "—"}</dd>
        </div>
        <div>
          <dt>بداية الاشتراك</dt>
          <dd className="m">{sub.started_at ? dateOnly(sub.started_at) : "—"}</dd>
        </div>
        <div>
          <dt>تاريخ الانتهاء</dt>
          <dd className="m">{sub.expires_at ? dateOnly(sub.expires_at) : "—"}</dd>
        </div>
        <div>
          <dt>التغيير</dt>
          <dd>
            <Changed at={sub.changed_at} by={sub.changed_by} />
          </dd>
        </div>
      </dl>
      <div className="state-actions">
        <button type="button" className="btn btn-sm btn-p" onClick={onActivate}>
          {sub.status === "active" ? "تجديد أو تعديل الانتهاء" : "تفعيل الاشتراك"}
        </button>
        {sub.status === "active" ? (
          <button type="button" className="btn btn-sm btn-dl" onClick={onDeactivate}>
            إيقاف الاشتراك
          </button>
        ) : null}
      </div>
    </section>
  );
}

/** Tomorrow as YYYY-MM-DD in the browser's zone: the earliest expiry the server accepts as a date. */
function tomorrow() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function SubscribeDialog({ store, onClose }) {
  const save = useSetSubscription();
  const current = store.subscription.expires_at ? store.subscription.expires_at.slice(0, 10) : "";
  const [expires, setExpires] = useState(current && current >= tomorrow() ? current : "");
  const [note, setNote] = useState("");
  const renewing = store.subscription.status === "active";
  const fieldError = save.error?.fieldError?.("expires_at");

  const submit = (e) => {
    e.preventDefault();
    save.mutate(
      { id: store.id, status: "active", ...(expires ? { expires_at: expires } : {}), ...(note.trim() ? { note: note.trim() } : {}) },
      { onSuccess: onClose },
    );
  };

  return (
    <Dialog title={renewing ? `تجديد اشتراك ${store.name}` : `تفعيل اشتراك ${store.name}`} onClose={onClose}>
      <form className="form-stack" onSubmit={submit}>
        <p className="cell-sub">فعّل الاشتراك بعد التحقق من وصول الدفعة. لا يُخصم أي مبلغ من هنا، ولا يتغير وصول الحساب.</p>
        <Field id="sub-expires" label="ينتهي في نهاية يوم" optional error={fieldError} hint="اتركه فارغاً لاشتراك بلا تاريخ انتهاء. اليوم يُحسب بتوقيت المتجر.">
          <input
            id="sub-expires"
            type="date"
            className={`fld ltr${fieldError ? " err" : ""}`}
            min={tomorrow()}
            value={expires}
            onChange={(e) => setExpires(e.target.value)}
            aria-invalid={Boolean(fieldError)}
            aria-describedby={fieldError ? "sub-expires-error" : undefined}
          />
        </Field>
        <ReasonField id="sub-note" label="ملاحظة الدفع (اختياري)" value={note} onChange={setNote} error={save.error?.fieldError?.("note")} />
        <ErrorBanner error={fieldError ? null : save.error} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={save.isPending}>
            {save.isPending ? "جارٍ الحفظ…" : renewing ? "حفظ التجديد" : "تفعيل الاشتراك"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            رجوع
          </button>
        </div>
      </form>
    </Dialog>
  );
}

function UnsubscribeDialog({ store, onClose }) {
  const save = useSetSubscription();
  const [note, setNote] = useState("");
  return (
    <Dialog title={`إيقاف اشتراك ${store.name}؟`} role="alertdialog" onClose={onClose}>
      <p>يُسجَّل المتجر بلا اشتراك. حساب المتجر يبقى كما هو، ويستمر أعضاؤه في الدخول.</p>
      <ReasonField id="unsub-note" label="ملاحظة (اختياري)" value={note} onChange={setNote} error={save.error?.fieldError?.("note")} />
      <ErrorBanner error={save.error} />
      <div className="dlg-actions">
        <button
          type="button"
          className="btn btn-dd"
          disabled={save.isPending}
          onClick={() => save.mutate({ id: store.id, status: "inactive", ...(note.trim() ? { note: note.trim() } : {}) }, { onSuccess: onClose })}
        >
          {save.isPending ? "جارٍ الحفظ…" : "إيقاف الاشتراك"}
        </button>
        <button type="button" className="btn btn-g" onClick={onClose}>
          رجوع
        </button>
      </div>
    </Dialog>
  );
}

/** This store's own rows: its prices, costs and stock only. */
function StoreProducts({ storeId, storeName }) {
  const [search, setSearch] = useState("");
  const [pageNo, setPageNo] = useState(1);
  const query = useDeferredValue(search.trim());
  const list = useAdminStoreProducts(storeId, { search: query, page: pageNo, per_page: 20 });

  return (
    <section className="platform-section" aria-labelledby="store-products">
      <div className="page-head">
        <h2 id="store-products" className="section-title">
          منتجات {storeName}
        </h2>
        <label className="search platform-inline-search">
          <span className="sr-only">بحث في منتجات المتجر</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="الاسم أو الباركود"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
      </div>
      <DataTable
        query={list}
        rows={list.data?.data ?? []}
        caption={`منتجات ${storeName}`}
        minWidth={760}
        empty={<EmptyState icon="products" title={query ? `لا منتج يطابق «${query}»` : "لا منتجات في هذا المتجر بعد"} />}
        columns={[
          {
            key: "name",
            label: "المنتج",
            render: (p) => (
              <>
                <b style={{ fontWeight: 600 }}>{p.name}</b>
                <span className="cell-sub">
                  {p.barcode ? <span className="m">{p.barcode}</span> : "بلا باركود"}
                  {p.catalog_product ? (
                    <>
                      {" "}
                      <Link to={`/admin/catalog/${p.catalog_product.id}`}>المتاجر الأخرى</Link>
                    </>
                  ) : null}
                </span>
              </>
            ),
          },
          { key: "price", label: "سعر البيع", numeric: true, render: (p) => <MoneyText value={p.selling_price} /> },
          { key: "cost", label: "سعر الشراء", numeric: true, render: (p) => (p.cost_price ? <MoneyText value={p.cost_price} /> : <span className="cell-sub">—</span>) },
          { key: "stock", label: "المخزون", numeric: true, render: (p) => <QtyText value={p.current_stock} unit={p.unit} /> },
          {
            key: "status",
            label: "الحالة",
            render: (p) => (p.status === "inactive" ? <StatusBadge status="inactive" label="معطّل" /> : <StatusBadge status={stockState(p)} />),
          },
        ]}
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
    </section>
  );
}
