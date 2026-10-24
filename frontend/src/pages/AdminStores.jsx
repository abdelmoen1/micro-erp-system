import { useDeferredValue, useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { AccessSwitch, SubscriptionBadge } from "../components/platform";
import { daysAgo } from "../lib/platform";
import { DataTable, EmptyState, ErrorBanner, PageHeader, Pager, Segments } from "../components/ui";
import { dateOnly } from "../lib/format";
import { useAdminOverview, useAdminStores } from "../services/admin";

const SORTS = [
  ["newest", "الأحدث تسجيلاً"],
  ["oldest", "الأقدم تسجيلاً"],
  ["name", "بالاسم"],
];

/** Platform owner · every registered store: counts, search, the two state filters and paging. */
export default function AdminStores() {
  const overview = useAdminOverview();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("all");
  const [subscription, setSubscription] = useState("all");
  const [sort, setSort] = useState("newest");
  const [pageNo, setPageNo] = useState(1);
  const query = useDeferredValue(search.trim());

  const list = useAdminStores({
    search: query,
    status: status === "all" ? undefined : status,
    subscription: subscription === "all" ? undefined : subscription,
    sort,
    page: pageNo,
    per_page: 20,
  });
  const rows = list.data?.data ?? [];
  const o = overview.data;
  const reset = (setter) => (value) => {
    setter(value);
    setPageNo(1);
  };

  const columns = [
    {
      key: "name",
      label: "المتجر",
      render: (s) => (
        <>
          <Link className="row-link" to={`/admin/stores/${s.id}`}>
            {s.name}
          </Link>
          <span className="cell-sub">{s.owner ? s.owner.name : "بلا مالك مسجّل"}</span>
          {s.owner ? (
            <span className="cell-sub m" style={{ textAlign: "right" }}>
              {s.owner.email}
            </span>
          ) : null}
        </>
      ),
    },
    {
      key: "contact",
      label: "التواصل والموقع",
      render: (s) => (
        <>
          <span className="m">{s.phone || s.owner?.phone || "—"}</span>
          <span className="cell-sub">{s.address || "لا عنوان"}</span>
        </>
      ),
    },
    {
      key: "registered",
      label: "التسجيل",
      render: (s) => (
        <>
          <span className="m">{dateOnly(s.created_at)}</span>
          <span className="cell-sub">{daysAgo(s.days_since_registration)}</span>
        </>
      ),
    },
    { key: "status", label: "الحساب", render: (s) => <AccessSwitch store={s} compact /> },
    {
      key: "subscription",
      label: "الاشتراك",
      render: (s) => (
        <>
          <SubscriptionBadge state={s.subscription.state} />
          {s.subscription.state === "trial" && s.subscription.trial_ends_at ? (
            <span className="cell-sub">
              تنتهي <span className="m">{dateOnly(s.subscription.trial_ends_at)}</span>
            </span>
          ) : s.subscription.expires_at ? (
            <span className="cell-sub">
              حتى <span className="m">{dateOnly(s.subscription.expires_at)}</span>
            </span>
          ) : null}
        </>
      ),
    },
    { key: "products", label: "المنتجات", numeric: true, render: (s) => <span className="m">{s.products_count}</span> },
  ];

  const filtered = query || status !== "all" || subscription !== "all";

  return (
    <>
      <PageHeader title="المتاجر" sub={o ? `${o.stores.total} متجراً مسجّلاً، ${o.stores.registered_last_30_days} منها خلال آخر 30 يوماً` : " "} />

      <ErrorBanner error={overview.error} />
      <section className="platform-counts" aria-label="ملخص المنصة">
        <Count label="كل المتاجر" value={o?.stores.total} />
        <Count label="حسابات مفعّلة" value={o?.stores.active} />
        <Count label="حسابات موقوفة" value={o?.stores.suspended} tone="danger" />
        <Count label="اشتراكات فعّالة" value={o?.subscriptions.active} tone="ok" />
        <Count label="في الفترة التجريبية" value={o?.subscriptions.trial} />
        <Count label="اشتراكات منتهية" value={o?.subscriptions.expired} tone="warn" />
        <Count label="بلا اشتراك" value={o?.subscriptions.inactive} />
      </section>

      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث في المتاجر</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="اسم المتجر، الهاتف، العنوان أو بريد المالك"
            value={search}
            onChange={(e) => reset(setSearch)(e.target.value)}
          />
        </label>
        <label className="field platform-sort">
          <span className="sr-only">الترتيب</span>
          <select className="fld" value={sort} onChange={(e) => reset(setSort)(e.target.value)}>
            {SORTS.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>
      </div>
      <div className="platform-filters">
        <Segments
          label="حالة الحساب"
          value={status}
          onChange={reset(setStatus)}
          options={[
            ["all", "كل الحسابات"],
            ["active", "مفعّلة", o?.stores.active],
            ["suspended", "موقوفة", o?.stores.suspended],
          ]}
        />
        <Segments
          label="حالة الاشتراك"
          value={subscription}
          onChange={reset(setSubscription)}
          options={[
            ["all", "كل الاشتراكات"],
            ["active", "فعّال", o?.subscriptions.active],
            ["trial", "تجريبي", o?.subscriptions.trial],
            ["expired", "منتهٍ", o?.subscriptions.expired],
            ["inactive", "بلا اشتراك", o?.subscriptions.inactive],
          ]}
        />
      </div>

      <DataTable
        query={list}
        rows={rows}
        columns={columns}
        caption="المتاجر المسجّلة"
        minWidth={860}
        empty={
          filtered ? (
            <EmptyState icon="search" title="لا متاجر تطابق هذا البحث" text="غيّر كلمة البحث أو اختر «كل الحسابات» و«كل الاشتراكات»." />
          ) : (
            <EmptyState icon="shop" title="لم يسجّل أي متجر بعد" text="تظهر المتاجر هنا فور تسجيلها من صفحة الانضمام أو من تطبيق الجوال." />
          )
        }
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      <p className="data-note">
        المتجر الجديد يبدأ بفترة تجريبية 7 أيام. بعد انتهائها، أو انتهاء الاشتراك، يدخل أعضاء المتجر ويرون شاشة التجديد فقط حتى يُفعَّل الاشتراك. إيقاف الحساب يمنع الدخول كلياً.
      </p>
    </>
  );
}

function Count({ label, value, tone }) {
  return (
    <div className={`card mini platform-count${tone ? ` is-${tone}` : ""}`}>
      <span className="label">{label}</span>
      {value === undefined ? <span className="sk" style={{ height: 26, width: 48 }} /> : <span className="value m">{value}</span>}
    </div>
  );
}
