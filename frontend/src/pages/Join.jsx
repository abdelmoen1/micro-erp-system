import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { clock, useCountdown } from "../lib/countdown";
import Banner, { FieldError, Spinner } from "../components/Banner";
import HisbahLogo from "../components/HisbahLogo";
import Icon from "../components/Icon";
import OtpResend from "../components/OtpResend";
import OtpWhatsapp from "../components/OtpWhatsapp";
import { latinDigits, shortReference } from "../lib/format";
import { maskPhone, normalizePhone, PHONE_HINT, otpSendError } from "../lib/phone";
import { sendOtp } from "../services/api";
import { ApiError, NetworkError } from "../services/apiClient";
import { useAuthOptions, useRegisterMutation } from "../services/useAuth";

/** Cities offered on step 2; the API stores them with the street in the store's address. */
const CITIES = [
  "الخليل", "بيت لحم", "القدس", "رام الله والبيرة", "نابلس", "جنين", "طولكرم", "قلقيلية",
  "سلفيت", "طوباس", "أريحا", "غزة", "شمال غزة", "دير البلح", "خان يونس", "رفح",
];

const EMPTY = { store_name: "", owner_name: "", phone: "", city: "", street: "", password: "", password_confirmation: "", otp_code: "" };

const STEPS = [
  { title: "المتجر", heading: "المتجر", sub: "لنبدأ باسم متجرك واسم صاحبه المسؤول عنه.", fields: ["store_name", "owner_name"] },
  { title: "الموقع والتواصل", heading: "الموقع والتواصل", sub: "تدخل إلى حسبة برقم جوالك، ويظهر هو والعنوان على إيصال الزبون.", fields: ["phone", "city", "street"] },
  { title: "بيانات الدخول", heading: "بيانات الدخول", sub: "اختر كلمة المرور التي تدخل بها مع رقم جوالك.", fields: ["password", "password_confirmation"] },
];

// API field → the step that owns it (address covers city and street; area is the city).
const FIELD_STEP = { store_name: 0, owner_name: 0, owner_phone: 1, phone: 1, address: 1, area: 1, password: 2, password_confirmation: 2, otp_code: 2 };
const FIELD_INPUT = { address: "street", area: "city", owner_phone: "phone" };
const TAKEN = /taken|مستخدم|مسجّل/i;

function validate(step, v) {
  const e = {};
  if (step === 0) {
    if (!v.store_name.trim()) e.store_name = "يرجى إدخال اسم المتجر.";
    if (!v.owner_name.trim()) e.owner_name = "يرجى إدخال اسم صاحب المتجر.";
  }
  if (step === 1) {
    if (!v.phone.trim()) e.phone = "اكتب رقم جوالك.";
    else if (!normalizePhone(v.phone)) e.phone = PHONE_HINT;
    if (!v.city) e.city = "يرجى اختيار المدينة.";
    if (!v.street.trim()) e.street = "يرجى إدخال عنوان المتجر.";
  }
  if (step === 2) {
    if (v.password.length < 8) e.password = "كلمة المرور 8 أحرف على الأقل.";
    if (!v.password_confirmation || v.password_confirmation !== v.password) e.password_confirmation = "التأكيد لا يطابق كلمة المرور.";
  }
  return e;
}

/** API field errors placed on our fields (address → street, area → city); «number taken» gets its own wording. */
function serverFieldErrors(error) {
  const e = {};
  for (const key of Object.keys(FIELD_STEP)) {
    const message = error.fieldError(key);
    if (message) e[FIELD_INPUT[key] ?? key] = message;
  }
  if (e.phone && TAKEN.test(e.phone)) e.phone = "هذا الرقم مسجّل مسبقاً. سجّل الدخول، أو استخدم رقماً آخر.";
  return e;
}

function Field({ id, label, hint, error, optional, children }) {
  return (
    <div className="field">
      <label htmlFor={id} className={`field-label${optional ? "" : " req"}`}>
        {label} {optional ? <span className="opt">(اختياري)</span> : null}
      </label>
      {children}
      {error ? (
        <FieldError id={`${id}-msg`}>{error}</FieldError>
      ) : hint ? (
        <span id={`${id}-msg`} className="field-hint">
          {hint}
        </span>
      ) : null}
    </div>
  );
}

