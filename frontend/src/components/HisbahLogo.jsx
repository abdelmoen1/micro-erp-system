/**
 * The Hisbah mark (docs/design/assets/brand): a geometric ح closed by a thinner rule — the double
 * underline under a final total — and the Arabic wordmark. One colour (currentColor), so the same
 * drawing is the brand (teal on ivory) and the reversed version (ivory on deep teal).
 */
export function HisbahMark({ size = 40, className }) {
  return (
    <svg width={size} height={size} viewBox="0 0 100 100" className={className} aria-hidden="true" focusable="false">
      <g fill="none" stroke="currentColor" strokeLinecap="butt" strokeLinejoin="miter">
        <path d="M78 20H22M58 20C46 28 29 38 29 48C29 60 38 68 52 68H78" strokeWidth="13" />
        <path d="M52 83H78" strokeWidth="5" />
      </g>
    </svg>
  );
}

export default function HisbahLogo({ size = 40, className = "" }) {
  return (
    <span className={`logo ${className}`} role="img" aria-label="حسبة">
      <HisbahMark size={size} />
      <span className="logo-word" style={{ fontSize: size * 0.62 }} aria-hidden="true">
        حسبة
      </span>
    </span>
  );
}
