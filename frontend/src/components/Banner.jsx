import Icon from "./Icon";

/** Form-level message (W-01 / W-02): icon, text and a status tone; colour is never the only carrier. */
export default function Banner({ tone = "error", icon = "alert", children, extra }) {
  return (
    <div role="alert" className={`banner tone-${tone}`}>
      <Icon name={icon} size={20} />
      <div>
        {children}
        {extra}
      </div>
    </div>
  );
}

export function Spinner() {
  return <Icon name="spinner" size={20} color="var(--disabled-ink)" strokeWidth={2.4} className="spin" />;
}

export function FieldError({ id, children }) {
  return children ? (
    <span id={id} className="field-error">
      <Icon name="alert" size={16} strokeWidth={2.2} />
      {children}
    </span>
  ) : null;
}