function JoinBanner({ outcome, waitLeft }) {
  switch (outcome?.kind) {
    case "taken":
      return <Banner>لم يُنشأ المتجر: رقم الجوال مستخدم.</Banner>;
    case "validation":
      return <Banner>لم يُنشأ المتجر. راجع الحقول المعلّمة.</Banner>;
    case "throttled":
      return waitLeft > 0 ? (
        <Banner tone="pending" icon="clock">
          محاولات كثيرة من هذا الجهاز. يمكنك المحاولة بعد <b className="m">{clock(waitLeft)}</b>
        </Banner>
      ) : null;
    case "network":
      return <Banner>تعذّر الاتصال بالخادم. بياناتك باقية في النموذج، أعد المحاولة.</Banner>;
    case "server":
      return (
        <Banner
          extra={
            outcome.reference ? (
              <span className="sub">
                رمز المرجع: <span className="m">{outcome.reference}</span>
              </span>
            ) : null
          }
        >
          حدث خطأ في الخادم ولم يُنشأ المتجر. أعد المحاولة بعد قليل.
        </Banner>
      );
    case "success":
      return (
        <Banner tone="success" icon="ok" extra={<Link to="/dashboard" className="sub">فتح لوحة التحكم الآن</Link>}>
          تم إنشاء المتجر وحساب المالك. جارٍ فتح لوحة التحكم…
        </Banner>
      );
    default:
      return null;
  }
}

function Stepper({ current }) {
  return (
    <ol className="stepper">
      {STEPS.map((s, i) => {
        const state = i < current ? "done" : i === current ? "now" : "todo";
        return (
          <li key={s.title} className={state} aria-current={state === "now" ? "step" : undefined}>
            <span className="dot" aria-hidden="true">
              {state === "done" ? <Icon name="check" size={16} strokeWidth={2.6} /> : <span className="m">{i + 1}</span>}
            </span>
            <span className="name">{s.title}</span>
            {state === "done" ? <span className="sr-only">(مكتملة)</span> : null}
          </li>
        );
      })}
    </ol>
  );
}

