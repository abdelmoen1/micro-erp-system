import { useEffect, useState } from "react";
import { Link, useSearchParams } from "react-router-dom";
import Banner, { Spinner } from "../components/Banner";
import HisbahLogo from "../components/HisbahLogo";
import { dateOnly } from "../lib/format";
import { normalizePhone, PHONE_HINT } from "../lib/phone";
import { getDeletionStatus, requestPublicDeletion } from "../services/subscriptions";

const STATUS = {
  pending_review: "قيد المراجعة: سنتحقق من صاحب الرقم ثم ننفّذ الحذف.",
  scheduled: "مجدول: سيُحذف المتجر وكل بياناته في التاريخ المحدد، ويمكن لصاحب المتجر الإلغاء قبله بتسجيل الدخول.",
  completed: "تم الحذف.",
  cancelled: "أُلغي الطلب.",
  rejected: "لم يُنفَّذ الطلب (لم نجد حساباً مطابقاً أو لم نتمكن من التحقق).",
};

/**
 * Public account deletion (Google Play: a web resource that works without the app). With the
 * password it does what the app does; without it, a request the Hisbah team verifies by hand.
 * A request number shows its status later. Nothing here reveals whether a number has an account.
 */
export default function DeleteAccount() {
  const [params] = useSearchParams();
  const [form, setForm] = useState({ phone: "", password: "", confirm_store_name: "", reason: "", no_password: false });
  const [state, setState] = useState({ busy: false, error: null, result: null });
  const [lookup, setLookup] = useState(params.get("done") ?? "");
  const [status, setStatus] = useState(null);
  const set = (key) => (e) => setForm((f) => ({ ...f, [key]: e.target.type === "checkbox" ? e.target.checked : e.target.value }));

  useEffect(() => {
    const ref = params.get("done");
    if (ref) getDeletionStatus(ref).then(setStatus).catch(() => setStatus(null));
  }, [params]);

  const submit = async (event) => {
    event.preventDefault();
    setState({ busy: true, error: null, result: null });
    try {
      const body = { ...form, phone: normalizePhone(form.phone) ?? form.phone };
      if (body.no_password) delete body.password;
      const response = await requestPublicDeletion(body);
      setState({ busy: false, error: null, result: response.data });
    } catch (error) {
      setState({ busy: false, error, result: null });
    }
  };

  const check = async (event) => {
    event.preventDefault();
    try {
      setStatus(await getDeletionStatus(lookup.trim()));
    } catch {
      setStatus({ status: "unknown" });
    }
  };

  const result = state.result;

  return (
    <div className="signin">
      <main className="signin-card" style={{ gridTemplateColumns: "1fr" }}>
        <section className="signin-form">
          <header className="signin-top">
            <HisbahLogo size={30} />
            <Link to="/" className="quiet-link">الصفحة الرئيسية</Link>
          </header>
          <div className="signin-body">
            <div>
              <h1 className="signin-title">حذف حساب حسبة</h1>
              <p className="signin-sub">بدون تطبيق وبدون تسجيل دخول.</p>
            </div>

            <div className="note">
              <span>
                <b>حساب موظف:</b> يُحذف الاسم ورقم الجوال وكلمة المرور ويُسجَّل الخروج من كل الأجهزة. تبقى عمليات المتجر التي سجّلها الموظف ضمن سجلات المتجر باسم «حساب محذوف».
                <br />
                <b>حساب صاحب المتجر:</b> يُغلق المتجر ويُسجَّل خروج الجميع، ثم يُحذف المتجر وكل بياناته بعد مهلة يمكن الإلغاء خلالها. تحتفظ حسبة بسجل مدفوعات الاشتراك التي دفعتها لحسبة لأنها سجلات مبيعات حسبة نفسها.
              </span>
            </div>

            {result ? (
              <Banner tone="ok" icon="check">
                رقم الطلب: <b className="m">{result.reference}</b> — {STATUS[result.status] ?? result.status}
                {result.scheduled_for ? ` (${dateOnly(result.scheduled_for)})` : ""}
              </Banner>
            ) : (
              <form className="form-stack" onSubmit={submit} noValidate>
                {state.error ? <Banner>{state.error.message}</Banner> : null}
                <label className="fld-label" htmlFor="del-phone">رقم الجوال المسجّل</label>
                <input id="del-phone" className="fld m" dir="ltr" inputMode="tel" autoComplete="tel" value={form.phone} onChange={set("phone")} placeholder="05XXXXXXXX" aria-describedby="del-phone-hint" />
                <small id="del-phone-hint" className="field-hint">{PHONE_HINT}</small>

                <label style={{ display: "flex", gap: 8, alignItems: "center" }}>
                  <input type="checkbox" checked={form.no_password} onChange={set("no_password")} />
                  <span>لا أتذكر كلمة المرور (سنتحقق منك يدوياً قبل الحذف)</span>
                </label>

                {!form.no_password ? (
                  <>
                    <label className="fld-label" htmlFor="del-pass">كلمة المرور</label>
                    <input id="del-pass" type="password" className="fld" autoComplete="current-password" value={form.password} onChange={set("password")} />
                    <label className="fld-label" htmlFor="del-store">اسم المتجر (لصاحب المتجر فقط، للتأكيد)</label>
                    <input id="del-store" className="fld" value={form.confirm_store_name} onChange={set("confirm_store_name")} />
                  </>
                ) : null}

                <label className="fld-label" htmlFor="del-reason">سبب الحذف (اختياري)</label>
                <textarea id="del-reason" className="fld" rows={2} maxLength={1000} value={form.reason} onChange={set("reason")} />

                <button type="submit" className="btn btn-dd" disabled={state.busy || !form.phone || (!form.no_password && !form.password)}>
                  {state.busy ? <Spinner /> : null}
                  <span>اطلب حذف الحساب</span>
                </button>
              </form>
            )}

            <form className="form-stack" onSubmit={check} aria-label="حالة طلب حذف">
              <label className="fld-label" htmlFor="del-ref">لديك رقم طلب؟ اعرف حالته</label>
              <input id="del-ref" className="fld m" dir="ltr" value={lookup} onChange={(e) => setLookup(e.target.value)} />
              <button type="submit" className="btn btn-g btn-sm" disabled={!lookup.trim()}>عرض الحالة</button>
              {status ? (
                <p role="status" className="field-hint">
                  {status.status === "unknown" ? "لم نجد طلباً بهذا الرقم." : STATUS[status.status] ?? status.status}
                  {status.scheduled_for ? ` (${dateOnly(status.scheduled_for)})` : ""}
                </p>
              ) : null}
            </form>
          </div>
        </section>
      </main>
    </div>
  );
}
