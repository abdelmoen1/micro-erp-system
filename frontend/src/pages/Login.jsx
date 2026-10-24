import { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import { clock, useCountdown } from "../lib/countdown";
import Banner, { FieldError, Spinner } from "../components/Banner";
import GoogleButton from "../components/GoogleButton";
import HisbahLogo, { HisbahMark } from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { GOOGLE_CLIENT_ID } from "../lib/google";
import { landingPath } from "../lib/domain";
import { shortReference } from "../lib/format";
import { ApiError, NetworkError } from "../services/apiClient";
import { useGoogleMutation, useLoginMutation } from "../services/useAuth";

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** What the last attempt ended with (W-01 review states). */
function outcomeOf(error) {
  if (error instanceof NetworkError) return { kind: "network" };
  if (!(error instanceof ApiError)) return { kind: "server" };
  if (error.status === 429) return { kind: "throttled", wait: error.retryAfter ?? 60 };
  if (error.code === "USER_INACTIVE") return { kind: "inactive" };
  if (error.code === "STORE_SUSPENDED") return { kind: "suspended" };
  if (error.code === "GOOGLE_TOKEN_INVALID" || error.code === "SSO_UNAVAILABLE") return { kind: "google", message: error.message };
  if (error.status === 401 || error.code === "INVALID_CREDENTIALS") return { kind: "invalid" };
  if (error.status === 422) return { kind: "fields", errors: error.errors };
  return { kind: "server", reference: shortReference(error.correlationId) };
}

function LoginBanner({ outcome, waitLeft }) {
  switch (outcome?.kind) {
    case "invalid":
      return <Banner>البريد الإلكتروني أو كلمة المرور غير صحيحة.</Banner>;
    case "throttled":
      return waitLeft > 0 ? (
        <Banner tone="pending" icon="clock">
          محاولات كثيرة. يمكنك المحاولة بعد <b className="m">{clock(waitLeft)}</b>
        </Banner>
      ) : null;
    case "inactive":
      return (
        <Banner tone="voided" icon="ban">
          هذا الحساب موقوف. تواصل مع مالك المتجر لإعادة تفعيله.
        </Banner>
      );
    case "suspended":
      return (
        <Banner tone="voided" icon="ban">
          حساب هذا المتجر موقوف. تواصل مع إدارة حسبة لإعادة تفعيله.
        </Banner>
      );
    case "expired":
      return (
        <Banner tone="info" icon="info">
          انتهت الجلسة. سجّل الدخول للمتابعة من حيث توقفت.
        </Banner>
      );
    case "google":
      return <Banner>{outcome.message}</Banner>;
    case "network":
      return <Banner>تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.</Banner>;
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
          حدث خطأ في الخادم. أعد المحاولة بعد قليل.
        </Banner>
      );
    case "success":
      return (
        <Banner tone="success" icon="ok" extra={<Link to="/dashboard" className="sub">فتح لوحة التحكم الآن</Link>}>
          تم تسجيل الدخول. جارٍ فتح لوحة التحكم…
        </Banner>
      );
    default:
      return null;
  }
}

