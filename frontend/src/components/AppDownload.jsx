import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import Icon from "./Icon";
import { Dialog } from "./ui";
import { session } from "../services/apiClient";

// The Android app is published as a GitHub release (the mobile release workflow attaches the APK).
// The newest published release is read at runtime, so a new APK needs no web deploy. Installed apps
// then keep themselves current with over-the-air patches.
const REPO = "abdelmoen1/micro-erp-system";
const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;

/** { url, version, sizeMb } of the newest published APK; the releases page when it cannot be read. */
function useLatestApk() {
  return useQuery({
    queryKey: ["latest-apk"],
    staleTime: 10 * 60_000,
    retry: 1,
    queryFn: async ({ signal }) => {
      const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { signal, headers: { Accept: "application/vnd.github+json" } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const release = await response.json();
      const apk = (release.assets ?? []).find((asset) => asset.name.endsWith(".apk"));
      if (!apk) throw new Error("no apk");
      // Tags look like android-1.1.0_3: version 1.1.0, build 3.
      const version = release.tag_name.replace(/^android-/, "").replace("_", "+");
      return { url: apk.browser_download_url, version, sizeMb: Math.round(apk.size / 1_000_000) };
    },
  });
}

function DownloadButton({ apk, className = "btn btn-p" }) {
  return (
    <a className={className} href={apk.data?.url ?? RELEASES_PAGE} rel="noopener noreferrer" download={apk.data ? "" : undefined}>
      <Icon name="download" size={18} />
      تنزيل التطبيق
      {apk.data ? <span className="m"> ({apk.data.sizeMb} MB)</span> : null}
    </a>
  );
}

const STEPS = [
  ["نزّل التطبيق على جوالك", "افتح هذه الصفحة من متصفح جوال أندرويد واضغط «تنزيل التطبيق»."],
  ["اسمح بالتثبيت", "عند فتح الملف يسألك أندرويد عن السماح بالتثبيت من هذا المصدر؛ اسمح ثم اضغط «تثبيت»."],
  ["ادخل بنفس حسابك", "افتح حسبة وادخل ببريدك وكلمة مرورك هنا، وسيأخذك «دليل الاستخدام» لإضافة أول منتج وعمل أول فاتورة بالباركود."],
];

function Steps() {
  return (
    <ol className="app-steps">
      {STEPS.map(([title, text], i) => (
        <li key={title}>
          <span className="app-step-n" aria-hidden="true">
            {i + 1}
          </span>
          <span>
            <b>{title}</b>
            <small>{text}</small>
          </span>
        </li>
      ))}
    </ol>
  );
}

/** On the dashboard: the app, its version and how to install it. */
export function AppDownloadCard() {
  const apk = useLatestApk();
  return (
    <section className="card panel app-card" aria-labelledby="app-card-title">
      <div className="app-card-head">
        <span className="app-card-ic" aria-hidden="true">
          <Icon name="phone" size={26} strokeWidth={1.8} />
        </span>
        <span>
          <h2 id="app-card-title">تطبيق حسبة على الجوال</h2>
          <small>
            البيع بالباركود من الجوال، وكل شيء يصل هنا فوراً.
            {apk.data ? (
              <>
                {" "}
                آخر نسخة <span className="m">{apk.data.version}</span> لأندرويد.
              </>
            ) : null}
          </small>
        </span>
        <DownloadButton apk={apk} />
      </div>
      <Steps />
    </section>
  );
}

const seenKey = () => `hisbah.appGuide.${session.user()?.id ?? "anon"}`;

function readSeen() {
  try {
    return localStorage.getItem(seenKey()) !== null;
  } catch {
    return true;
  }
}

/** First visit to the back office: start by putting the app on the phone. Shown once per account. */
export function AppGuideDialog() {
  const [open, setOpen] = useState(() => !readSeen());
  const apk = useLatestApk();
  if (!open) return null;
  const close = () => {
    try {
      localStorage.setItem(seenKey(), new Date().toISOString());
    } catch {
      // Private mode: the dialog may show again next time.
    }
    setOpen(false);
  };
  return (
    <Dialog title="ابدأ بتطبيق حسبة على جوالك" icon="phone" onClose={close}>
      <p style={{ marginTop: 0 }}>البيع اليومي بالباركود يكون من الجوال، وهذه اللوحة لمتابعة المبيعات والديون والمخزون. ثلاث خطوات:</p>
      <Steps />
      <div className="dlg-actions">
        <DownloadButton apk={apk} />
        <button type="button" className="btn btn-g" onClick={close}>
          لاحقاً
        </button>
      </div>
    </Dialog>
  );
}
