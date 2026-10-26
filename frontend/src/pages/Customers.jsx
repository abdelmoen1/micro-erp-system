import { useDeferredValue, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Icon from "../components/Icon";
import { CustomerFormDialog } from "../components/dialogs";
import { DataTable, EmptyState, MoneyText, PageHeader, Pager, Segments, StatusBadge } from "../components/ui";
import { isPositiveAmount } from "../lib/format";
import { session } from "../services/apiClient";
import { useCustomers } from "../services/backoffice";
import { canManage } from "../lib/domain";

const FILTERS = [
  ["all", "الكل"],
  ["with_balance", "عليهم دين"],
  ["overdue", "متأخرون"],
  ["inactive", "موقوفون"],
];

/** SCR-W-06 · customers: search, balance and overdue badges, create (US-0301). */
export default function Customers() {
  const navigate = useNavigate();
  const user = session.user();
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [pageNo, setPageNo] = useState(1);
  // The dashboard's «زبون جديد» opens /customers?new=1 with the form already open.
  const [creating, setCreating] = useState(() => new URLSearchParams(window.location.search).has("new"));
  const query = useDeferredValue(search.trim());

  const params = {
    search: query,
    page: pageNo,
    per_page: 20,
    status: filter === "inactive" ? "inactive" : "all",
    filter: filter === "with_balance" || filter === "overdue" ? filter : undefined,
  };
  const list = useCustomers(params);
  const rows = list.data?.data ?? [];

  const columns = [
    {
      key: "name",
      label: "الزبون",
      render: (c) => (
        <>
          <Link className="row-link" to={`/customers/${c.id}`}>
            {c.name}
          </Link>
          <span className="cell-sub m" style={{ textAlign: "right" }}>
            {c.phone}
          </span>
        </>
      ),
    },
    {
      key: "status",
      label: "الحالة",
      render: (c) =>
        c.status === "inactive" ? <StatusBadge status="inactive" /> : isPositiveAmount(c.overdue) ? <StatusBadge status="overdue" /> : <StatusBadge status="active" label="نشط" />,
    },
    { key: "limit", label: "حد الدين", render: (c) => (c.credit_limit ? <MoneyText value={c.credit_limit} /> : <span className="cell-sub">بلا حد</span>) },
    {
      key: "balance",
      label: "الرصيد المستحق",
      numeric: true,
      render: (c) => <MoneyText value={c.balance} style={{ fontWeight: 700, color: isPositiveAmount(c.balance) ? "var(--debt-fg)" : "var(--ink-muted)" }} />,
    },
  ];

  const empty =
    query || filter !== "all" ? (
      <EmptyState icon="search" title={query ? `لا زبون يطابق «${query}»` : "لا زبائن في هذه القائمة"} text={query ? "جرّب جزءاً من الاسم أو آخر 4 أرقام من الهاتف." : null}>
        {query ? (
          <button type="button" className="btn btn-s btn-sm" onClick={() => setCreating(true)}>
            إضافة «{query}» زبوناً جديداً
          </button>
        ) : null}
      </EmptyState>
    ) : (
      <EmptyState icon="customers" title="لا زبائن بعد" text="أضف زبائن الدين أولاً، أو أضفهم من الجوال عند البيع. البيع النقدي لا يحتاج زبوناً.">
        <button type="button" className="btn btn-p btn-sm" onClick={() => setCreating(true)}>
          إضافة أول زبون
        </button>
      </EmptyState>
    );

  return (
    <>
      <PageHeader title="الزبائن" sub={list.data?.meta ? `${list.data.meta.total} زبوناً في هذه القائمة` : " "}>
        <button type="button" className="btn btn-p btn-sm" onClick={() => setCreating(true)}>
          <Icon name="plus" size={16} strokeWidth={2.2} />
          زبون جديد
        </button>
      </PageHeader>

      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث بالاسم أو الهاتف</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="بحث بالاسم أو رقم الهاتف"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
        <Segments
          label="تصفية"
          value={filter}
          options={FILTERS}
          onChange={(v) => {
            setFilter(v);
            setPageNo(1);
          }}
        />
      </div>

      <DataTable query={list} rows={rows} columns={columns} caption="قائمة الزبائن" empty={empty} minWidth={640} />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      <p className="data-note">الرصيد = مجموع المتبقي على ديون الزبون.</p>

      {creating ? (
        <CustomerFormDialog
          canSetLimit={canManage(user)}
          onClose={() => setCreating(false)}
          onSaved={(saved) => {
            setCreating(false);
            if (saved?.id) navigate(`/customers/${saved.id}`);
          }}
        />
      ) : null}
    </>
  );
}

