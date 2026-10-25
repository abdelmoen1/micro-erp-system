import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { clock, useCountdown } from "../lib/countdown";
import Banner, { FieldError, Spinner } from "../components/Banner";
import GoogleButton from "../components/GoogleButton";
import HisbahLogo from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { GOOGLE_CLIENT_ID } from "../lib/google";
import { landingPath } from "../lib/domain";
import { shortReference } from "../lib/format";
import { ApiError, NetworkError } from "../services/apiClient";
import { useGoogleMutation, useGoogleRegisterMutation, useRegisterMutation } from "../services/useAuth";

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const PHONE_RE = /^\d{9,10}$/;

/** Cities offered on step 2; the API stores them with the street in the store's address. */
const CITIES = [
  "الخليل", "بيت لحم", "القدس", "رام الله والبيرة", "نابلس", "جنين", "طولكرم", "قلقيلية",
  "سلفيت", "طوباس", "أريحا", "غزة", "شمال غزة", "دير البلح", "خان يونس", "رفح",
];

const EMPTY = { store_name: "", owner_name: "", phone: "", city: "", street: "", email: "", password: "", password_confirmation: "" };

const STEPS = [
  { title: "المتجر", heading: "المتجر", sub: "لنبدأ باسم متجرك واسم صاحبه المسؤول عنه.", fields: ["store_name", "owner_name"] },
  { title: "الموقع والتواصل", heading: "الموقع والتواصل", sub: "الهاتف والعنوان يظهران على إيصال الزبون.", fields: ["phone", "city", "street"] },
  { title: "بيانات الدخول", heading: "بيانات الدخول", sub: "اختر البريد وكلمة المرور التي تدخل بها إلى حسبة.", fields: ["email", "password", "password_confirmation"] },
];

// API field → the step that owns it (address covers city and street; area is the city).
const FIELD_STEP = { store_name: 0, owner_name: 0, phone: 1, address: 1, area: 1, email: 2, password: 2, password_confirmation: 2 };
const FIELD_INPUT = { address: "street", area: "city" };

const digits = (s) => s.replace(/[\s-]/g, "");

function validate(step, v, sso) {
  const e = {};
  if (step === 0) {
    if (!v.store_name.trim()) e.store_name = "يرجى إدخال اسم المتجر.";
    if (!v.owner_name.trim()) e.owner_name = "يرجى إدخال اسم صاحب المتجر.";
  }
  if (step === 1) {
    if (!v.phone.trim()) e.phone = "يرجى إدخال رقم الهاتف.";
    else if (!PHONE_RE.test(digits(v.phone))) e.phone = "رقم الهاتف 9 أو 10 أرقام، مثل 0599123456.";
    if (!v.city) e.city = "يرجى اختيار المدينة.";
    if (!v.street.trim()) e.street = "يرجى إدخال عنوان المتجر.";
  }
  if (step === 2 && !sso) {
    if (!v.email.trim()) e.email = "يرجى إدخال البريد الإلكتروني.";
    else if (!EMAIL_RE.test(v.email.trim())) e.email = "صيغة البريد الإلكتروني غير صحيحة.";
    if (v.password.length < 8) e.password = "كلمة المرور 8 أحرف على الأقل.";
    if (!v.password_confirmation || v.password_confirmation !== v.password) e.password_confirmation = "التأكيد لا يطابق كلمة المرور.";
  }
  return e;
}

/** API field errors placed on our fields (address → street, area → city); «email taken» gets its own wording. */
function serverFieldErrors(error) {
  const e = {};
  for (const key of Object.keys(FIELD_STEP)) {
    const message = error.fieldError(key);
    if (message) e[FIELD_INPUT[key] ?? key] = message;
  }
  if (e.email && /taken|مستخدم|مسجّل/i.test(e.email)) e.email = "هذا البريد مسجّل مسبقاً. سجّل الدخول، أو استخدم بريداً آخر.";
  return e;
}

