import { useState } from "react";
import Icon from "../components/Icon";
import { DataTable, EmptyState, ErrorBanner, Field, PageHeader, StatusBadge } from "../components/ui";
import { useArchiveReceivingAccount, useReceivingAccounts, useSaveReceivingAccount } from "../services/backoffice";
import { roleOf } from "../lib/domain";
import { ApiError, session } from "../services/apiClient";

const PROVIDERS = [
  ["palpay", "بال بي"],
  ["jawwal_pay", "جوال بي"],
  ["bank_of_palestine", "بنك فلسطين"],
];

const EMPTY_FORM = { provider: "", account_name: "", account_identifier: "", active: true };

const fieldErrors = (error) =>
  error instanceof ApiError ? Object.fromEntries(Object.keys(error.errors).map((key) => [key, error.fieldError(key)]).filter(([, m]) => m)) : {};

export default function ReceivingAccounts() {
  const me = session.user() ?? {};
  const canManage = ["owner", "manager"].includes(roleOf(me));
  const [includeInactive, setIncludeInactive] = useState(false);
  const [provider, setProvider] = useState("");
  const accounts = useReceivingAccounts(provider || null, includeInactive);
  const save = useSaveReceivingAccount();
  const archive = useArchiveReceivingAccount();
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState(EMPTY_FORM);
  const [local, setLocal] = useState({});

  const serverFields = fieldErrors(save.error);
  const errors = { ...serverFields, ...local };

  const openNew = () => {
    setEditing(null);
    setLocal({});
    setForm({ ...EMPTY_FORM, provider: provider || "" });
  };

  const setField = (key, value) => {
    setForm({ ...form, [key]: value });
    if (local[key]) setLocal({ ...local, [key]: undefined });
    if (save.isError || save.isSuccess) save.reset();
  };

  const submit = (event) => {
    event.preventDefault();
    const found = {};
    if (!PROVIDERS.some(([value]) => value === form.provider)) found.provider = "اختر مزود الدفع.";
    if (!form.account_name.trim()) found.account_name = "اكتب اسم صاحب الحساب.";
    if (!form.account_identifier.trim()) found.account_identifier = "اكتب رقم الهاتف أو رقم الحساب.";
    setLocal(found);
    save.reset();
    if (Object.keys(found).length > 0) return;

    save.mutate(
      {
        id: editing?.id,
        body: {
          provider: form.provider,
          account_name: form.account_name.trim(),
          account_identifier: form.account_identifier.trim(),
          active: !!form.active,
        },
      },
      {
        onSuccess: () => {
          setEditing(null);
          setLocal({});
          setForm({ ...EMPTY_FORM, provider: provider || "" });
        },
      },
    );
  };

  const rows = (accounts.data ?? []).map((a) => ({
    ...a,
    __class: !a.active ? "voided" : undefined,
  }));

  const formBannerError = save.error && Object.keys(serverFields).length === 0 ? save.error : archive.error;

  return (
    <>
      <PageHeader title="حسابات استقبال الحوالات" sub="حسابات التحويل الخاصة بهذا المتجر فقط" />
      {canManage ? (
        <form className="card panel form-stack" onSubmit={submit} noValidate>
          <div className="panel-head"><h2>{editing ? "تعديل حساب" : "إضافة حساب"}</h2></div>
          <Field id="ra-provider" label="مزود الدفع" required error={errors.provider}>
            <select id="ra-provider" className="fld" value={form.provider} onChange={(e) => setField("provider", e.target.value)}>
              <option value="">اختر مزود الدفع</option>
              {PROVIDERS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </Field>
          <Field id="ra-name" label="اسم صاحب الحساب" required error={errors.account_name}>
            <input id="ra-name" className="fld" value={form.account_name} onChange={(e) => setField("account_name", e.target.value)} />
          </Field>
          <Field id="ra-id" label="رقم الهاتف أو رقم الحساب" required error={errors.account_identifier}>
            <input id="ra-id" className="fld" dir="ltr" value={form.account_identifier} onChange={(e) => setField("account_identifier", e.target.value)} />
          </Field>
          <label style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <input type="checkbox" checked={form.active} onChange={(e) => setField("active", e.target.checked)} />
            الحساب نشط
          </label>
          <ErrorBanner error={formBannerError} />
          {save.isSuccess ? (
            <p role="status" className="banner tone-success">
              <Icon name="ok" size={20} />
              <span>تم حفظ حساب الاستقبال.</span>
            </p>
          ) : null}
          <div style={{ display: "flex", gap: 8 }}>
            <button className="btn btn-p" type="submit" disabled={save.isPending}>{save.isPending ? "جارٍ الحفظ…" : "حفظ الحساب"}</button>
            {editing ? (
              <button className="btn btn-s" type="button" onClick={() => { save.reset(); openNew(); }}>إلغاء التعديل</button>
            ) : null}
          </div>
        </form>
      ) : null}

      <div className="card panel">
        <div className="toolbar">
          <Field id="ra-filter" label="المزوّد">
            <select id="ra-filter" className="fld" value={provider} onChange={(e) => setProvider(e.target.value)}>
              <option value="">الكل</option>
              {PROVIDERS.map(([value, label]) => <option key={value} value={value}>{label}</option>)}
            </select>
          </Field>
          {canManage ? (
            <label style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 22 }}>
              <input type="checkbox" checked={includeInactive} onChange={(e) => setIncludeInactive(e.target.checked)} />
              عرض الحسابات غير النشطة
            </label>
          ) : null}
        </div>
      </div>
      <DataTable
        query={accounts}
        rows={rows}
        columns={[
          { key: "provider", label: "المزوّد", render: (a) => PROVIDERS.find(([value]) => value === a.provider)?.[1] ?? a.provider },
          { key: "name", label: "صاحب الحساب", render: (a) => a.account_name },
          { key: "identifier", label: "المعرّف", render: (a) => <span dir="ltr" className="m">{a.account_identifier}</span> },
          { key: "status", label: "الحالة", render: (a) => <StatusBadge status={a.active ? "active" : "voided"} label={a.active ? "نشط" : "مؤرشف"} /> },
          ...(canManage ? [{ key: "actions", label: "الإجراء", render: (a) => (
            <div style={{ display: "flex", gap: 8 }}>
              <button type="button" className="btn btn-sm" onClick={() => { setEditing(a); setLocal({}); save.reset(); setForm({ provider: a.provider, account_name: a.account_name, account_identifier: a.account_identifier, active: !!a.active }); }}>تعديل</button>
              {a.deleted_at == null ? <button type="button" className="btn btn-danger btn-sm" disabled={archive.isPending} onClick={() => archive.mutate(a.id)}>أرشفة</button> : null}
            </div>
          ) }] : []),
        ]}
        caption="حسابات استقبال الحوالات"
        empty={<EmptyState icon="payments" title="لا توجد حسابات" text="أضف حساب استقبال نشطًا للمزوّد قبل تعليق فاتورة تحويل." />}
      />
    </>
  );
}
