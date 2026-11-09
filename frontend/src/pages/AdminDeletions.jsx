import { useState } from "react";
import { EmptyState, ErrorBanner, ErrorState, PageHeader, Segments } from "../components/ui";
import { dateTime } from "../lib/format";
import { useAdminDeletions, useResolveDeletion } from "../services/subscriptions";

const LABEL = { pending_review: "قيد المراجعة", scheduled: "مجدول", completed: "منفّذ", cancelled: "ملغى", rejected: "مرفوض" };

/**
 * Platform admin: account deletion requests. Requests made without a password («pending review»)
 * are approved only after verifying, outside the system, that the requester owns the number.
 */
export default function AdminDeletions() {
  const [status, setStatus] = useState("pending_review");
  const rows = useAdminDeletions(status ? { status } : {});
  const resolve = useResolveDeletion();

  return (
    <>
      <PageHeader title="طلبات حذف الحسابات" sub="الطلبات العامة بلا كلمة مرور تحتاج تحققاً يدوياً من صاحب الرقم" />
      <Segments label="الحالة" value={status} options={[["pending_review", "قيد المراجعة"], ["scheduled", "مجدولة"], ["completed", "منفّذة"], ["", "الكل"]]} onChange={setStatus} />
      {resolve.isError ? <ErrorBanner error={resolve.error} /> : null}
      {rows.isError ? (
        <ErrorState error={rows.error} onRetry={() => rows.refetch()} />
      ) : rows.data?.length === 0 ? (
        <EmptyState title="لا توجد طلبات" />
      ) : (
        <div className="card table-card" style={{ marginTop: 12, overflowX: "auto" }}>
          <table className="tbl">
            <caption className="sr-only">طلبات الحذف</caption>
            <thead>
              <tr>
                <th>التاريخ</th>
                <th>النوع</th>
                <th>الرقم</th>
                <th>المتجر</th>
                <th>المصدر</th>
                <th>الحالة</th>
                <th>السبب</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {(rows.data ?? []).map((r) => (
                <tr key={r.id}>
                  <td>{dateTime(r.requested_at)}</td>
                  <td>{r.type === "store" ? "متجر (صاحب)" : "موظف"}</td>
                  <td className="m ltr-inline">{r.phone_masked}</td>
                  <td>{r.store_name ?? "—"}</td>
                  <td>{r.source === "public" ? "صفحة الحذف" : r.source === "app" ? "التطبيق" : "الموقع"}</td>
                  <td>
                    {LABEL[r.status] ?? r.status}
                    {r.scheduled_for ? ` (${dateTime(r.scheduled_for)})` : ""}
                  </td>
                  <td>{r.reason ?? ""}</td>
                  <td>
                    {r.status === "pending_review" ? (
                      <div className="head-actions">
                        <button type="button" className="btn btn-dd btn-sm" disabled={resolve.isPending} onClick={() => resolve.mutate({ id: r.id, action: "approve" })}>
                          تحققت: نفّذ
                        </button>
                        <button type="button" className="btn btn-g btn-sm" disabled={resolve.isPending} onClick={() => resolve.mutate({ id: r.id, action: "reject" })}>
                          رفض
                        </button>
                      </div>
                    ) : null}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}