function Field({ id, label, hint, error, children }) {
  return (
    <div className="field">
      <label htmlFor={id} className="field-label req">
        {label}
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
      return <Banner>لم يُنشأ المتجر: البريد الإلكتروني مستخدم.</Banner>;
    case "validation":
      return <Banner>لم يُنشأ المتجر. راجع الحقول المعلّمة.</Banner>;
    case "expired":
      return (
        <Banner extra={<Link to="/login" className="sub">العودة لتسجيل الدخول</Link>}>
          انتهت مهلة التسجيل بحساب Google. تابع بحساب Google مرة أخرى.
        </Banner>
      );
    case "google":
      return <Banner>{outcome.message}</Banner>;
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

/** SCR-W-02 · /join: create a store and its owner in three steps (US-0201, DEF-13), by email or Google. */
export default function Join() {
  const navigate = useNavigate();
  const location = useLocation();
  const register = useRegisterMutation();
  const googleRegister = useGoogleRegisterMutation();
  const google = useGoogleMutation();

  // Google account from the login page (router state) or from the button on step 3.
  const [sso, setSso] = useState(() => location.state?.google ?? null);
  const [step, setStep] = useState(0);
  const [v, setV] = useState(() => ({ ...EMPTY, owner_name: location.state?.google?.name ?? "" }));
  const [errors, setErrors] = useState({});
  const [outcome, setOutcome] = useState(null);
  const [show, setShow] = useState({ password: false, password_confirmation: false });
  const waitLeft = useCountdown(outcome?.kind === "throttled" ? outcome.wait : 0);

  const busy = register.isPending || googleRegister.isPending || google.isPending;
  const throttled = outcome?.kind === "throttled" && waitLeft > 0;
  const success = outcome?.kind === "success";
  const last = step === STEPS.length - 1;

  const set = (key) => (event) => {
    const value = event.target.value;
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
    if (error.code === "GOOGLE_TOKEN_INVALID" || error.code === "SSO_UNAVAILABLE") return setOutcome({ kind: "google", message: error.message });
    if (error.status === 422) {
      if (error.fieldError("onboarding_token")) return setOutcome({ kind: "expired" });
      const fields = serverFieldErrors(error);
      setErrors(fields);
      const steps = Object.keys(fields).map((k) => FIELD_STEP[k] ?? (k === "street" || k === "city" ? 1 : 2));
      const first = Math.min(...steps, 2);
      if (first !== step) setStep(first);
      return setOutcome({ kind: fields.email && Object.keys(fields).length === 1 ? "taken" : "validation" });
    }
    return setOutcome({ kind: "server", reference: shortReference(error.correlationId) });
  };

  const create = () => {
    const base = {
      store_name: v.store_name.trim(),
      owner_name: v.owner_name.trim(),
      phone: digits(v.phone),
      address: `${v.street.trim()}، ${v.city}`,
      area: v.city,
    };
    const done = { onSuccess: () => { setOutcome({ kind: "success" }); navigate("/dashboard", { replace: true }); }, onError: fail };
    if (sso) googleRegister.mutate({ onboarding_token: sso.token, ...base }, done);
    else register.mutate({ ...base, email: v.email.trim(), password: v.password, password_confirmation: v.password_confirmation }, done);
  };

  const onGoogle = (credential) => {
    if (busy) return;
    google.mutate(credential, {
      onSuccess: (result) => {
        if (result.onboarding) {
          setSso(result.onboarding);
          setOutcome(null);
          return;
        }
        navigate(landingPath(result.user), { replace: true }); // Already registered: Google signed them in.
      },
      onError: fail,
    });
  };

  const next = (event) => {
    event.preventDefault();
    if (busy || throttled || success) return;
    const local = validate(step, v, sso);
    setErrors(local);
    if (Object.keys(local).length > 0) {
      document.getElementById(`join-${Object.keys(local)[0]}`)?.focus();
      return;
    }
    if (last) create();
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
                <Field id="join-phone" label="رقم الهاتف" error={errors.phone}>
                  <input {...input("phone", { ltr: true, type: "tel", inputMode: "numeric", autoComplete: "tel", placeholder: "0599123456", maxLength: 12 })} />
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

            {step === 2 && sso ? (
              <div className="note ok">
                <Icon name="ok" size={20} />
                <p>
                  تدخل بحساب Google: <b className="m">{sso.email}</b>
                  <br />
                  لا تحتاج كلمة مرور. اضغط «إنشاء المتجر» للمتابعة.
                </p>
              </div>
            ) : null}

            {step === 2 && !sso ? (
              <>
                {GOOGLE_CLIENT_ID ? (
                  <>
                    <GoogleButton onCredential={onGoogle} text="signup_with" disabled={busy} />
                    <div className="or" role="separator">
                      أو بالبريد الإلكتروني
                    </div>
                  </>
                ) : null}
                <div className="grid2">
                  <Field id="join-email" label="البريد الإلكتروني" hint="تدخل به إلى لوحة الإدارة وتطبيق البيع." error={errors.email}>
                    <input {...input("email", { ltr: true, type: "email", inputMode: "email", autoComplete: "username", spellCheck: false, placeholder: "name@store.ps" })} />
                  </Field>
                  {pw("password", "كلمة المرور", "8 أحرف على الأقل.")}
                  {pw("password_confirmation", "تأكيد كلمة المرور")}
                </div>
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
