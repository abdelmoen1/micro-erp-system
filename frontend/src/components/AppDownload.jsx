import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import Icon from "./Icon";
import { Dialog } from "./ui";
import { session } from "../services/apiClient";

// The Android app is published as a GitHub release (the mobile release workflow attaches the APK).
// The newest published release is read at runtime, so a new APK needs no web deploy. Installed apps
// then keep themselves current with over-the-air patches.
const REPO = "abdelmoen1/micro-erp-system";
// GitHub redirects this to the newest published release's hisbah.apk (attached by every release),
// so the button serves the latest APK even when the API below cannot be read (rate limit, offline).
const LATEST_APK = `https://github.com/${REPO}/releases/latest/download/hisbah.apk`;

/** { url, version, sizeMb } of the newest published APK; the releases page when it cannot be read. */
function useLatestApk() {
  return useQuery({
    queryKey: ["latest-apk"],
    staleTime: 60_000,
    retry: 1,
    queryFn: async ({ signal }) => {
      const response = await fetch(`https://api.github.com/repos/${REPO}/releases/latest`, { signal, cache: "no-store", headers: { Accept: "application/vnd.github+json" } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const release = await response.json();
      // The versioned file (hisbah-1.2.0_4.apk) names the download after its version.
      const assets = (release.assets ?? []).filter((asset) => asset.name.endsWith(".apk"));
      const apk = assets.find((asset) => asset.name !== "hisbah.apk") ?? assets[0];
      if (!apk) throw new Error("no apk");
      // Tags look like android-1.1.0_3: version 1.1.0, build 3.
      const version = release.tag_name.replace(/^android-/, "").replace("_", "+");
      return { url: apk.browser_download_url, version, sizeMb: Math.round(apk.size / 1_000_000) };
    },
  });
}

function DownloadButton({ apk, className = "btn btn-p" }) {
  return (
    <a className={className} href={apk.data?.url ?? LATEST_APK} rel="noopener noreferrer" download>
      <Icon name="download" size={18} />
      تنزيل التطبيق
      {apk.data ? <span className="app-dl-size m">{apk.data.sizeMb} MB</span> : null}
    </a>
  );
}

const STEPS = [
  ["نزّل التطبيق", "من متصفح جوال أندرويد."],
  ["اسمح بالتثبيت", "وافق على التثبيت من هذا المصدر."],
  ["ادخل بنفس حسابك", "نفس رقم الجوال وكلمة المرور."],
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

const hiddenKey = () => `hisbah.appCard.hidden.${session.user()?.id ?? "anon"}`;

function readHidden() {
  try {
    return localStorage.getItem(hiddenKey()) !== null;
  } catch {
    return false;
  }
}

/** On the landing page: the same download and steps as the dashboard, for anyone. */
export function AppDownloadSection() {
  const apk = useLatestApk();
  return (
    <section id="app" className="lp-app" aria-labelledby="app-t" data-reveal>
      <div className="lp-wrap">
        <p className="lp-kicker">تطبيق الجوال</p>
        <h2 id="app-t">حمّل حسبة على جوالك</h2>
        <p className="lp-text">
          أندرويد{apk.data ? <> <span className="m">{apk.data.version.split("+")[0]}</span></> : null}. البيع والدين والمخزون من الجوال.
        </p>
        <Steps />
        <DownloadButton apk={apk} className="lp-btn solid big" />
      </div>
    </section>
  );
}

/** On the dashboard: the app, its version and how to install it. «إخفاء» folds it to one line. */
export function AppDownloadCard() {
  const apk = useLatestApk();
  const [hidden, setHidden] = useState(readHidden);
  const toggle = (hide) => {
    try {
      if (hide) localStorage.setItem(hiddenKey(), "1");
      else localStorage.removeItem(hiddenKey());
    } catch {
      // Private mode: the choice lasts until the page reloads.
    }
    setHidden(hide);
  };

  if (hidden) {
    return (
      <section className="card app-card app-card-folded" aria-label="تطبيق حسبة على الجوال">
        <Icon name="phone" size={20} strokeWidth={1.8} />
        <span>تطبيق حسبة على الجوال</span>
        <button type="button" className="btn btn-t btn-sm" onClick={() => toggle(false)}>
          إظهار
        </button>
      </section>
    );
  }

  return (
    <section className="card panel app-card" aria-labelledby="app-card-title">
      <div className="app-card-head">
        <span className="app-card-ic" aria-hidden="true">
          <Icon name="phone" size={24} strokeWidth={1.8} />
        </span>
        <span>
          <h2 id="app-card-title">تطبيق حسبة على الجوال</h2>
          <small>
            البيع بالباركود من الجوال، وكل شيء يصل هنا فوراً
            {apk.data ? (
              <>
                {" · "}أندرويد <span className="m">{apk.data.version.split("+")[0]}</span>
              </>
            ) : null}
          </small>
        </span>
        <button type="button" className="app-card-hide" onClick={() => toggle(true)} aria-label="إخفاء" title="إخفاء">
          <Icon name="close" size={18} />
        </button>
      </div>
      <div className="app-card-body">
        <Steps />
        <DownloadButton apk={apk} className="btn btn-p app-dl" />
      </div>
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
