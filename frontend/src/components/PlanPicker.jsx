import { useState } from "react";
import Icon from "./Icon";
import { ErrorBanner } from "./ui";
import { dateOnly } from "../lib/format";
import { monthsLabel, ORDER_STATUS, useCreateOrder, useMyOrders, usePlans } from "../services/subscriptions";

/**
 * WEBSITE ONLY: the store owner picks a plan and asks for it. Prices come from the server. Online
 * payment appears only once a provider is enabled on the server; until then the WhatsApp request is
 * the way: it creates a pending request with a reference, and Hisbah activates the subscription only
 * after confirming the payment. (The Android app never shows this: Google Play consumption-only build.)
 */
export default function PlanPicker() {
  const plans = usePlans();
  const orders = useMyOrders();
  const create = useCreateOrder();
  const [last, setLast] = useState(null);
  const providers = Object.entries(plans.data?.meta?.online_providers ?? {});
  const features = plans.data?.meta?.features ?? {};

  const ask = (plan, channel, provider) =>
    create.mutate(
      { plan_id: plan.id, channel, provider },
      {
        onSuccess: (order) => {
          setLast(order);
          if (order.checkout_url) window.location.assign(order.checkout_url);
          else if (order.whatsapp_url) window.open(order.whatsapp_url, "_blank", "noopener,noreferrer");
        },
      },
    );

  if (plans.isPending) return <div className="sk" style={{ height: 120, borderRadius: 8 }} />;
  if (plans.isError) return <ErrorBanner error={plans.error} />;

  const list = plans.data?.data ?? [];
  const open = (orders.data ?? []).filter((o) => ["pending_contact", "awaiting_payment", "payment_verification"].includes(o.status));

  return (
    <div className="form-stack">
      {list.length === 0 ? (
        <p className="field-hint">لا توجد باقات متاحة للشراء حالياً. تواصل مع إدارة حسبة.</p>
      ) : (
        <div className="plan-grid" style={{ display: "grid", gap: 12, gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))" }}>
          {list.map((plan) => (
            <article key={plan.id} className="card panel" aria-labelledby={`plan-${plan.id}`} style={{ margin: 0 }}>
              <h3 id={`plan-${plan.id}`} style={{ margin: 0 }}>{plan.name}</h3>
              <p style={{ margin: "4px 0", fontWeight: 700 }}>
                <span className="m">{plan.price}</span> {plan.currency} · {monthsLabel(plan.duration_months)}
              </p>
              {plan.description ? <p className="field-hint">{plan.description}</p> : null}
              {plan.features.length ? (
                <ul className="field-hint" style={{ margin: "4px 0", paddingInlineStart: 18 }}>
                  {plan.features.map((f) => <li key={f}>{features[f] ?? f}</li>)}
                </ul>
              ) : null}
              <div className="form-stack" style={{ gap: 6 }}>
                {providers.map(([key, label]) => (
                  <button key={key} type="button" className="btn btn-p btn-sm" disabled={create.isPending} onClick={() => ask(plan, "online", key)}>
                    ادفع إلكترونياً ({label})
                  </button>
                ))}
                <button type="button" className="btn btn-s btn-sm" disabled={create.isPending} onClick={() => ask(plan, "manual_whatsapp")}>
                  <Icon name="mail" size={16} />
                  <span>لا تملك بطاقة دفع؟ تواصل معنا عبر واتساب</span>
                </button>
              </div>
            </article>
          ))}
        </div>
      )}

      {create.isError ? <ErrorBanner error={create.error} /> : null}
      {last && !last.checkout_url ? (
        <div className="note ok" role="status">
          <Icon name="check" size={18} />
          <span>
            سُجّل طلبك برقم <b className="m">{last.reference}</b>.{" "}
            {last.whatsapp_url ? (
              <>
                إن لم يفتح واتساب{" "}
                <a href={last.whatsapp_url} target="_blank" rel="noopener noreferrer">
                  اضغط هنا
                </a>
                .
              </>
            ) : (
              "اذكر هذا الرقم عند التواصل مع إدارة حسبة."
            )}{" "}
            يُفعَّل الاشتراك بعد تأكيد الدفع فقط.
          </span>
        </div>
      ) : null}

      {open.length ? (
        <div>
          <p className="field-hint" style={{ marginBottom: 4 }}>طلبات قيد المعالجة:</p>
          <ul style={{ margin: 0, paddingInlineStart: 18 }}>
            {open.map((o) => (
              <li key={o.id}>
                <b className="m">{o.reference}</b> · {o.plan?.name} · <span className="m">{o.amount}</span> {o.currency} ·{" "}
                {ORDER_STATUS[o.status]?.[0] ?? o.status} · {dateOnly(o.created_at)}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
}
