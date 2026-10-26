import { useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { ErrorBanner, ErrorState, Field, PageHeader } from "../components/ui";
import { roleOf } from "../lib/domain";
import { dateOnly, latinDigits } from "../lib/format";
import { ApiError, session } from "../services/apiClient";
import { useChangePassword, useMyStore, useSaveStore } from "../services/backoffice";
import { useSubscription } from "../services/dashboard";

/** Server field messages as { field: first message }; empty when the error is not about fields. */
const fieldErrors = (error) =>
  error instanceof ApiError ? Object.fromEntries(Object.keys(error.errors).map((key) => [key, error.fieldError(key)]).filter(([, m]) => m)) : {};

/**
 * Settings, as on the mobile «More» tab: the store details printed on every receipt (owner only),
 * where the subscription stands, and a new password for the signed-in account.
 */
export default function Settings() {
  const me = session.user() ?? {};
  const owner = roleOf(me) === "owner";

  return (
    <>
      <PageHeader title="الإعدادات" sub="بيانات المحل والاشتراك وحسابك" />
      <div className="split">
        {owner ? <StoreSection /> : null}
        <div className="form-stack" style={{ flex: "1 1 380px", minWidth: 0 }}>
          <SubscriptionSection user={me} />
          <PasswordSection />
          {owner ? (
            <Link className="card panel settings-link" to="/staff">
              <Icon name="staff" size={22} strokeWidth={1.8} />
              <span>
                <b>الموظفون</b>
                <small>دعوة موظف، تغيير الدور، الإيقاف</small>
              </span>
              <Icon name="arrow" size={18} />
            </Link>
          ) : null}
        </div>
      </div>
    </>
  );
}

function StoreSection() {
  const store = useMyStore();
  if (store.isPending) return <div className="card sk" style={{ flex: "1 1 420px", height: 380 }} />;
  if (store.isError) return <ErrorState error={store.error} title="تعذّر تحميل بيانات المحل" onRetry={store.refetch} />;
  return <StoreForm key={store.data.id} store={store.data} />;
}

function StoreForm({ store }) {
  const [form, setForm] = useState({ name: store.name ?? "", phone: store.phone ?? "", address: store.address ?? "", area: store.area ?? "" });
  const [nameMissing, setNameMissing] = useState(false);
  const save = useSaveStore();
  const errors = fieldErrors(save.error);
  const set = (key, clean = (v) => v) => (e) => {
    setForm({ ...form, [key]: clean(e.target.value) });
    save.reset();
  };

  const submit = (e) => {
    e.preventDefault();
    const name = form.name.trim();
    setNameMissing(!name);
    if (!name) return;
    // An empty phone, address or area clears it.
    const blankToNull = (v) => v.trim() || null;
    save.mutate({ name, phone: blankToNull(form.phone), address: blankToNull(form.address), area: blankToNull(form.area) });
  };

  return (
    <form className="card panel form-stack" style={{ flex: "1 1 420px" }} onSubmit={submit} noValidate>
      <div className="panel-head">
        <h2>بيانات المحل</h2>
      </div>
      <p className="field-hint" style={{ margin: 0 }}>
        تظهر هذه البيانات أعلى كل إيصال.
      </p>
      <Field id="st-name" label="اسم المحل" required error={nameMissing ? "يرجى إدخال اسم المتجر." : errors.name}>
        <input id="st-name" className="fld" value={form.name} onChange={set("name")} maxLength={255} autoComplete="organization" />
      </Field>
      <Field id="st-phone" label="هاتف المحل" optional error={errors.phone} hint="مثل 0599123456">
        <input id="st-phone" className="fld ltr m" inputMode="tel" value={form.phone} onChange={set("phone", latinDigits)} autoComplete="tel" />
      </Field>
      <Field id="st-address" label="العنوان" optional error={errors.address}>
        <input id="st-address" className="fld" value={form.address} onChange={set("address")} maxLength={255} />
      </Field>
      <Field id="st-area" label="المنطقة أو المدينة" optional error={errors.area}>
        <input id="st-area" className="fld" value={form.area} onChange={set("area")} maxLength={100} />
      </Field>
      <ErrorBanner error={save.error && Object.keys(errors).length === 0 ? save.error : null} />
      {save.isSuccess ? (
        <p role="status" className="banner tone-success">
          <Icon name="ok" size={20} />
          <span>حُفظت بيانات المحل.</span>
        </p>
      ) : null}
      <div>
        <button type="submit" className="btn btn-p" disabled={save.isPending}>
          {save.isPending ? "جارٍ الحفظ…" : "حفظ التغييرات"}
        </button>
      </div>
    </form>
  );
}

function SubscriptionSection({ user }) {
  const sub = useSubscription();
  const s = sub.data;
  const status = !s
    ? null
    : s.state === "trial" && s.trial_ends_at
      ? `تجربة مجانية حتى ${dateOnly(s.trial_ends_at)}`
      : s.state === "active" && s.subscription_expires_at
        ? `مفعّل حتى ${dateOnly(s.subscription_expires_at)}`
        : "مفعّل";
  const number = s?.support_whatsapp;
  const text = `مرحباً، بخصوص اشتراك متجر «${user.store?.name ?? ""}» على حسبة.`;

  return (
    <section className="card panel">
      <div className="panel-head">
        <h2>الاشتراك</h2>
      </div>
      {sub.isPending ? (
        <div className="sk" style={{ height: 22, borderRadius: 6 }} />
      ) : sub.isError ? (
        <ErrorBanner error={sub.error} />
      ) : (
        <p style={{ margin: 0, fontWeight: 600 }}>{status}</p>
      )}
      {number ? (
        <div>
          <a className="btn btn-s btn-sm" href={`https://wa.me/${number}?text=${encodeURIComponent(text)}`} target="_blank" rel="noopener noreferrer">
            تواصل مع إدارة حسبة عبر واتساب
          </a>
        </div>
      ) : null}
    </section>
  );
}

const EMPTY_PASSWORDS = { current_password: "", password: "", password_confirmation: "" };

function PasswordSection() {
  const [form, setForm] = useState(EMPTY_PASSWORDS);
  const [local, setLocal] = useState({});
  const change = useChangePassword();
  const errors = { ...fieldErrors(change.error), ...local };
  const set = (key) => (e) => {
    setForm({ ...form, [key]: e.target.value });
    if (change.isSuccess) change.reset();
  };

  const submit = (e) => {
    e.preventDefault();
    const found = {};
    if (!form.current_password) found.current_password = "اكتب كلمة المرور الحالية.";
    if (form.password.length < 8) found.password = "كلمة المرور 8 أحرف على الأقل.";
    else if (form.password !== form.password_confirmation) found.password_confirmation = "تأكيد كلمة المرور لا يطابقها.";
    setLocal(found);
    change.reset();
    if (Object.keys(found).length > 0) return;
    change.mutate(form, { onSuccess: () => setForm(EMPTY_PASSWORDS) });
  };

  return (
    <form className="card panel form-stack" onSubmit={submit} noValidate>
      <div className="panel-head">
        <h2>تغيير كلمة المرور</h2>
      </div>
      <Field id="pw-current" label="كلمة المرور الحالية" required error={errors.current_password}>
        <input id="pw-current" type="password" className="fld ltr" value={form.current_password} onChange={set("current_password")} autoComplete="current-password" />
      </Field>
      <Field id="pw-new" label="كلمة المرور الجديدة" required error={errors.password} hint="8 أحرف على الأقل. سيُسجَّل خروجك من الأجهزة الأخرى، ويبقى هذا المتصفح داخلاً.">
        <input id="pw-new" type="password" className="fld ltr" value={form.password} onChange={set("password")} autoComplete="new-password" />
      </Field>
      <Field id="pw-confirm" label="تأكيد كلمة المرور الجديدة" required error={errors.password_confirmation}>
        <input id="pw-confirm" type="password" className="fld ltr" value={form.password_confirmation} onChange={set("password_confirmation")} autoComplete="new-password" />
      </Field>
      <ErrorBanner error={change.error && Object.keys(fieldErrors(change.error)).length === 0 ? change.error : null} />
      {change.isSuccess ? (
        <p role="status" className="banner tone-success">
          <Icon name="ok" size={20} />
          <span>تم تغيير كلمة المرور، وسُجّل الخروج من الأجهزة الأخرى.</span>
        </p>
      ) : null}
      <div>
        <button type="submit" className="btn btn-p" disabled={change.isPending}>
          {change.isPending ? "جارٍ التغيير…" : "تغيير كلمة المرور"}
        </button>
      </div>
    </form>
  );
}
