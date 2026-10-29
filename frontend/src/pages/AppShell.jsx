import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { NavLink, Outlet, useNavigate } from "react-router-dom";
import HisbahLogo from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { canManage } from "../lib/domain";
import { initialOf } from "../lib/format";
import { session } from "../services/apiClient";
import { useSyncConflicts } from "../services/backoffice";
import { logout } from "../services/dashboard";

const ROLE_LABEL = { owner: "مالك المتجر", manager: "مدير", employee: "موظف" };

// W-04 navigation (S3: every back-office screen is live). Staff is the owner's only.
const NAV = [
  { label: "الرئيسية", icon: "home", to: "/dashboard" },
  { label: "المبيعات", icon: "sales", to: "/sales" },
  { label: "الزبائن", icon: "customers", to: "/customers" },
  { label: "البضاعة", icon: "products", to: "/products" },
  { label: "الديون", icon: "debts", to: "/debts" },
  { label: "المدفوعات", icon: "payments", to: "/payments" },
  { label: "الموظفون", icon: "staff", to: "/staff", ownerOnly: true },
  // R2: what the phones sent offline and the server held or flagged (SCR-W-18).
  { label: "مراجعة المزامنة", icon: "upload", to: "/sync", managerOnly: true, count: true },
  { label: "الإعدادات", icon: "settings", to: "/settings" },
];

/** SCR-W-04 · application shell: white RTL sidebar, top bar and the canvas. */
export default function AppShell() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const user = session.user() ?? {};
  const role = user.role ?? "employee";
  const manager = canManage(user);
  // One small page just for the badge; employees never ask (the endpoint is Owner / Manager only).
  const syncOpen = useSyncConflicts({ status: "open", per_page: 1 }, manager);
  const openSync = syncOpen.data?.open_count ?? 0;

  const signOut = async () => {
    setLeaving(true);
    await logout();
    queryClient.clear();
    navigate("/login", { replace: true });
  };

  return (
    <div className={open ? "shell nav-open" : "shell"}>
      <a href="#main" className="skip-link">
        تخطَّ إلى المحتوى
      </a>
      <aside className="side" aria-label="القائمة الجانبية">
        <div className="side-top">
          <NavLink to="/dashboard" className="side-brand" aria-label="حسبة — الرئيسية">
            <HisbahLogo size={30} />
          </NavLink>
          <button type="button" className="menubtn ic" onClick={() => setOpen((o) => !o)} aria-expanded={open} aria-controls="w5-nav" aria-label="القائمة">
            <Icon name="menu" size={20} />
          </button>
        </div>
        <div className="navwrap">
          <nav id="w5-nav" className="nav" aria-label="القائمة الرئيسية">
            {NAV.filter((item) => (!item.ownerOnly || role === "owner") && (!item.managerOnly || manager)).map((item) =>
              item.to ? (
                <NavLink key={item.label} to={item.to} end={item.to === "/dashboard"} onClick={() => setOpen(false)}>
                  <Icon name={item.icon} size={20} strokeWidth={1.7} />
                  <span>{item.label}</span>
                  {item.count && openSync > 0 ? (
                    <span className="nav-count" aria-label={`${openSync} بانتظار المراجعة`}>
                      {openSync}
                    </span>
                  ) : null}
                </NavLink>
              ) : (
                <span key={item.label} className="soon" aria-disabled="true">
                  <Icon name={item.icon} size={20} strokeWidth={1.7} />
                  <span>{item.label}</span>
                  <small>قريباً</small>
                </span>
              ),
            )}
          </nav>
          <div className="side-foot">
            {user.is_platform_admin ? (
              <NavLink to="/admin" className="platform-entry" onClick={() => setOpen(false)}>
                <Icon name="shield" size={18} strokeWidth={1.8} />
                إدارة المنصة
              </NavLink>
            ) : null}
            <div className="store-card">
              <span className="store-ic" aria-hidden="true">
                <Icon name="home" size={18} strokeWidth={1.8} />
              </span>
              <span>
                <small>المتجر</small>
                <b>{user.store?.name ?? ""}</b>
              </span>
            </div>
            <div className="user-card">
              <span className="avatar" aria-hidden="true">
                {initialOf(user.name)}
              </span>
              <span className="who">
                <b>{user.name}</b>
                <span>{ROLE_LABEL[role]}</span>
              </span>
              <button type="button" className="logout ic" onClick={signOut} disabled={leaving} aria-label={leaving ? "جارٍ تسجيل الخروج…" : "تسجيل الخروج"} title="تسجيل الخروج">
                <Icon name="logout" size={18} />
              </button>
            </div>
          </div>
        </div>
      </aside>
      <div className="workspace">
        <header className="topbar">
          <span className="topbar-title">لوحة الإدارة</span>
          <span className="topbar-meta">
            <span className="role-chip">{ROLE_LABEL[role]}</span>
            <span className="m">{user.phone}</span>
          </span>
        </header>
        <main id="main" className="content">
          <div className="content-inner">
            <Outlet />
          </div>
        </main>
      </div>
    </div>
  );
}
