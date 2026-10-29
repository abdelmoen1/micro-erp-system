import { useEffect, useState } from "react";

/** «أرسل رمزاً جديداً», off with a countdown until `availableAt` (ms; the server's resend_in). */
export default function OtpResend({ availableAt, onResend, disabled }) {
  const [, tick] = useState(0);
  const left = Math.max(0, Math.ceil(((availableAt ?? 0) - Date.now()) / 1000));

  useEffect(() => {
    if (left === 0) return undefined;
    const timer = setInterval(() => tick((n) => n + 1), 1000);
    return () => clearInterval(timer);
  }, [availableAt, left === 0]); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <button type="button" className="btn btn-t" onClick={onResend} disabled={disabled || left > 0}>
      {left > 0 ? (
        <>
          رمز جديد بعد <span className="m">{left}</span> ث
        </>
      ) : (
        "أرسل رمزاً جديداً"
      )}
    </button>
  );
}

