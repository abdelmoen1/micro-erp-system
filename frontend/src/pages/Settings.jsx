import { useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import OtpResend from "../components/OtpResend";
import { ErrorBanner, ErrorState, Field, PageHeader, StatusBadge } from "../components/ui";
import { roleOf } from "../lib/domain";
import { dateOnly, dateTime, latinDigits } from "../lib/format";
import { maskPhone, normalizePhone, PHONE_HINT, otpSendError } from "../lib/phone";
import { TICKET_STATUS, TICKET_TYPES, ticketTypeLabel } from "../lib/support";
import { changePhone, sendOtp } from "../services/api";
import { ApiError, session } from "../services/apiClient";
import { useChangePassword, useMyStore, useSaveStore, useSendTicket, useSupportTickets } from "../services/backoffice";
import { useSubscription } from "../services/dashboard";
import { useAuthOptions } from "../services/useAuth";

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
          <PhoneSection user={me} />
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
      <SupportSection />
    </>
  );
}

const EMPTY_TICKET = { type: "", subject: "", details: "" };

/** Technical support: a complaint (type, subject, details) to the Hisbah team, and the replies. */
function SupportSection() {
  const [form, setForm] = useState(EMPTY_TICKET);
  const [local, setLocal] = useState({});
  const send = useSendTicket();
  const tickets = useSupportTickets();
  const errors = { ...fieldErrors(send.error), ...local };
  const set = (key) => (e) => {
    setForm({ ...form, [key]: e.target.value });
    if (send.isSuccess) send.reset();
  };

  const submit = (e) => {
    e.preventDefault();
    const found = {};
    if (!form.type) found.type = "اختر نوع الدعم.";
    if (!form.subject.trim()) found.subject = "اكتب موضوع المشكلة.";
    if (!form.details.trim()) found.details = "اكتب تفاصيل المشكلة.";
    setLocal(found);
    send.reset();
    if (Object.keys(found).length > 0) return;
    send.mutate({ type: form.type, subject: form.subject.trim(), details: form.details.trim() }, { onSuccess: () => setForm(EMPTY_TICKET) });
  };

  return (
    <div className="split" style={{ marginTop: 16 }}>
      <form className="card panel form-stack" style={{ flex: "1 1 420px" }} onSubmit={submit} noValidate>
        <div className="panel-head">
          <h2>الدعم الفني</h2>
        </div>
        <div className="field">
          <span className="field-label req" id="tk-type">
            نوع الدعم
          </span>
          <div className="chips" role="group" aria-labelledby="tk-type">
            {TICKET_TYPES.map(([key, label]) => (
              <button
                key={key}
                type="button"
                className="chip"
                aria-pressed={form.type === key}
                onClick={() => {
                  setForm({ ...form, type: key });
                  setLocal({ ...local, type: undefined });
                }}
              >
                {label}
              </button>
            ))}
          </div>
          {errors.type ? (
            <span className="field-error">
              <Icon name="alert" size={16} />
              {errors.type}
            </span>
          ) : null}
        </div>
        <Field id="tk-subject" label="موضوع المشكلة" required error={errors.subject}>
          <input id="tk-subject" className="fld" value={form.subject} onChange={set("subject")} maxLength={150} placeholder="بكلمات قليلة، مثل: الطابعة لا تطبع الإيصال" />
        </Field>
        <Field id="tk-details" label="تفاصيل المشكلة" required error={errors.details}>
          <textarea
            id="tk-details"
            className="fld fld-area"
            rows={5}
            value={form.details}
            onChange={set("details")}
            maxLength={3000}
            placeholder="ماذا حدث، وأين، ومتى؟ كلما كتبت أكثر ساعدناك أسرع."
          />
        </Field>
        <ErrorBanner error={send.error && Object.keys(fieldErrors(send.error)).length === 0 ? send.error : null} />
        {send.isSuccess ? (
          <p role="status" className="banner tone-success">
            <Icon name="ok" size={20} />
            <span>وصلت شكواك إلى فريق حسبة، وسنرد عليك هنا.</span>
          </p>
        ) : null}
        <div>
          <button type="submit" className="btn btn-p" disabled={send.isPending}>
            {send.isPending ? "جارٍ الإرسال…" : "إرسال الشكوى"}
          </button>
        </div>
      </form>

      <section className="card panel" style={{ flex: "1 1 380px" }} aria-labelledby="tk-list">
        <div className="panel-head">
          <h2 id="tk-list">شكاواي</h2>
        </div>
        {tickets.isPending ? (
          <div className="sk" style={{ height: 120, borderRadius: 10 }} />
        ) : tickets.isError ? (
          <ErrorBanner error={tickets.error} />
        ) : tickets.data.length === 0 ? (
          <p className="field-hint" style={{ margin: 0 }}>
            لم ترسل أي شكوى بعد.
          </p>
        ) : (
          <ul className="ticket-list">
            {tickets.data.map((ticket) => (
              <TicketItem key={ticket.id} ticket={ticket} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}

function TicketItem({ ticket }) {
  const [label, badge] = TICKET_STATUS[ticket.status] ?? [ticket.status, "unpaid"];
  return (
    <li className="ticket">
      <div className="ticket-head">
        <b>{ticket.subject}</b>
        <StatusBadge status={badge} label={label} />
      </div>
      <span className="ticket-meta">
        {ticketTypeLabel(ticket.type)} · <span className="m">{dateTime(ticket.created_at)}</span>
        {ticket.user?.name ? ` · ${ticket.user.name}` : ""}
      </span>
      <p className="ticket-body">{ticket.details}</p>
      {ticket.reply ? (
        <div className="ticket-reply">
          <small>رد فريق حسبة</small>
          <p>{ticket.reply}</p>
        </div>
      ) : null}
    </li>
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

/**
 * The mobile number this account signs in with. The current password guards it; with SMS codes
 * on, the new number receives a code first. An account made with an e-mail adds its number here.
 */
function PhoneSection({ user }) {
  const options = useAuthOptions();
  const otp = Boolean(options.data?.otp);
  const [form, setForm] = useState({ phone: user.phone ?? "", current_password: "", otp_code: "" });
  const [sent, setSent] = useState(null);
  const [errors, setErrors] = useState({});
  const [banner, setBanner] = useState(null);
  const [saved, setSaved] = useState(user.phone ?? null);
  const [busy, setBusy] = useState(false);
  const set = (key) => (e) => {
    const value = key === "current_password" ? e.target.value : latinDigits(e.target.value);
    setForm({ ...form, [key]: value });
    setErrors((old) => ({ ...old, [key]: undefined }));
    if (key === "phone") setSent(null); // A changed number needs its own code.
  };

  const submit = async (e) => {
    e.preventDefault();
    const phone = normalizePhone(form.phone);
    const found = {};
    if (!phone) found.phone = form.phone.trim() ? PHONE_HINT : "اكتب رقم جوالك.";
    if (!form.current_password) found.current_password = "اكتب كلمة المرور الحالية.";
    if (otp && sent && !/^\d{6}$/.test(form.otp_code.trim())) found.otp_code = "الرمز 6 أرقام.";
    setErrors(found);
    setBanner(null);
    if (Object.keys(found).length) return;
    setBusy(true);
    try {
      if (otp && !sent) {
        const wait = await sendOtp(phone, "change_phone");
        setSent({ phone, availableAt: Date.now() + wait * 1000 });
        return;
      }
      const result = await changePhone({ phone, current_password: form.current_password, ...(otp ? { otp_code: form.otp_code.trim() } : {}) });
      setSaved(result.user.phone);
      setSent(null);
      setForm({ phone: result.user.phone, current_password: "", otp_code: "" });
    } catch (error) {
      if (error?.status === 422) setErrors(fieldErrors(error));
      else setBanner(otpSendError(error));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="card panel form-stack" onSubmit={submit} noValidate>
      <div className="panel-head">
        <h2>رقم الجوال للدخول</h2>
      </div>
      <Field id="ph-phone" label="رقم الجوال" required error={errors.phone} hint="تسجّل الدخول بهذا الرقم وكلمة مرورك.">
        <input id="ph-phone" type="tel" inputMode="tel" className="fld ltr" value={form.phone} onChange={set("phone")} autoComplete="tel" placeholder="0599123456" />
      </Field>
      <Field id="ph-current" label="كلمة المرور الحالية" required error={errors.current_password}>
        <input id="ph-current" type="password" className="fld ltr" value={form.current_password} onChange={set("current_password")} autoComplete="current-password" />
      </Field>
      {sent ? (
        <>
          <p className="field-hint">
            أرسلنا رمزاً من 6 أرقام برسالة إلى <b className="m">{maskPhone(sent.phone)}</b>.
          </p>
          <Field id="ph-code" label="رمز التأكيد" required error={errors.otp_code}>
            <input id="ph-code" inputMode="numeric" className="fld ltr" value={form.otp_code} onChange={set("otp_code")} autoComplete="one-time-code" maxLength={6} />
          </Field>
          <OtpResend
            availableAt={sent.availableAt}
            disabled={busy}
            onResend={async () => {
              try {
                const wait = await sendOtp(sent.phone, "change_phone");
                setSent({ ...sent, availableAt: Date.now() + wait * 1000 });
              } catch (error) {
                setBanner(otpSendError(error));
              }
            }}
          />
        </>
      ) : null}
      {banner ? (
        <p role="alert" className="banner tone-error">
          {banner}
        </p>
      ) : null}
      {saved && saved === normalizePhone(form.phone) && !form.current_password ? (
        <p role="status" className="banner tone-success">
          <Icon name="ok" size={20} />
          <span>تدخل الآن بالرقم <span className="m">{saved}</span>.</span>
        </p>
      ) : null}
      <div>
        <button type="submit" className="btn btn-p" disabled={busy}>
          {busy ? "لحظة…" : otp && !sent ? "أرسل رمز التأكيد" : "حفظ الرقم"}
        </button>
      </div>
    </form>
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
