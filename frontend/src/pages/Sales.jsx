import { useState } from "react";
import { Link } from "react-router-dom";
import { DataTable, EmptyState, Field, MoneyText, PageHeader, Pager, Segments, StatusBadge } from "../components/ui";
import { saleType } from "../lib/domain";
import { dateTime, isPositiveAmount } from "../lib/format";
import { useSales } from "../services/backoffice";


/** SCR-W-10 · sales list: date range, type and status filters (US-0504 AC1). */
export default function Sales() {
  const [filters, setFilters] = useState({ from: "", to: "", type: "", status: "active" });
  const [pageNo, setPageNo] = useState(1);
  const set = (patch) => {
    setFilters({ ...filters, ...patch });
    setPageNo(1);
  };
  const list = useSales({ ...filters, source: "sale", page: pageNo, per_page: 20 });
  const rows = (list.data?.data ?? []).map((s) => ({ ...s, __class: s.status === "voided" ? "voided" : undefined }));

  const columns = [
    { key: "no", label: "الفاتورة", render: (s) => <Link to={`/sales/${s.id}`} className="m">#{s.id}</Link> },
    { key: "at", label: "التاريخ", render: (s) => <span className="m">{dateTime(s.created_at)}</span> },
    { key: "cust", label: "الزبون", render: (s) => (s.customer ? <Link className="row-link" to={`/customers/${s.customer.id}`}>{s.customer.name}</Link> : <span className="cell-sub">بدون زبون</span>) },
    { key: "by", label: "البائع", render: (s) => s.seller?.name ?? "—" },
    { key: "type", label: "النوع", render: (s) => (s.status === "voided" ? <StatusBadge status="voided" /> : <StatusBadge status={saleType(s)} />) },
    { key: "total", label: "الإجمالي", numeric: true, render: (s) => <MoneyText className="strike" value={s.total_amount} style={{ fontWeight: 700 }} /> },
    {
      key: "rem",
      label: "المتبقي",
      numeric: true,
      render: (s) => (s.debt && isPositiveAmount(s.debt.remaining_amount) ? <MoneyText value={s.debt.remaining_amount} style={{ color: "var(--debt-fg)", fontWeight: 600 }} /> : "—"),
    },
  ];

  return (
    <>
      <PageHeader title="المبيعات" sub={list.data?.meta ? `${list.data.meta.total} فاتورة في هذه التصفية` : " "} />
      <div className="card panel">
        <div className="toolbar">
          <Field id="sf-from" label="من">
            <input id="sf-from" type="date" className="fld date-fld" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
          </Field>
          <Field id="sf-to" label="إلى">
            <input id="sf-to" type="date" className="fld date-fld" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
          </Field>
          <div className="field">
            <span className="field-label">النوع</span>
            <Segments
              label="النوع"
              value={filters.type}
              options={[
                ["", "الكل"],
                ["cash", "نقدي"],
                ["partial", "جزئي"],
                ["credit", "دين"],
              ]}
              onChange={(type) => set({ type })}
            />
          </div>
          <div className="field">
            <span className="field-label">الحالة</span>
            <Segments
              label="الحالة"
              value={filters.status}
              options={[
                ["active", "فعّالة"],
                ["voided", "ملغاة"],
                ["all", "الكل"],
              ]}
              onChange={(status) => set({ status })}
            />
          </div>
        </div>
      </div>
      <DataTable
        query={list}
        rows={rows}
        columns={columns}
        caption="قائمة المبيعات"
        minWidth={820}
        empty={<EmptyState icon="sales" title="لا مبيعات تطابق هذه التصفية" text="وسّع نطاق التاريخ أو اختر «الكل». المبيعات تُسجَّل من تطبيق الجوال." />}
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
    </>
  );
}
