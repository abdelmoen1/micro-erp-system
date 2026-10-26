import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Link, Navigate, useNavigate } from "react-router-dom";
import Banner, { Spinner } from "../components/Banner";
import HisbahLogo, { HisbahMark } from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { dateOnly } from "../lib/format";
import { session } from "../services/apiClient";
import { logout, useSubscription } from "../services/dashboard";

/** wa.me link with a prefilled request naming the store and the account. */
function whatsappLink(number, user) {
  const text = `مرحباً، أريد تفعيل اشتراك متجر «${user?.store?.name ?? ""}» على حسبة.\nالبريد: ${user?.email ?? ""}`;
  return `https://wa.me/${number}?text=${encodeURIComponent(text)}`;
}

/**
 * Without a support number the owner still has to say which store to activate: the store and the
 * account email, ready to copy into any message.
 */
function ContactDetails({ user }) {
  const [copied, setCopied] = useState(false);
  const text = `المتجر: ${user.store?.name ?? ""}\nالبريد: ${user.email ?? ""}`;
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
    } catch {
      setCopied(false); // The details stay selectable on the page.
    }
  };
  return (
    <div className="contact-details">
      <p className="field-hint">اذكر هذه البيانات عند التواصل:</p>
      <p className="contact-lines">
        المتجر: <b>{user.store?.name}</b>
        <br />
        البريد: <b className="ltr-inline">{user.email}</b>
      </p>
      <button type="button" className="btn btn-g btn-sm" onClick={copy}>
        <Icon name={copied ? "check" : "copy"} size={16} />
        <span>{copied ? "نُسخت البيانات" : "نسخ البيانات"}</span>
      </button>
      <span role="status" className="sr-only">
        {copied ? "نُسخت البيانات." : ""}
      </span>
    </div>
  );
}

/**
 * The renewal screen: the store's trial or paid subscription has ended. The session is kept and the
 * data is untouched; every business call is refused by the server (403 SUBSCRIPTION_EXPIRED) until
 * the platform admin activates the subscription. "Check again" returns to the dashboard once it is.
 */
export default function SubscriptionExpired() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const sub = useSubscription();
  const [checked, setChecked] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const user = session.user();

  if (sub.data?.has_access) return <Navigate to="/dashboard" replace />;

  const paid = sub.data?.state === "expired";
  const endedOn = paid ? sub.data?.subscription_expires_at : sub.data?.trial_ends_at;
  const number = sub.data?.support_whatsapp;

  const checkAgain = async () => {
    setChecked(false);
    const result = await sub.refetch();
    if (result.data?.has_access) {
      queryClient.clear();
      navigate("/dashboard", { replace: true });
    } else {
      setChecked(true);
    }
  };

  const signOut = async () => {
    setLeaving(true);
    await logout();
    queryClient.clear();
    navigate("/login", { replace: true });
  };

  return (
    <div className="signin">
      <main className="signin-card">
        <section className="signin-form">
          <header className="signin-top">
            <HisbahLogo size={30} />
            <button type="button" className="quiet-link ic" onClick={signOut} disabled={leaving}>
              تسجيل الخروج
            </button>
          </header>

          <div className="signin-body">
            <div>
              <h1 className="signin-title">{paid ? "انتهى اشتراك متجرك" : "انتهت الفترة التجريبية"}</h1>
              <p className="signin-sub">
                {user?.store?.name ? `متجر «${user.store.name}»` : "متجرك"}
                {endedOn ? `، انتهت في ${dateOnly(endedOn)}` : ""}
              </p>
            </div>

            {sub.isError ? <Banner>{sub.error?.message ?? "تعذّر التحقق من الاشتراك. أعد المحاولة."}</Banner> : null}
            {checked && !sub.isError ? (
              <Banner tone="pending" icon="clock">
                لم يُفعَّل الاشتراك بعد. بعد تأكيد الدفع من إدارة حسبة اضغط «تحقق من جديد».
              </Banner>
            ) : null}

            <div className="note ok">
              <Icon name="lock" size={18} />
              <span>بياناتك محفوظة كما هي: الزبائن والديون والمبيعات والمنتجات. يعود كل شيء فور تفعيل الاشتراك.</span>
            </div>

            {number ? (
              <a className="btn btn-p" href={whatsappLink(number, user)} target="_blank" rel="noopener noreferrer">
                تواصل معنا عبر واتساب
              </a>
            ) : sub.isPending ? null : (
              // Only once the summary has answered: a support number may still be on its way.
              <>
                <p className="signin-sub">تواصل مع إدارة حسبة لتفعيل الاشتراك.</p>
                {user ? <ContactDetails user={user} /> : null}
              </>
            )}
            <p className="field-hint">بعد الدفع تفعّل إدارة حسبة اشتراكك، ثم اضغط «تحقق من جديد» لتعود إلى متجرك.</p>

            <button type="button" className="btn btn-ghost" onClick={checkAgain} disabled={sub.isFetching} aria-busy={sub.isFetching}>
              {sub.isFetching ? <Spinner /> : null}
              <span>{sub.isFetching ? "جارٍ التحقق…" : "تحقق من جديد"}</span>
            </button>
          </div>

          <footer className="signin-foot">
            <span className="m">© 2026 حسبة</span>
            <Link to="/" className="quiet-link">
              الصفحة الرئيسية
            </Link>
          </footer>
        </section>

        <aside className="signin-panel" aria-hidden="true">
          <p className="panel-crumb">حسبة / الاشتراك</p>
          <HisbahMark size={210} className="panel-mark" />
          <div>
            <p className="panel-kicker">بياناتك بأمان</p>
            <p className="panel-title">
              فعّل الاشتراك
              <br />
              وتابع من حيث توقفت.
            </p>
          </div>
        </aside>
      </main>
    </div>
  );
}
