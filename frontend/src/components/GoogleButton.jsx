import { useEffect, useRef, useState } from "react";
import { GOOGLE_CLIENT_ID } from "../lib/google";

// Google Identity Services. The button is Google's own (brand rules); it hands back an ID token
// that the API verifies (POST /auth/google). Without VITE_GOOGLE_CLIENT_ID nothing renders.
const SCRIPT_URL = "https://accounts.google.com/gsi/client";

let scriptPromise;
function loadScript() {
  scriptPromise ??= new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = SCRIPT_URL;
    script.async = true;
    script.onload = resolve;
    script.onerror = () => {
      scriptPromise = undefined;
      reject(new Error("gsi"));
    };
    document.head.appendChild(script);
  });
  return scriptPromise;
}

/** Renders «المتابعة باستخدام Google»; onCredential(idToken) runs after the user picks an account. */
export default function GoogleButton({ onCredential, text = "continue_with", disabled = false }) {
  const slot = useRef(null);
  const callback = useRef(onCredential);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    callback.current = onCredential;
  }, [onCredential]);

  useEffect(() => {
    if (!GOOGLE_CLIENT_ID) return undefined;
    let live = true;
    loadScript()
      .then(() => {
        if (!live || !slot.current) return;
        const id = window.google.accounts.id;
        id.initialize({ client_id: GOOGLE_CLIENT_ID, callback: (r) => callback.current(r.credential), ux_mode: "popup" });
        id.renderButton(slot.current, {
          theme: "outline",
          size: "large",
          shape: "rectangular",
          text,
          locale: "ar",
          width: Math.min(slot.current.offsetWidth || 400, 400),
        });
      })
      .catch(() => live && setFailed(true));
    return () => {
      live = false;
    };
  }, [text]);

  if (!GOOGLE_CLIENT_ID) return null;
  if (failed) return <p className="sso-note">تعذّر تحميل زر Google. تحقق من الإنترنت، أو تابع بالبريد الإلكتروني.</p>;
  return <div ref={slot} className="sso-slot" aria-disabled={disabled || undefined} />;
}
