import { useEffect, useId, useRef } from "react";
import { createPortal } from "react-dom";
import { Link } from "react-router-dom";
import Icon from "./Icon";
import { shekel, shortReference } from "../lib/format";

// S3 shared components (W-06 … W-15, design board S3-Spec). Money and quantities come from the API
// as strings and are shown as isolated LTR runs, never through a float.

export const MoneyText = ({ value, className = "", ...rest }) => (
  <span className={`m ${className}`} {...rest}>
    {shekel(value)}
  </span>
);

const UNIT_LABEL = { kg: "كغ", piece: "" };

export const QtyText = ({ value, unit }) => (
  <span className="m">
    {value}
    {UNIT_LABEL[unit] ? ` ${UNIT_LABEL[unit]}` : ""}
  </span>
);

const BADGES = {
  paid: ["مدفوع", "ok"],
  active: ["فعّالة", "ok"],
  ok: ["متوفر", "ok"],
  unpaid: ["مفتوح", "pending"],
  partially_paid: ["مدفوع جزئياً", "partial"],
  partial: ["جزئي", "partial"],
  cash: ["نقدي", "ok"],
  credit: ["دين", "debt"],
  overdue: ["متأخر", "error"],
  due_today: ["مستحق اليوم", "info"],
  cancelled: ["ملغى", "voided"],
  voided: ["ملغاة", "voided"],
  reversed: ["معكوسة", "voided"],
  inactive: ["موقوف", "voided"],
  low: ["منخفض", "low"],
  out: ["نفد", "error"],
  negative: ["سالب", "error"],
};

const BADGE_ICON = { ok: "ok", error: "clock", low: "low", voided: "ban", info: "clock", pending: "dot", partial: "dot", debt: "dot" };

/** Status as text + colour + icon (never colour alone). */
export function StatusBadge({ status, label, children }) {
  const [text, tone] = BADGES[status] ?? [status, "pending"];
  return (
    <span className={`pill tone-${tone}`}>
      <Icon name={BADGE_ICON[tone] ?? "dot"} size={14} strokeWidth={2.2} />
      {label ?? text}
      {children}
    </span>
  );
}

export function PageHeader({ title, sub, children }) {
  return (
    <header className="page-head">
      <div>
        <h1>{title}</h1>
        {sub ? <p className="sub">{sub}</p> : null}
      </div>
      {children ? <div className="head-actions">{children}</div> : null}
    </header>
  );
}

export function Crumbs({ items }) {
  return (
    <nav aria-label="مسار التنقل" className="crumbs">
      {items.map(([label, to], i) => (
        <span key={label}>
          {i > 0 ? " / " : ""}
          {to ? <Link to={to}>{label}</Link> : label}
        </span>
      ))}
    </nav>
  );
}

/** Segmented filter: `options` = [[value, label, count?]]. */
export function Segments({ label, value, options, onChange }) {
  return (
    <div className="segs" role="group" aria-label={label}>
      {options.map(([key, text, count]) => (
        <button key={key} type="button" className="seg" aria-pressed={value === key} onClick={() => onChange(key)}>
          {text}
          {count !== undefined && count !== null ? <span className="m seg-count"> {count}</span> : null}
        </button>
      ))}
    </div>
  );
}

/** Error card with the support reference (US-0106) and a retry. */
export function ErrorState({ error, title = "تعذّر تحميل البيانات", onRetry }) {
  const ref = shortReference(error?.correlationId);
  return (
    <div role="alert" className="card state-card">
      <Icon name="alert" size={40} color="var(--error-fg)" strokeWidth={1.8} />
      <b className="state-title">{title}</b>
      <span className="state-text">
        {error?.message ?? "تحقق من الاتصال ثم أعد المحاولة."}
        {ref ? (
          <>
            {" "}
            رمز المرجع للدعم: <span className="m">{ref}</span>
          </>
        ) : null}
      </span>
      {onRetry ? (
        <button type="button" className="btn btn-p btn-sm" onClick={onRetry}>
          إعادة المحاولة
        </button>
      ) : null}
    </div>
  );
}

export function EmptyState({ icon = "info", title, text, children }) {
  return (
    <div className="card state-card">
      <Icon name={icon} size={40} color="var(--primary)" strokeWidth={1.6} />
      <b className="state-title">{title}</b>
      {text ? <span className="state-text">{text}</span> : null}
      {children}
    </div>
  );
}

/**
 * A table with its loading, error and empty states. `columns` = [{ key, label, numeric, render }].
 */