/** SCR-W-02 · /join: create a store and its owner in three steps (US-0201, DEF-13); the owner signs in with the phone. */
export default function Join() {
  const navigate = useNavigate();
  const register = useRegisterMutation();
  const [step, setStep] = useState(0);
  const [v, setV] = useState(EMPTY);
  const [errors, setErrors] = useState({});
  const [outcome, setOutcome] = useState(null);
  const [show, setShow] = useState({ password: false, password_confirmation: false });
  const waitLeft = useCountdown(outcome?.kind === "throttled" ? outcome.wait : 0);
  const options = useAuthOptions();
  // With SMS codes on: where the code went and when a new one may be asked.
  const [code, setCode] = useState(null);
  const [sending, setSending] = useState(false);
  const [codeError, setCodeError] = useState(null);
  const otp = Boolean(options.data?.otp);

  const busy = register.isPending || sending;
  const throttled = outcome?.kind === "throttled" && waitLeft > 0;
  const success = outcome?.kind === "success";
  const last = step === STEPS.length - 1;

  const set = (key) => (event) => {
    // A phone typed on an Arabic keyboard (٠٥٩…) is kept as 059….
    const value = key === "phone" || key === "otp_code" ? latinDigits(event.target.value) : event.target.value;
    // A changed number needs its own code.
    if (key === "phone") setCode(null);
    setV((old) => ({ ...old, [key]: value }));
    setErrors((old) => ({ ...old, [key]: undefined }));
  };

  const goTo = (next) => {
    setStep(next);
    setOutcome(null);
    requestAnimationFrame(() => document.getElementById("join-step-title")?.focus());
  };

  const input = (key, props = {}) => ({
    id: `join-${key}`,
    name: key,
    value: v[key],
    onChange: set(key),
    disabled: busy || success,
    className: `fld${props.ltr ? " ltr" : ""}${errors[key] ? " err" : ""}`,
    "aria-invalid": errors[key] ? "true" : "false",
    "aria-describedby": `join-${key}-msg`,
    ...Object.fromEntries(Object.entries(props).filter(([k]) => k !== "ltr")),
  });

  const fail = (error) => {
    if (error instanceof NetworkError) return setOutcome({ kind: "network" });
    if (!(error instanceof ApiError)) return setOutcome({ kind: "server" });
    if (error.status === 429) return setOutcome({ kind: "throttled", wait: error.retryAfter ?? 60 });
    if (error.status === 422) {
      const fields = serverFieldErrors(error);
      setErrors(fields);
      const steps = Object.keys(fields).map((k) => FIELD_STEP[k] ?? (k === "street" || k === "city" ? 1 : 2));
      const first = Math.min(...steps, 2);
      if (first !== step) setStep(first);
      // Only a wrong code keeps the code field open.
      if (Object.keys(fields).some((k) => k !== "otp_code")) setCode(null);
      return setOutcome({ kind: fields.phone && TAKEN.test(fields.phone) && Object.keys(fields).length === 1 ? "taken" : "validation" });
    }
    return setOutcome({ kind: "server", reference: shortReference(error.correlationId) });
  };

  const send = async () => {
    const phone = normalizePhone(v.phone);
    setSending(true);
    setCodeError(null);
    try {
      const wait = await sendOtp(phone, "register");
      setCode({ sentTo: phone, availableAt: Date.now() + wait * 1000 });
      requestAnimationFrame(() => document.getElementById("join-otp_code")?.focus());
    } catch (error) {
      if (error?.status === 422) return fail(error);
      setCodeError(otpSendError(error));
    } finally {
      setSending(false);
    }
  };

  const create = () => {
    const phone = normalizePhone(v.phone);
    register.mutate(
      {
        store_name: v.store_name.trim(),
        owner_name: v.owner_name.trim(),
        // The owner signs in with this number; it is the store's phone on receipts too.
        owner_phone: phone,
        phone,
        address: `${v.street.trim()}، ${v.city}`,
        area: v.city,
        password: v.password,
        password_confirmation: v.password_confirmation,
        ...(code ? { otp_code: v.otp_code.trim() } : {}),
      },
      { onSuccess: () => { setOutcome({ kind: "success" }); navigate("/dashboard", { replace: true }); }, onError: fail },
    );
  };

  const next = (event) => {
    event.preventDefault();
    if (busy || throttled || success) return;
    const local = validate(step, v);
    if (last && code && !/^\d{6}$/.test(v.otp_code.trim())) local.otp_code = "الرمز 6 أرقام.";
    setErrors(local);
    if (Object.keys(local).length > 0) {
      document.getElementById(`join-${Object.keys(local)[0]}`)?.focus();
      return;
    }
    if (last && otp && !code) send();
    else if (last) create();
    else goTo(step + 1);
  };

  const label = busy
    ? last
      ? "جارٍ إنشاء المتجر…"
      : "لحظة…"
    : throttled
      ? `انتظر ${clock(waitLeft)}`
      : last
        ? outcome?.kind === "network" || outcome?.kind === "server"
          ? "إعادة المحاولة"
          : otp && !code
            ? "أرسل رمز التأكيد"
            : code
              ? "تأكيد الرمز وإنشاء المتجر"
              : "إنشاء المتجر"
        : "التالي";

  const pw = (key, text, hint) => (
    <Field id={`join-${key}`} label={text} hint={hint} error={errors[key]}>
      <div className="fld-wrap">
        <input {...input(key, { ltr: true, type: show[key] ? "text" : "password", autoComplete: "new-password" })} />
        <button
          type="button"
          className="eye ic"
          onClick={() => setShow((s) => ({ ...s, [key]: !s[key] }))}
          aria-pressed={show[key]}
          aria-label={show[key] ? `إخفاء ${text}` : `إظهار ${text}`}
        >
          <Icon name={show[key] ? "eyeOff" : "eye"} size={18} strokeWidth={1.7} />
        </button>
      </div>
    </Field>
  );

  return (
    <div className="join">
      <header className="join-top">
        <Link to="/" className="plain" aria-label="حسبة — الصفحة الرئيسية">
          <HisbahLogo size={34} />
        </Link>
        <Link to="/#faq" className="quiet-link">
          عندك سؤال؟
        </Link>
      </header>

      <main className="join-main">
        <div className="join-head">
          <p className="join-kicker">لأصحاب المحلات</p>
          <h1>إنشاء متجر جديد</h1>
          <p>سجّل متجرك في حسبة، وابدأ البيع من الجوال والإدارة من الحاسوب.</p>
        </div>

        <section className="join-card" aria-labelledby="join-step-title">
          <Stepper current={step} />

          <div className="join-step-head step-in" key={`h${step}`}>
            <h2 id="join-step-title" tabIndex={-1}>
              {STEPS[step].heading}
            </h2>
            <p>{STEPS[step].sub}</p>
            <p className="join-count">
              الخطوة <span className="m">{step + 1}</span> من <span className="m">3</span> · جميع الحقول مطلوبة
            </p>
          </div>

          <JoinBanner outcome={outcome} waitLeft={waitLeft} />
          {codeError ? <Banner>{codeError}</Banner> : null}

          <form key={step} onSubmit={next} noValidate className="form-stack step-in">
            {step === 0 ? (
              <div className="grid2">
                <Field id="join-store_name" label="اسم المتجر" error={errors.store_name}>
                  <input {...input("store_name", { autoComplete: "organization", placeholder: "مثل: بقالة النور", maxLength: 255 })} />
                </Field>
                <Field id="join-owner_name" label="اسم صاحب المتجر" error={errors.owner_name}>
                  <input {...input("owner_name", { autoComplete: "name", placeholder: "الاسم الكامل", maxLength: 255 })} />
                </Field>
              </div>
            ) : null}

            {step === 1 ? (
              <div className="grid2">
                <Field id="join-phone" label="رقم جوالك (تسجّل الدخول به)" error={errors.phone}>
                  <input {...input("phone", { ltr: true, type: "tel", inputMode: "tel", autoComplete: "tel", placeholder: "0599123456", maxLength: 16 })} />
                </Field>
                <Field id="join-city" label="المدينة" error={errors.city}>
                  <select {...input("city", { autoComplete: "address-level2" })}>
                    <option value="">اختر المدينة</option>
                    {CITIES.map((c) => (
                      <option key={c}>{c}</option>
                    ))}
                  </select>
                </Field>
                <div className="span2">
                  <Field id="join-street" label="عنوان المتجر" error={errors.street}>
                    <input {...input("street", { autoComplete: "street-address", placeholder: "الشارع، الحي، علامة قريبة", maxLength: 200 })} />
                  </Field>
                </div>
              </div>
            ) : null}

            {step === 2 ? (
              <>
                <div className="grid2">
                  {pw("password", "كلمة المرور", "8 أحرف على الأقل.")}
                  {pw("password_confirmation", "تأكيد كلمة المرور")}
                </div>
                {code ? (
                  <div className="otp-box">
                    <p>
                      أرسلنا رمزاً من 6 أرقام برسالة إلى <b className="m">{maskPhone(code.sentTo)}</b>.
                    </p>
                    <Field id="join-otp_code" label="رمز التأكيد" error={errors.otp_code}>
                      <input {...input("otp_code", { ltr: true, inputMode: "numeric", autoComplete: "one-time-code", maxLength: 6, placeholder: "6 أرقام" })} />
                    </Field>
                    <OtpResend availableAt={code.availableAt} onResend={send} disabled={busy} />
                    <OtpWhatsapp phone={code.sentTo} />
                  </div>
                ) : null}
              </>
            ) : null}

            {last ? <p className="note">بعد الإنشاء تدخل إلى لوحة الإدارة مباشرة مالكاً للمتجر، وتدعو موظفيك لاحقاً.</p> : null}

            <div className="join-actions">
              <button type="submit" className="btn btn-p pill" disabled={busy || throttled || success} aria-busy={busy}>
                {busy ? <Spinner /> : null}
                <span>{label}</span>
                {busy || last ? null : <Icon name="arrow" size={18} />}
              </button>
              {step > 0 ? (
                <button type="button" className="btn btn-ghost pill" onClick={() => goTo(step - 1)} disabled={busy || success}>
                  رجوع
                </button>
              ) : null}
            </div>
          </form>

          <p className="join-foot">
            <span>لديك حساب بالفعل؟</span>
            <Link to="/login">تسجيل الدخول</Link>
          </p>
        </section>
      </main>
    </div>
  );
}
