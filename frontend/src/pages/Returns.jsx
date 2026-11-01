import { useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import { usePrint } from "../components/usePrint";
import { DataTable, EmptyState, Field, MoneyText, PageHeader, Pager, Segments } from "../components/ui";
import { canManage } from "../lib/domain";
import { dateTime } from "../lib/format";
import { purchaseReturnDoc, saleReturnDoc } from "../lib/printDocs";
import { session } from "../services/apiClient";
import { usePurchaseReturns, useSaleReturns } from "../services/backoffice";

/** Both return registers: from customers and, for owners and managers, to suppliers. */
export default function Returns() {
  const manager = canManage(session.user());
  const [params] = useSearchParams();
  const [tab, setTab] = useState("sales");
  const [filters, setFilters] = useState({ from: params.get("from") ?? "", to: params.get("to") ?? "" });
  const [pageNo, setPageNo] = useState(1);
  const { print, sheet } = usePrint();
  const set = (patch) => {
    setFilters({ ...filters, ...patch });
    setPageNo(1);
  };
  const query = { ...filters, page: pageNo, per_page: 20 };
  const sales = useSaleReturns(query, tab === "sales");
  const purchases = usePurchaseReturns(query, tab === "purchases");
  const list = tab === "sales" ? sales : purchases;

  const lines = (r) => (r.items ?? []).map((i) => `${i.quantity} × ${i.item_name}`).join("، ");
  const printButton = (doc) => (
    <button type="button" className="text-btn" onClick={() => print(doc)}>
      طباعة
    </button>
  );

  const saleColumns = [
    { key: "no", label: "الفاتورة", render: (r) => <Link to={`/sales/${r.invoice_id}`} className="m">#{r.invoice_id}</Link> },
    { key: "at", label: "التاريخ", render: (r) => <span className="m">{dateTime(r.created_at)}</span> },
    { key: "who", label: "الزبون", render: (r) => r.customer?.name ?? <span className="cell-sub">بدون زبون</span> },
    { key: "lines", label: "الأصناف", render: (r) => <>{lines(r)}<span className="cell-sub">السبب: {r.reason}</span></> },
    { key: "total", label: "القيمة", numeric: true, render: (r) => <MoneyText value={r.total_amount} style={{ fontWeight: 700 }} /> },
    { key: "act", label: "", render: (r) => printButton(saleReturnDoc(r)) },
  ];
  const purchaseColumns = [
    { key: "no", label: "الفاتورة", render: (r) => <Link to={`/purchases/${r.purchase_invoice_id}`} className="m">#{r.purchase_invoice_id}</Link> },
    { key: "at", label: "التاريخ", render: (r) => <span className="m">{dateTime(r.created_at)}</span> },
    { key: "who", label: "المورد", render: (r) => <Link className="row-link" to={`/suppliers/${r.supplier.id}`}>{r.supplier.name}</Link> },
    { key: "lines", label: "الأصناف", render: (r) => <>{lines(r)}<span className="cell-sub">السبب: {r.reason}</span></> },
    { key: "total", label: "القيمة", numeric: true, render: (r) => <MoneyText value={r.total_amount} style={{ fontWeight: 700 }} /> },
    { key: "act", label: "", render: (r) => printButton(purchaseReturnDoc(r)) },
  ];

  return (
    <>
      <PageHeader title="المرتجعات" sub={list.data?.meta ? `${list.data.meta.total} مرتجع في هذه التصفية` : " "} />
      <div className="card panel">
        <div className="toolbar">
          {manager ? (
            <div className="field">
              <span className="field-label">النوع</span>
              <Segments
                label="نوع المرتجع"
                value={tab}
                options={[
                  ["sales", "من الزبائن"],
                  ["purchases", "للموردين"],
                ]}
                onChange={(next) => {
                  setTab(next);
                  setPageNo(1);
                }}
              />
            </div>
          ) : null}
          <Field id="rf-from" label="من">
            <input id="rf-from" type="date" className="fld date-fld" value={filters.from} onChange={(e) => set({ from: e.target.value })} />
          </Field>
          <Field id="rf-to" label="إلى">
            <input id="rf-to" type="date" className="fld date-fld" value={filters.to} onChange={(e) => set({ to: e.target.value })} />
          </Field>
        </div>
      </div>
      <DataTable
        query={list}
        rows={list.data?.data ?? []}
        columns={tab === "sales" ? saleColumns : purchaseColumns}
        caption="قائمة المرتجعات"
        minWidth={820}
        empty={
          <EmptyState
            icon="undo"
            title="لا مرتجعات في هذه التصفية"
            text={tab === "sales" ? "المرتجع من الزبون يُسجَّل من صفحة فاتورة المبيعات." : "المرتجع للمورد يُسجَّل من صفحة فاتورة المشتريات."}
          />
        }
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      {sheet}
    </>
  );
}
