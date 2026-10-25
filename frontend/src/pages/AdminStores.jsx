import { useDeferredValue, useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Link, useLocation } from "react-router-dom";
import Icon from "../components/Icon";
import { AccessSwitch, SubscriptionBadge } from "../components/platform";
import { daysAgo, daysLeftLabel } from "../lib/platform";
import { DataTable, EmptyState, ErrorBanner, PageHeader, Pager } from "../components/ui";
import { dateOnly } from "../lib/format";
import { useAdminOverview, useAdminStores } from "../services/admin";
import { queryKeys } from "../services/queryClient";

const SORTS = [
  ["newest", "الأحدث تسجيلاً"],
  ["oldest", "الأقدم تسجيلاً"],
  ["name", "بالاسم"],
];

/** Platform owner · every registered store: counts, search, the two state filters and paging. */
export default function AdminStores() {
  const queryClient = useQueryClient();
  const deleted = useLocation().state?.deleted;
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
  // New registrations from the web or the phone show up on demand (and on returning to the tab).
  const refresh = () => queryClient.invalidateQueries({ queryKey: queryKeys.admin.all });

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
          <span className="cell-sub">{s.address || s.area || "لا عنوان"}</span>
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
            <>
              <span className="cell-sub cell-strong">{daysLeftLabel(s.subscription.trial_ends_at)}</span>
              <span className="cell-sub">
                حتى <span className="m">{dateOnly(s.subscription.trial_ends_at)}</span>
              </span>
            </>
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
  const updatedAt = Math.max(list.dataUpdatedAt || 0, overview.dataUpdatedAt || 0);

  return (
    <>
      <PageHeader title="المتاجر" sub={o ? `${o.stores.total} متجراً مسجّلاً، ${o.stores.registered_last_30_days} منها خلال آخر 30 يوماً` : " "}>
        <span className="platform-updated" aria-live="polite">
          {updatedAt ? (
            <>
              آخر تحديث <span className="m">{clockTime(updatedAt)}</span>
            </>
          ) : null}
        </span>
        <button type="button" className="btn btn-g btn-sm" onClick={refresh} disabled={list.isFetching || overview.isFetching} aria-busy={list.isFetching}>
          <Icon name="spinner" size={16} className={list.isFetching ? "spin" : undefined} />
          تحديث
        </button>
      </PageHeader>

      {deleted ? (
        <p role="status" className="banner tone-success">
          <Icon name="ok" size={20} />
          حُذف متجر «{deleted}» وكل بياناته نهائياً.
        </p>
      ) : null}
      <ErrorBanner error={overview.error} />
      <div className="filter-groups">
        <FilterTiles
          label="حساب المتجر"
          value={status}
          onChange={reset(setStatus)}
          tiles={[
            ["all", "كل المتاجر", o?.stores.total],
            ["active", "مفعّلة", o?.stores.active, "ok"],
            ["suspended", "موقوفة", o?.stores.suspended, "danger"],
          ]}
        />
        <FilterTiles
          label="الاشتراك"
          value={subscription}
          onChange={reset(setSubscription)}
          tiles={[
            ["all", "الكل", o?.stores.total],
            ["active", "فعّال", o?.subscriptions.active, "ok"],
            ["trial", "تجريبي", o?.subscriptions.trial, "info"],
            ["expired", "منتهٍ", o?.subscriptions.expired, "warn"],
            ["inactive", "انتهت التجربة", o?.subscriptions.inactive, "danger"],
          ]}
        />
      </div>

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

      <DataTable
        query={list}
        rows={rows}
        columns={columns}
        caption="المتاجر المسجّلة"
        minWidth={860}
        empty={
          filtered ? (
            <EmptyState icon="search" title="لا متاجر تطابق هذا البحث" text="غيّر كلمة البحث، أو اختر «كل المتاجر» و«الكل» في الفلاتر.">
              <button
                type="button"
                className="btn btn-s btn-sm"
                onClick={() => {
                  setSearch("");
                  setStatus("all");
                  setSubscription("all");
                  setPageNo(1);
                }}
              >
                عرض كل المتاجر
              </button>
            </EmptyState>
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

const clockTime = (ms) => new Date(ms).toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });

/**
 * A labelled group of filter tiles: each tile shows its count and filters the list when pressed
 * (aria-pressed), so a number is shown once and is always actionable.
 */
function FilterTiles({ label, value, onChange, tiles }) {
  return (
    <div className="filter-group" role="group" aria-label={label}>
      <span className="filter-group-label" aria-hidden="true">
        {label}
      </span>
      <div className="filter-tiles">
        {tiles.map(([key, text, count, tone]) => (
          <button
            key={key}
            type="button"
            className={`filter-tile${tone ? ` is-${tone}` : ""}`}
            aria-pressed={value === key}
            onClick={() => onChange(key)}
          >
            {count === undefined ? <span className="sk" style={{ height: 24, width: 32 }} /> : <span className="filter-count m">{count}</span>}
            <span className="filter-text">{text}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
