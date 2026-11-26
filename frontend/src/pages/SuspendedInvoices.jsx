import { useState } from "react";
import Icon from "../components/Icon";
import { ConfirmSummary, DataTable, Dialog, EmptyState, ErrorBanner, PageHeader, Segments, StatusBadge } from "../components/ui";
import { canManage } from "../lib/domain";
import { centsOf, dateTime, moneyOf, shekel } from "../lib/format";
import { session } from "../services/apiClient";
import { useConfirmSuspendedInvoice, useCloseSuspendedInvoice, useRemoveHeldLine, useSuspendedInvoices } from "../services/backoffice";

const STATUS_LABEL = {
  pending_transfer: ["قيد انتظار التحويل", "partial"],
  completed: ["مكتملة", "active"],
  rejected: ["مرفوضة", "voided"],
  cancelled: ["ملغاة", "voided"],
};

export default function SuspendedInvoices() {
  const [status, setStatus] = useState("pending_transfer");
  const [removing, setRemoving] = useState(null);
  const list = useSuspendedInvoices(status);
  const confirm = useConfirmSuspendedInvoice();
  const close = useCloseSuspendedInvoice();
  const me = session.user();
  // Lines come off a held invoice before it is confirmed: owners, managers, or whoever held it.
  const mayEdit = (x) => x.status === "pending_transfer" && (canManage(me) || x.cashier_id === me?.id);

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
          {
            key: "items",
            label: "الأصناف",
            render: (x) => (
              <ul className="held-lines">
                {(x.items ?? []).map((item) => (
                  <li key={item.id}>
                    <span>
                      <span className="m">{item.quantity}</span> × {item.item_name}
                    </span>
                    {mayEdit(x) && x.items.length > 1 ? (
                      <button
                        type="button"
                        className="icon-btn danger"
                        aria-label={`حذف ${item.item_name} من الفاتورة #${x.reference}`}
                        title="حذف البند"
                        onClick={() => setRemoving({ invoice: x, item })}
                      >
                        <Icon name="close" size={16} />
                      </button>
                    ) : null}
                  </li>
                ))}
              </ul>
            ),
          },
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
        minWidth={1100}
        empty={<EmptyState icon="sales" title="لا توجد فواتير بهذه الحالة" text="الفواتير المعلقة تظهر هنا قبل اكتمال البيع." />}
      />
      {removing ? <RemoveLineDialog {...removing} onClose={() => setRemoving(null)} /> : null}
    </>
  );
}

/** Takes one line off a held invoice; the server recomputes the total and frees the reserved stock. */
function RemoveLineDialog({ invoice, item, onClose }) {
  const remove = useRemoveHeldLine();
  const after = moneyOf(centsOf(invoice.total_amount) - centsOf(item.total));
  return (
    <Dialog title={`حذف «${item.item_name}» من الفاتورة #${invoice.reference}؟`} role="alertdialog" tone="warning" onClose={onClose}>
      <ConfirmSummary
        rows={[
          ["الإجمالي الآن", shekel(invoice.total_amount)],
          ["البند", `${item.quantity} × ${item.item_name} = ${shekel(item.total)}`],
        ]}
        total={["الإجمالي بعد الحذف", shekel(after)]}
      />
      <p className="field-hint">تتحرر الكمية المحجوزة لهذا البند وتعود متاحة للبيع. تبقى الفاتورة معلقة بباقي البنود.</p>
      <ErrorBanner error={remove.error} />
      <div className="dlg-actions">
        <button type="button" className="btn btn-dd" disabled={remove.isPending} onClick={() => remove.mutate({ id: invoice.id, itemId: item.id }, { onSuccess: onClose })}>
          {remove.isPending ? "جارٍ الحذف…" : "حذف البند"}
        </button>
        <button type="button" className="btn btn-g" onClick={onClose}>
          رجوع
        </button>
      </div>
    </Dialog>
  );
}
