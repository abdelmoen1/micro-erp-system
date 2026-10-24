import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Link, Navigate, useNavigate, useSearchParams } from "react-router-dom";
import { clock, useCountdown } from "../lib/countdown";
import Banner, { FieldError, Spinner } from "../components/Banner";
import HisbahLogo, { HisbahMark } from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { shortReference } from "../lib/format";
import { ApiError, NetworkError, session } from "../services/apiClient";
import { logout } from "../services/dashboard";
import { useLoginMutation } from "../services/useAuth";

const EMAIL_RE = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

/** What the last attempt ended with. `not_admin`: valid store account, refused here and signed out again. */
function outcomeOf(error) {
  if (error instanceof NetworkError) return { kind: "network" };
  if (!(error instanceof ApiError)) return { kind: "server" };
  if (error.status === 429) return { kind: "throttled", wait: error.retryAfter ?? 60 };
  if (error.code === "USER_INACTIVE") return { kind: "inactive" };
  if (error.status === 401 || error.code === "INVALID_CREDENTIALS") return { kind: "invalid" };
  if (error.status === 422) return { kind: "fields", errors: error.errors };
  return { kind: "server", reference: shortReference(error.correlationId) };
}

function AdminBanner({ outcome, waitLeft }) {
  switch (outcome?.kind) {
    case "invalid":
      return <Banner>البريد الإلكتروني أو كلمة المرور غير صحيحة.</Banner>;
    case "not_admin":
      return (
        <Banner tone="voided" icon="lock" extra={<Link to="/login" className="sub">الدخول إلى لوحة المتجر</Link>}>
          هذا الحساب حساب متجر، وليس حساب إدارة المنصة.
        </Banner>
      );
    case "inactive":
      return (
        <Banner tone="voided" icon="ban">
          هذا الحساب موقوف.
        </Banner>
      );
    case "throttled":
      return waitLeft > 0 ? (
        <Banner tone="pending" icon="clock">
          محاولات كثيرة. يمكنك المحاولة بعد <b className="m">{clock(waitLeft)}</b>
        </Banner>
      ) : null;
    case "expired":
      return (
        <Banner tone="info" icon="info">
          انتهت الجلسة. سجّل الدخول للمتابعة.
        </Banner>
      );
    case "network":
      return <Banner>تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.</Banner>;
    case "server":
      return (
        <Banner extra={outcome.reference ? <span className="sub">رمز المرجع: <span className="m">{outcome.reference}</span></span> : null}>
          حدث خطأ في الخادم. أعد المحاولة بعد قليل.
        </Banner>
      );
    default:
      return null;
  }
}

/**
 * Platform owner sign-in (/admin/login). Same POST /login as the store owners; only an account the
 * server marks `is_platform_admin` goes on to /admin. Any other account is signed out again here,
 * and every /admin API call is refused server-side regardless.
 */
