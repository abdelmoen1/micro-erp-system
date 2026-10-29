import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import HisbahLogo from "../components/HisbahLogo";
import OtpResend from "../components/OtpResend";
import { Field } from "../components/ui";
import { latinDigits } from "../lib/format";
import { maskPhone, normalizePhone, PHONE_HINT, otpSendError } from "../lib/phone";
import { resetPassword, sendOtp } from "../services/api";

/** A forgotten password: the mobile number, then the SMS code with a new password. */
export default function Forgot() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ phone: "", otp_code: "", password: "", password_confirmation: "" });
  const [sent, setSent] = useState(null);
  const [errors, setErrors] = useState({});
  const [banner, setBanner] = useState(null);
  const [busy, setBusy] = useState(false);
  const set = (field) => (e) => {
    setForm({ ...form, [field]: field === "phone" || field === "otp_code" ? latinDigits(e.target.value) : e.target.value });
    setErrors((old) => ({ ...old, [field]: undefined }));
  };
  const fromServer = (error) => Object.fromEntries(Object.entries(error?.errors ?? {}).map(([k, v]) => [k, v?.[0]]));

  const send = async () => {
    const phone = normalizePhone(sent?.phone ?? form.phone);
    if (!phone) return setErrors({ phone: form.phone.trim() ? PHONE_HINT : "اكتب رقم جوالك." });
    setBusy(true);
    setBanner(null);
    try {
      const wait = await sendOtp(phone, "reset");
      setSent({ phone, availableAt: Date.now() + wait * 1000 });
    } catch (error) {
      if (error?.status === 422) setErrors(fromServer(error));
      else setBanner(otpSendError(error));
    } finally {
      setBusy(false);
    }
  };

  const save = async () => {
    const found = {};
    if (!/^\d{6}$/.test(form.otp_code.trim())) found.otp_code = "الرمز 6 أرقام.";
    if (form.password.length < 8) found.password = "كلمة المرور 8 أحرف على الأقل.";
    else if (form.password !== form.password_confirmation) found.password_confirmation = "تأكيد كلمة المرور لا يطابقها.";
    setErrors(found);
    if (Object.keys(found).length) return;
    setBusy(true);
    setBanner(null);
    try {
      await resetPassword({ phone: sent.phone, otp_code: form.otp_code.trim(), password: form.password, password_confirmation: form.password_confirmation });
      navigate(`/login?phone=${sent.phone}&reset=1`, { replace: true });
    } catch (error) {
      if (error?.status === 422) setErrors(fromServer(error));
      else setBanner(error?.message ?? "حدث خطأ في الخادم. أعد المحاولة بعد قليل.");
    } finally {
      setBusy(false);
    }
  };

  const submit = (e) => {
    e.preventDefault();
    if (!busy) (sent ? save : send)();
  };

  return (
    <div className="signin">
      <main className="signin-card" style={{ gridTemplateColumns: "minmax(0, 1fr)", maxWidth: 560, minHeight: 0 }}>
        <section className="signin-form">
          <header className="signin-top">
            <Link to="/" className="plain" aria-label="حسبة — الصفحة الرئيسية">
              <HisbahLogo size={30} />
            </Link>
            <Link to="/login" className="quiet-link">
              تسجيل الدخول
            </Link>
          </header>
          <div className="signin-body">
            <div>
              <h1 className="signin-title">استعادة كلمة المرور</h1>
              <p className="signin-sub">
                {sent ? (
                  <>
                    أرسلنا رمزاً من 6 أرقام برسالة إلى <b className="m">{maskPhone(sent.phone)}</b>.
                  </>
                ) : (
                  "اكتب رقم جوالك، ونرسل لك رمزاً برسالة لتختار كلمة مرور جديدة."
                )}
              </p>
            </div>
            {banner ? (
              <p role="alert" className="banner tone-error">
                {banner}
              </p>
            ) : null}
            <form className="form-stack" onSubmit={submit} noValidate>
              {!sent ? (
                <Field id="fp-phone" label="رقم الجوال" required error={errors.phone}>
                  <input id="fp-phone" type="tel" inputMode="tel" className="fld ltr" value={form.phone} onChange={set("phone")} autoComplete="tel" placeholder="0599123456" />
                </Field>
              ) : (
                <>
                  <Field id="fp-code" label="رمز التأكيد" required error={errors.otp_code}>
                    <input id="fp-code" inputMode="numeric" className="fld ltr" value={form.otp_code} onChange={set("otp_code")} autoComplete="one-time-code" maxLength={6} placeholder="6 أرقام" />
                  </Field>
                  <OtpResend availableAt={sent.availableAt} onResend={send} disabled={busy} />
                  <Field id="fp-pass" label="كلمة المرور الجديدة" required error={errors.password} hint="8 أحرف على الأقل. يُسجَّل الخروج من كل الأجهزة.">
                    <input id="fp-pass" type="password" className="fld ltr" value={form.password} onChange={set("password")} autoComplete="new-password" />
                  </Field>
                  <Field id="fp-pass2" label="تأكيد كلمة المرور الجديدة" required error={errors.password_confirmation}>
                    <input id="fp-pass2" type="password" className="fld ltr" value={form.password_confirmation} onChange={set("password_confirmation")} autoComplete="new-password" />
                  </Field>
                </>
              )}
              <button type="submit" className="btn btn-p" disabled={busy}>
                {busy ? "لحظة…" : sent ? "حفظ كلمة المرور الجديدة" : "أرسل الرمز"}
              </button>
            </form>
          </div>
        </section>
      </main>
    </div>
  );
}