export function DataTable({ query, rows, columns, caption, empty, minWidth = 720, rowKey = (r) => r.id }) {
  if (query.isError && !query.data) return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  const loading = query.isPending;
  if (!loading && rows.length === 0) return empty;
  return (
    <div className="card table-wrap" aria-busy={loading || query.isFetching}>
      <table style={{ minWidth }}>
        {caption ? <caption className="sr-only">{caption}</caption> : null}
        <thead>
          <tr>
            {columns.map((c) => (
              <th key={c.key} scope="col" className={c.numeric ? "n" : undefined}>
                {c.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading
            ? [0, 1, 2, 3, 4].map((i) => (
                <tr key={i}>
                  {columns.map((c) => (
                    <td key={c.key}>
                      <span className="sk" style={{ height: 14, width: c.numeric ? 70 : `${50 + ((i * 7) % 30)}%`, marginInlineStart: c.numeric ? "auto" : 0 }} />
                    </td>
                  ))}
                </tr>
              ))
            : rows.map((row) => (
                <tr key={rowKey(row)} className={row.__class}>
                  {columns.map((c) => (
                    <td key={c.key} className={c.numeric ? "n" : undefined}>
                      {c.render ? c.render(row) : row[c.key]}
                    </td>
                  ))}
                </tr>
              ))}
        </tbody>
      </table>
    </div>
  );
}

export function Pager({ meta, onPage }) {
  if (!meta || meta.last_page <= 1) return null;
  return (
    <div className="pager">
      <button type="button" className="btn btn-g btn-sm" disabled={meta.current_page <= 1} onClick={() => onPage(meta.current_page - 1)}>
        السابق
      </button>
      <span className="m">
        {meta.current_page} / {meta.last_page}
      </span>
      <button type="button" className="btn btn-g btn-sm" disabled={meta.current_page >= meta.last_page} onClick={() => onPage(meta.current_page + 1)}>
        التالي
      </button>
    </div>
  );
}

const DIALOG_ICON = { danger: "alert", warning: "alert", success: "ok", info: "info" };
const FOCUSABLE = 'a[href], button:not(:disabled), input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex="-1"])';

/**
 * Modal dialog, rendered into <body> so no transformed ancestor can trap it inside the page.
 * A confirmation (role="alertdialog") opens with a tone badge: danger (cannot be undone), warning
 * (reversible stop), success (turning something on) or info. Focus moves to the first field, or to
 * the first action, stays inside while open, and returns to the opener; Escape and the scrim close it.
 */
export function Dialog({ title, onClose, children, role = "dialog", wide = false, tone, icon }) {
  const titleId = useId();
  const box = useRef(null);
  const close = useRef(onClose);
  close.current = onClose;
  const alert = role === "alertdialog";
  const badge = tone ?? (alert ? "warning" : null);

  useEffect(() => {
    const opener = document.activeElement;
    const el = box.current;
    (el?.querySelector(".dlg-body :is(input, select, textarea):not(:disabled)") ?? el?.querySelector(".dlg-actions button:not(:disabled)") ?? el)?.focus();
    const onKey = (e) => {
      if (e.key === "Escape") return close.current();
      if (e.key !== "Tab" || !el) return;
      const items = [...el.querySelectorAll(FOCUSABLE)];
      if (items.length === 0) return;
      const target = e.shiftKey ? items[items.length - 1] : items[0];
      const edge = e.shiftKey ? items[0] : items[items.length - 1];
      if (document.activeElement === edge || !el.contains(document.activeElement)) {
        e.preventDefault();
        target.focus();
      }
    };
    const scroll = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = scroll;
      opener?.focus?.();
    };
  }, []);

  return createPortal(
    <div className="scrim" onMouseDown={(e) => e.target === e.currentTarget && close.current()}>
      <div
        ref={box}
        tabIndex={-1}
        className={`dlg${wide ? " wide" : ""}${alert ? " is-alert" : ""}${badge ? ` tone-${badge}` : ""}`}
        role={role}
        aria-modal="true"
        aria-labelledby={titleId}
      >
        <div className="dlg-head">
          {badge ? (
            <span className="dlg-badge" aria-hidden="true">
              <Icon name={icon ?? DIALOG_ICON[badge]} size={28} strokeWidth={2.2} />
            </span>
          ) : null}
          <h2 id={titleId} className="dlg-title">
            {title}
          </h2>
          <button type="button" className="dlg-close" aria-label="إغلاق" onClick={() => close.current()}>
            <Icon name="close" size={20} />
          </button>
        </div>
        <div className="dlg-body">{children}</div>
      </div>
    </div>,
    document.body,
  );
}

/** Before → change → after, shown before every financial write. */
export function ConfirmSummary({ rows, total }) {
  return (
    <div className="sum" aria-live="polite">
      {rows.map(([label, value]) => (
        <div key={label}>
          <span>{label}</span>
          <span className="m">{value}</span>
        </div>
      ))}
      {total ? (
        <div className="sum-total">
          <span>{total[0]}</span>
          <span className="m" style={{ color: total[2] }}>
            {total[1]}
          </span>
        </div>
      ) : null}
    </div>
  );
}

export function Field({ label, error, hint, optional, children, id }) {
  return (
    <div className="field">
      <label className="field-label" htmlFor={id}>
        {label} {optional ? <span className="opt">(اختياري)</span> : null}
      </label>
      {children}
      {error ? (
        <span className="field-error" id={`${id}-error`}>
          <Icon name="alert" size={16} />
          {error}
        </span>
      ) : hint ? (
        <span className="field-hint">{hint}</span>
      ) : null}
    </div>
  );
}

export function ReasonField({ id, value, onChange, error, label = "السبب" }) {
  return (
    <Field id={id} label={label} error={error}>
      <textarea
        id={id}
        className={`fld fld-area${error ? " err" : ""}`}
        rows={3}
        value={value}
        maxLength={500}
        onChange={(e) => onChange(e.target.value)}
        aria-invalid={Boolean(error)}
        aria-describedby={error ? `${id}-error` : undefined}
      />
    </Field>
  );
}

/** Form-level error banner from an ApiError / NetworkError. */
export function ErrorBanner({ error }) {
  if (!error) return null;
  const ref = shortReference(error.correlationId);
  return (
    <div role="alert" className="banner tone-error">
      <Icon name="alert" size={20} />
      <span>
        {error.message}
        {ref ? <span className="sub">رمز المرجع: {ref}</span> : null}
      </span>
    </div>
  );
}


