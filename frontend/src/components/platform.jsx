import { useState } from "react";
import { Dialog, ErrorBanner, ReasonField, StatusBadge } from "./ui";
import { ACCESS, SUBSCRIPTION } from "../lib/platform";
import { useSetStoreStatus } from "../services/admin";

// Badges for the two separate store states (text + colour + icon, never colour alone).

export const AccessBadge = ({ status }) => <StatusBadge status={ACCESS[status]?.badge ?? status} label={ACCESS[status]?.label ?? status} />;

export const SubscriptionBadge = ({ state }) => <StatusBadge status={SUBSCRIPTION[state]?.badge ?? state} label={SUBSCRIPTION[state]?.label ?? state} />;

/**
 * Account access as a switch. Switching on reactivates at once; switching off asks first
 * (AccessDialog), because it signs the owner and every employee out immediately.
 */
export function AccessSwitch({ store, compact = false }) {
  const save = useSetStoreStatus();
  const [confirming, setConfirming] = useState(false);
  const on = store.status !== "suspended";
  const busy = save.isPending;

  const toggle = () => {
    if (busy) return;
    if (on) setConfirming(true);
    else save.mutate({ id: store.id, status: "active" });
  };

  return (
    <span className={`access-switch${compact ? " compact" : ""}`}>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-busy={busy}
        aria-label={`حساب ${store.name}`}
        className={`switch${on ? " on" : ""}`}
        disabled={busy}
        onClick={toggle}
      >
        <span className="switch-knob" aria-hidden="true" />
      </button>
      <span className="switch-text" aria-hidden="true">
        {busy ? "جارٍ الحفظ…" : on ? "مفعّل" : "موقوف"}
      </span>
      {save.error && !confirming ? (
        <span role="alert" className="switch-error">
          {save.error.message}
        </span>
      ) : null}
      {confirming ? <AccessDialog store={store} onClose={() => setConfirming(false)} /> : null}
    </span>
  );
}

/** Suspend (with an optional reason) or reactivate one store's account. */
export function AccessDialog({ store, onClose }) {
  const save = useSetStoreStatus();
  const [reason, setReason] = useState("");
  const suspending = store.status !== "suspended";
  const submit = () =>
    save.mutate({ id: store.id, status: suspending ? "suspended" : "active", ...(suspending && reason.trim() ? { reason: reason.trim() } : {}) }, { onSuccess: onClose });

  return (
    <Dialog title={suspending ? `إيقاف حساب ${store.name}؟` : `تفعيل حساب ${store.name}؟`} role="alertdialog" tone={suspending ? "warning" : "success"} icon={suspending ? "ban" : "ok"} onClose={onClose}>
      <p>
        {suspending
          ? "يُمنع المالك وكل الموظفين من الدخول فوراً، وتتوقف جلساتهم المفتوحة. لا تُحذف أي بيانات، والاشتراك يبقى كما هو."
          : "يعود المالك والموظفون إلى الدخول والعمل فوراً. الاشتراك يبقى كما هو."}
      </p>
      {suspending ? <ReasonField id="suspend-reason" label="السبب (يظهر في سجل التغييرات)" value={reason} onChange={setReason} error={save.error?.fieldError?.("reason")} /> : null}
      <ErrorBanner error={save.error} />
      <div className="dlg-actions">
        <button type="button" className={`btn ${suspending ? "btn-dd" : "btn-p"}`} disabled={save.isPending} onClick={submit}>
          {save.isPending ? "جارٍ الحفظ…" : suspending ? "إيقاف الحساب" : "تفعيل الحساب"}
        </button>
        <button type="button" className="btn btn-g" onClick={onClose}>
          رجوع
        </button>
      </div>
    </Dialog>
  );
}
