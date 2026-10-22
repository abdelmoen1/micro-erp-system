import { useState } from "react";
import { Link, useNavigate, useSearchParams } from "react-router-dom";
import HisbahLogo from "../components/HisbahLogo";
import { ErrorBanner, Field } from "../components/ui";
import { apiSend, session } from "../services/apiClient";

/** US-0204: the invited employee opens the owner's link and creates an account in that store. */
export default function AcceptInvite() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const token = params.get("invite") ?? "";
  const [form, setForm] = useState({ name: "", email: "", password: "", password_confirmation: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);
  const set = (field) => (e) => setForm({ ...form, [field]: e.target.value });
  const err = (field) => error?.fieldError?.(field);

  const submit = async (e) => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const result = await apiSend("POST", "/register/invitation", { token, ...form });
      session.save(result.token, result.user);
      navigate("/dashboard", { replace: true });
    } catch (failure) {
      setError(failure);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="signin">
      <main className="signin-card" style={{ gridTemplateColumns: "minmax(0, 1fr)", maxWidth: 560, minHeight: 0 }}>
        <section className="signin-form">
          <header className="signin-top">
            <Link to="/" className="plain" aria-label="حسبة — الصفحة الرئيسية">
              <HisbahLogo size={30} />
            </Link>
          </header>
          <div className="signin-body">
            <div>
              <h1 className="signin-title">الانضمام إلى المتجر</h1>
              <p className="signin-sub">أنشئ حسابك لتبدأ العمل في المتجر الذي دعاك.</p>
            </div>
            {!token ? (
              <p role="alert" className="banner tone-error">
                رابط الدعوة ناقص. اطلب من مالك المتجر رابطاً جديداً.
              </p>
            ) : (
              <form className="form-stack" onSubmit={submit} noValidate>
                <Field id="ai-name" label="الاسم" error={err("name")}>
                  <input id="ai-name" className="fld" value={form.name} onChange={set("name")} autoComplete="name" />
                </Field>
                <Field id="ai-email" label="البريد الإلكتروني" error={err("email")}>
                  <input id="ai-email" type="email" className="fld ltr" value={form.email} onChange={set("email")} autoComplete="username" />
                </Field>
                <Field id="ai-pass" label="كلمة المرور" error={err("password")}>
                  <input id="ai-pass" type="password" className="fld ltr" value={form.password} onChange={set("password")} autoComplete="new-password" />
                </Field>
                <Field id="ai-pass2" label="تأكيد كلمة المرور" error={err("password_confirmation")}>
                  <input id="ai-pass2" type="password" className="fld ltr" value={form.password_confirmation} onChange={set("password_confirmation")} autoComplete="new-password" />
                </Field>
                <ErrorBanner error={error && !Object.keys(error.errors ?? {}).length ? error : err("token") ? { message: err("token") } : null} />
                <button type="submit" className="btn btn-p" disabled={busy}>
                  {busy ? "جارٍ إنشاء الحساب…" : "إنشاء الحساب والانضمام"}
                </button>
              </form>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