/** SCR-W-01 · login (US-0202): the form beside the deep-teal brand panel. */
export default function Login() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const login = useLoginMutation();
  const google = useGoogleMutation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [fieldErrors, setFieldErrors] = useState({});
  const [outcome, setOutcome] = useState(() => (params.get("expired") === "1" ? { kind: "expired" } : null));
  const waitLeft = useCountdown(outcome?.kind === "throttled" ? outcome.wait : 0);

  const busy = login.isPending || google.isPending;
  const throttled = outcome?.kind === "throttled" && waitLeft > 0;
  const success = outcome?.kind === "success";

  // A new Google account continues to registration; a known one goes straight in.
  const onGoogle = (credential) => {
    if (busy || success) return;
    google.mutate(credential, {
      onSuccess: (result) => {
        if (result.onboarding) {
          navigate("/join", { state: { google: result.onboarding } });
          return;
        }
        setOutcome({ kind: "success" });
        navigate(landingPath(result.user), { replace: true });
      },
      onError: (error) => setOutcome(outcomeOf(error)),
    });
  };

  const submit = (event) => {
    event.preventDefault();
    if (busy || throttled || success) return;
    const errors = {};
    if (!email.trim()) errors.email = "أدخل البريد الإلكتروني";
    else if (!EMAIL_RE.test(email.trim())) errors.email = "صيغة البريد الإلكتروني غير صحيحة";
    if (!password) errors.password = "أدخل كلمة المرور";
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) {
      setOutcome(null);
      document.getElementById(errors.email ? "w1-email" : "w1-pass")?.focus();
      return;
    }
    login.mutate(
      { email: email.trim(), password },
      {
        onSuccess: (result) => {
          setOutcome({ kind: "success" });
          navigate(landingPath(result.user), { replace: true });
        },
        onError: (error) => {
          const next = outcomeOf(error);
          if (next.kind === "fields") {
            setFieldErrors({ email: next.errors.email?.[0], password: next.errors.password?.[0] });
            setOutcome(null);
            return;
          }
          if (next.kind === "invalid") setPassword("");
          setOutcome(next);
        },
      },
    );
  };

  const label = busy
    ? "جارٍ تسجيل الدخول…"
    : throttled
      ? `انتظر ${clock(waitLeft)}`
      : success
        ? "تم الدخول"
        : outcome?.kind === "network" || outcome?.kind === "server"
          ? "إعادة المحاولة"
          : "تسجيل الدخول";

  return (
    <div className="signin">
      <main className="signin-card">
        <section className="signin-form">
          <header className="signin-top">
            <Link to="/" className="plain" aria-label="حسبة — الصفحة الرئيسية">
              <HisbahLogo size={30} />
            </Link>
            <Link to="/" className="quiet-link">
              الصفحة الرئيسية
            </Link>
          </header>

          <div className="signin-body">
            <div>
              <h1 className="signin-title">مرحبًا بعودتك</h1>
              <p className="signin-sub">سجّل الدخول إلى لوحة إدارة متجرك.</p>
            </div>
            <LoginBanner outcome={outcome} waitLeft={waitLeft} />
            <form className="form-stack" onSubmit={submit} noValidate>
              <div className="field">
                <label htmlFor="w1-email" className="field-label">
                  البريد الإلكتروني
                </label>
                <div className="fld-wrap">
                  <Icon name="mail" size={18} strokeWidth={1.7} className="fld-icon" />
                  <input
                    id="w1-email"
                    className={`fld ltr${fieldErrors.email ? " err" : ""}`}
                    type="email"
                    name="email"
                    autoComplete="username"
                    spellCheck={false}
                    placeholder="name@store.ps"
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      setFieldErrors((f) => ({ ...f, email: undefined }));
                    }}
                    disabled={busy}
                    aria-invalid={fieldErrors.email ? "true" : "false"}
                    aria-describedby="w1-email-err"
                  />
                </div>
                <FieldError id="w1-email-err">{fieldErrors.email}</FieldError>
              </div>
              <div className="field">
                <label htmlFor="w1-pass" className="field-label">
                  كلمة المرور
                </label>
                <div className="fld-wrap">
                  <Icon name="lock" size={18} strokeWidth={1.7} className="fld-icon" />
                  <input
                    id="w1-pass"
                    className={`fld ltr${fieldErrors.password ? " err" : ""}`}
                    type={show ? "text" : "password"}
                    name="password"
                    autoComplete="current-password"
                    placeholder="أدخل كلمة المرور"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      setFieldErrors((f) => ({ ...f, password: undefined }));
                    }}
                    disabled={busy}
                    aria-invalid={fieldErrors.password ? "true" : "false"}
                    aria-describedby="w1-pass-err"
                  />
                  <button
                    type="button"
                    className="eye ic"
                    onClick={() => setShow((s) => !s)}
                    aria-pressed={show}
                    aria-controls="w1-pass"
                    aria-label={show ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}
                  >
                    <Icon name={show ? "eyeOff" : "eye"} size={18} strokeWidth={1.7} />
                  </button>
                </div>
                <FieldError id="w1-pass-err">{fieldErrors.password}</FieldError>
              </div>
              <button type="submit" className="btn btn-p" disabled={busy || throttled || success} aria-busy={busy}>
                {busy ? <Spinner /> : null}
                <span>{label}</span>
                {busy ? null : <Icon name="arrow" size={18} />}
              </button>
            </form>
            <p className="signin-alt">
              <span>ليس لديك حساب؟</span>
              <Link to="/join">إنشاء متجر جديد</Link>
            </p>
            {GOOGLE_CLIENT_ID ? (
              <div className="signin-sso">
                <GoogleButton onCredential={onGoogle} text="signin_with" disabled={busy} />
                <p>حساب Google الجديد يكمل إنشاء المتجر بعد الدخول.</p>
              </div>
            ) : null}
          </div>

          <footer className="signin-foot">
            <span className="m">© 2026 حسبة</span>
            <Link to="/#faq" className="quiet-link">
              الأسئلة الشائعة
            </Link>
          </footer>
        </section>

        <aside className="signin-panel" aria-hidden="true">
          <p className="panel-crumb">حسبة / لوحة إدارة المتجر</p>
          <HisbahMark size={210} className="panel-mark" />
          <div>
            <p className="panel-kicker">للبقالات والمحامص ومحلات البهارات</p>
            <p className="panel-title">
              دفتر متجرك،
              <br />
              في جيبك.
            </p>
          </div>
        </aside>
      </main>
    </div>
  );
}