export default function AdminLogin() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [params] = useSearchParams();
  const login = useLoginMutation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [fieldErrors, setFieldErrors] = useState({});
  const [outcome, setOutcome] = useState(() => (params.get("expired") === "1" ? { kind: "expired" } : null));
  const [checking, setChecking] = useState(false);
  const waitLeft = useCountdown(outcome?.kind === "throttled" ? outcome.wait : 0);

  // Already signed in as the platform owner: straight to the dashboard.
  if (session.token() && session.user()?.is_platform_admin && !checking) return <Navigate to="/admin" replace />;

  const busy = login.isPending || checking;
  const throttled = outcome?.kind === "throttled" && waitLeft > 0;

  const submit = (event) => {
    event.preventDefault();
    if (busy || throttled) return;
    const errors = {};
    if (!email.trim()) errors.email = "أدخل البريد الإلكتروني";
    else if (!EMAIL_RE.test(email.trim())) errors.email = "صيغة البريد الإلكتروني غير صحيحة";
    if (!password) errors.password = "أدخل كلمة المرور";
    setFieldErrors(errors);
    if (Object.keys(errors).length > 0) {
      setOutcome(null);
      document.getElementById(errors.email ? "adm-email" : "adm-pass")?.focus();
      return;
    }
    login.mutate(
      { email: email.trim(), password },
      {
        onSuccess: async (result) => {
          if (result.user?.is_platform_admin) {
            navigate("/admin", { replace: true });
            return;
          }
          setChecking(true);
          await logout();
          queryClient.clear();
          setChecking(false);
          setPassword("");
          setOutcome({ kind: "not_admin" });
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

  return (
    <div className="signin">
      <main className="signin-card">
        <section className="signin-form">
          <header className="signin-top">
            <Link to="/" className="plain" aria-label="حسبة — الصفحة الرئيسية">
              <HisbahLogo size={30} />
            </Link>
          </header>

          <div className="signin-body">
            <div>
              <h1 className="signin-title">دخول إدارة المنصة</h1>
              <p className="signin-sub">لمالك منصة حسبة فقط. أصحاب المتاجر يدخلون من صفحة الدخول العادية.</p>
            </div>
            <AdminBanner outcome={outcome} waitLeft={waitLeft} />
            <form className="form-stack" onSubmit={submit} noValidate>
              <div className="field">
                <label htmlFor="adm-email" className="field-label">
                  البريد الإلكتروني
                </label>
                <div className="fld-wrap">
                  <Icon name="mail" size={18} strokeWidth={1.7} className="fld-icon" />
                  <input
                    id="adm-email"
                    className={`fld ltr${fieldErrors.email ? " err" : ""}`}
                    type="email"
                    name="email"
                    autoComplete="username"
                    spellCheck={false}
                    value={email}
                    onChange={(e) => {
                      setEmail(e.target.value);
                      setFieldErrors((f) => ({ ...f, email: undefined }));
                    }}
                    disabled={busy}
                    aria-invalid={fieldErrors.email ? "true" : "false"}
                    aria-describedby="adm-email-err"
                  />
                </div>
                <FieldError id="adm-email-err">{fieldErrors.email}</FieldError>
              </div>
              <div className="field">
                <label htmlFor="adm-pass" className="field-label">
                  كلمة المرور
                </label>
                <div className="fld-wrap">
                  <Icon name="lock" size={18} strokeWidth={1.7} className="fld-icon" />
                  <input
                    id="adm-pass"
                    className={`fld ltr${fieldErrors.password ? " err" : ""}`}
                    type={show ? "text" : "password"}
                    name="password"
                    autoComplete="current-password"
                    value={password}
                    onChange={(e) => {
                      setPassword(e.target.value);
                      setFieldErrors((f) => ({ ...f, password: undefined }));
                    }}
                    disabled={busy}
                    aria-invalid={fieldErrors.password ? "true" : "false"}
                    aria-describedby="adm-pass-err"
                  />
                  <button
                    type="button"
                    className="eye ic"
                    onClick={() => setShow((s) => !s)}
                    aria-pressed={show}
                    aria-controls="adm-pass"
                    aria-label={show ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}
                  >
                    <Icon name={show ? "eyeOff" : "eye"} size={18} strokeWidth={1.7} />
                  </button>
                </div>
                <FieldError id="adm-pass-err">{fieldErrors.password}</FieldError>
              </div>
              <button type="submit" className="btn btn-p" disabled={busy || throttled} aria-busy={busy}>
                {busy ? <Spinner /> : null}
                <span>{busy ? "جارٍ تسجيل الدخول…" : throttled ? `انتظر ${clock(waitLeft)}` : "دخول الإدارة"}</span>
              </button>
            </form>
          </div>

          <footer className="signin-foot">
            <span className="m">© 2026 حسبة</span>
            <Link to="/login" className="quiet-link">
              دخول أصحاب المتاجر
            </Link>
          </footer>
        </section>

        <aside className="signin-panel" aria-hidden="true">
          <p className="panel-crumb">حسبة / إدارة المنصة</p>
          <HisbahMark size={210} className="panel-mark" />
          <div>
            <p className="panel-kicker">كل المتاجر في مكان واحد</p>
            <p className="panel-title">
              الحسابات والاشتراكات
              <br />
              والمنتجات.
            </p>
          </div>
        </aside>
      </main>
    </div>
  );
}
