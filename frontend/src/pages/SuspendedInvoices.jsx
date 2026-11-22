import { DataTable, EmptyState, ErrorBanner, PageHeader, Segments, StatusBadge } from "../components/ui";
import { useConfirmSuspendedInvoice, useCloseSuspendedInvoice, useSuspendedInvoices } from "../services/backoffice";
import { dateTime } from "../lib/format";
import { useState } from "react";

const STATUS_LABEL = {
  pending_transfer: ["قيد انتظار التحويل", "partial"],
  completed: ["مكتملة", "active"],
  rejected: ["مرفوضة", "voided"],
  cancelled: ["ملغاة", "voided"],
};

export default function SuspendedInvoices() {
  const [status, setStatus] = useState("pending_transfer");
  const list = useSuspendedInvoices(status);
  const confirm = useConfirmSuspendedInvoice();
  const close = useCloseSuspendedInvoice();

  return (
    <>
      <PageHeader title="الفواتير المعلقة" sub="الفواتير المعلقة لا تُحسب كمبيعات أو إيرادات نهائية" />
      <div className="card panel toolbar">
        <Segments
          label="حالة الفاتورة"
          value={status}
          options={[["pending_transfer", "قيد الانتظار"], ["completed", "مكتملة"], ["rejected", "مرفوضة"], ["cancelled", "ملغاة"]]}
          onChange={setStatus}
        />
      </div>
      <ErrorBanner error={confirm.error || close.error} />
      <DataTable
        query={list}
        rows={list.data ?? []}
        columns={[
          { key: "reference", label: "المرجع", render: (x) => <span className="m">#{x.reference}</span> },
          { key: "customer", label: "الزبون", render: (x) => x.customer?.name ?? "بدون زبون" },
          { key: "cashier", label: "الكاشير", render: (x) => x.cashier?.name ?? "—" },
          { key: "total", label: "الإجمالي", numeric: true, render: (x) => <span className="m">{x.total_amount}</span> },
          { key: "account", label: "حساب الاستقبال", render: (x) => <span>{x.account_snapshot_name} · <span className="m" dir="ltr">{x.account_snapshot_identifier}</span></span> },
          { key: "created", label: "الإنشاء", render: (x) => <span className="m">{dateTime(x.created_at)}</span> },
          { key: "status", label: "الحالة", render: (x) => {
            const [label, badge] = STATUS_LABEL[x.status] ?? [x.status, "unpaid"];
            return <StatusBadge status={badge} label={label} />;
          } },
          ...(status === "pending_transfer" ? [{ key: "actions", label: "الإجراء", render: (x) => (
            <div style={{ display: "flex", gap: 8 }}>
              <button type="button" className="btn btn-p btn-sm" disabled={confirm.isPending} onClick={() => confirm.mutate(x.id)}>تأكيد الاستلام</button>
              <button type="button" className="btn btn-danger btn-sm" disabled={close.isPending} onClick={() => close.mutate({ id: x.id, body: { status: "rejected", reason: "رفض التحويل" } })}>رفض</button>
            </div>
          ) }] : []),
        ]}
        caption="الفواتير المعلقة"
        minWidth={1000}
        empty={<EmptyState icon="sales" title="لا توجد فواتير بهذه الحالة" text="الفواتير المعلقة تظهر هنا قبل اكتمال البيع." />}
      />
    </>
  );
}
