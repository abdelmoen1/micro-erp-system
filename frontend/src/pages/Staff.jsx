import { useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { DataTable, Dialog, EmptyState, ErrorBanner, PageHeader, StatusBadge } from "../components/ui";
import { session } from "../services/apiClient";
import { useInvite, useStaff, useStaffAction } from "../services/backoffice";
import { roleOf } from "../lib/domain";
import { dateTime } from "../lib/format";

const ROLE = { owner: "مالك", manager: "مدير", employee: "موظف" };

/** SCR-W-15 · staff and roles: invite, change role, deactivate (US-0204). Owner only. */
export default function Staff() {
  const me = session.user();
  const staff = useStaff();
  const action = useStaffAction();
  const [inviting, setInviting] = useState(false);
  const [deactivating, setDeactivating] = useState(null);

  if (roleOf(me) !== "owner") {
    return (
      <div role="alert" className="card state-card">
        <Icon name="lock" size={40} color="#4a5565" strokeWidth={1.8} />
        <b className="state-title">هذه الصفحة للمالك فقط</b>
        <span className="state-text">إدارة الموظفين وأدوارهم من صلاحية مالك المتجر.</span>
        <Link className="btn btn-s btn-sm" to="/dashboard">
          العودة إلى الرئيسية
        </Link>
      </div>
    );
  }

  const rows = [{ ...me, role: "owner", status: "active", __self: true }, ...(staff.data ?? [])].map((u) => ({ ...u, __class: u.status === "inactive" ? "voided" : undefined }));

  return (
    <>
      <PageHeader title="الموظفون" sub={staff.data ? `${staff.data.filter((u) => u.status !== "inactive").length} موظفين نشطين` : " "}>
        <button type="button" className="btn btn-p btn-sm" onClick={() => setInviting(true)}>
          دعوة موظف
        </button>
      </PageHeader>
      <ErrorBanner error={action.error} />
      <DataTable
        query={staff}
        rows={rows}
        minWidth={640}
        caption="الموظفون"
        columns={[
          {
            key: "name",
            label: "الاسم",
            render: (u) => (
              <>
                <b style={{ fontWeight: 600 }}>{u.name}</b>
                <span className="cell-sub m" style={{ textAlign: "right" }}>
                  {u.phone}
                </span>
              </>
            ),
          },
          {
            key: "role",
            label: "الدور",
            render: (u) =>
              u.__self || u.status === "inactive" ? (
                ROLE[u.role] ?? u.role
              ) : (
                <select
                  className="fld"
                  style={{ width: 140, minHeight: 38 }}
                  aria-label={`دور ${u.name}`}
                  value={u.role}
                  disabled={action.isPending}
                  onChange={(e) => action.mutate({ action: "role", id: u.id, role: e.target.value })}
                >
                  <option value="manager">مدير</option>
                  <option value="employee">موظف</option>
                </select>
              ),
          },
          { key: "status", label: "الحالة", render: (u) => <StatusBadge status={u.status === "inactive" ? "inactive" : "active"} label={u.status === "inactive" ? "موقوف" : "نشط"} /> },
          {
            key: "x",
            label: "إجراء",
            numeric: true,
            render: (u) =>
              !u.__self && u.status !== "inactive" ? (
                <button type="button" className="btn btn-t danger" onClick={() => setDeactivating(u)}>
                  إيقاف
                </button>
              ) : null,
          },
        ]}
        empty={<EmptyState icon="staff" title="لا موظفين بعد" />}
      />
      <p className="field-hint">المدير: كل شيء عدا الموظفين وإعدادات المتجر. الموظف: البيع والزبائن وتسجيل الدفعات، بلا مرتجع أو إلغاء أو عكس دفعة أو تجاوز حد الدين.</p>

      {inviting ? <InviteDialog onClose={() => setInviting(false)} /> : null}
      {deactivating ? (
        <Dialog title={`إيقاف ${deactivating.name}؟`} role="alertdialog" tone="warning" icon="ban" onClose={() => setDeactivating(null)}>
          <p>يُسجَّل خروجه من كل الأجهزة فوراً ولن يستطيع الدخول. فواتيره ودفعاته تبقى باسمه في السجل.</p>
          <div className="dlg-actions">
            <button
              type="button"
              className="btn btn-dd"
              disabled={action.isPending}
              onClick={() => action.mutate({ action: "deactivate", id: deactivating.id }, { onSuccess: () => setDeactivating(null) })}
            >
              إيقاف الموظف
            </button>
            <button type="button" className="btn btn-g" onClick={() => setDeactivating(null)}>
              رجوع
            </button>
          </div>
        </Dialog>
      ) : null}
    </>
  );
}

function InviteDialog({ onClose }) {
  const [role, setRole] = useState("employee");
  const [hours, setHours] = useState(24);
  const [copied, setCopied] = useState(false);
  const invite = useInvite();
  const link = invite.data ? `${window.location.origin}/invite?invite=${encodeURIComponent(invite.data.token)}` : "";

  const submit = (e) => {
    e.preventDefault();
    invite.mutate({ role, expires_in_hours: hours });
  };

  return (
    <Dialog title="دعوة موظف" onClose={onClose}>
      {invite.data ? (
        <div className="form-stack">
          <p role="status" className="banner tone-success">
            الدعوة جاهزة. أرسل الرابط إلى الموظف؛ يظهر مرة واحدة فقط.
          </p>
          <div style={{ display: "flex", gap: 8 }}>
            <input className="fld ltr m" readOnly value={link} aria-label="رابط الدعوة" />
            <button
              type="button"
              className="btn btn-s btn-sm"
              onClick={() => navigator.clipboard?.writeText(link).then(() => setCopied(true))}
            >
              {copied ? "نُسخ" : "نسخ"}
            </button>
          </div>
          <p className="field-hint">
            ينتهي في <span className="m">{dateTime(invite.data.expires_at)}</span> · {ROLE[invite.data.role] ?? invite.data.role}
          </p>
          <button type="button" className="btn btn-p" onClick={onClose}>
            تم
          </button>
        </div>
      ) : (
        <form className="form-stack" onSubmit={submit} noValidate>
          <div className="field">
            <span className="field-label" id="iv-role">
              الدور
            </span>
            <div className="chips" role="group" aria-labelledby="iv-role">
              {[
                ["manager", "مدير"],
                ["employee", "موظف"],
              ].map(([key, label]) => (
                <button key={key} type="button" className="chip" aria-pressed={role === key} onClick={() => setRole(key)}>
                  {label}
                </button>
              ))}
            </div>
          </div>
          <div className="field">
            <span className="field-label" id="iv-hours">
              صلاحية الرابط
            </span>
            <div className="chips" role="group" aria-labelledby="iv-hours">
              {[
                [24, "24 ساعة"],
                [72, "3 أيام"],
                [168, "7 أيام"],
              ].map(([value, label]) => (
                <button key={value} type="button" className="chip" aria-pressed={hours === value} onClick={() => setHours(value)}>
                  {label}
                </button>
              ))}
            </div>
          </div>
          <ErrorBanner error={invite.error} />
          <div className="dlg-actions">
            <button type="submit" className="btn btn-p" disabled={invite.isPending}>
              {invite.isPending ? "جارٍ الإنشاء…" : "إنشاء رابط الدعوة"}
            </button>
            <button type="button" className="btn btn-g" onClick={onClose}>
              إلغاء
            </button>
          </div>
        </form>
      )}
    </Dialog>
  );
}
