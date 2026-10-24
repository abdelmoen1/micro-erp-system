import { useState } from "react";
import { useQueryClient } from "@tanstack/react-query";
import { Link, NavLink, Outlet, useNavigate } from "react-router-dom";
import HisbahLogo from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { initialOf } from "../lib/format";
import { session } from "../services/apiClient";
import { logout } from "../services/dashboard";
import "../styles/platform.css";

const NAV = [
  { label: "المتاجر", icon: "shop", to: "/admin", end: true },
  { label: "المنتجات في المتاجر", icon: "products", to: "/admin/products" },
];

/**
 * Platform owner area. The deep-green sidebar marks that these pages span every store, unlike the
 * white store back office. Hiding this for non-admins is a courtesy only: every /admin API call is
 * refused server-side unless the account is a platform admin.
 */
export default function AdminShell() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const user = session.user() ?? {};

  const signOut = async () => {
    setLeaving(true);
    await logout();
    queryClient.clear();
    navigate("/login", { replace: true });
  };

  if (!user.is_platform_admin) {
    return (
      <main className="platform-denied">
        <div role="alert" className="card state-card">
          <Icon name="lock" size={40} color="#4a5565" strokeWidth={1.8} />
          <b className="state-title">هذه الصفحات لمالك المنصة فقط</b>
          <span className="state-text">حسابك حساب متجر. إدارة المتاجر والاشتراكات متاحة لإدارة حسبة وحدها.</span>
          <Link className="btn btn-s btn-sm" to="/dashboard">
            العودة إلى متجري
          </Link>
        </div>
      </main>
    );
  }

  return (
    <div className={open ? "shell platform nav-open" : "shell platform"}>
      <a href="#main" className="skip-link">
        تخطَّ إلى المحتوى
      </a>
      <aside className="side" aria-label="قائمة المنصة">
        <div className="side-top">
          <NavLink to="/admin" className="side-brand" aria-label="حسبة — إدارة المنصة">
            <HisbahLogo size={30} />
          </NavLink>
          <button type="button" className="menubtn ic" onClick={() => setOpen((o) => !o)} aria-expanded={open} aria-controls="platform-nav" aria-label="القائمة">
            <Icon name="menu" size={20} />
          </button>
        </div>
        <div className="navwrap">
          <p className="platform-tag">
            <Icon name="shield" size={16} strokeWidth={1.9} />
            إدارة المنصة
          </p>
          <nav id="platform-nav" className="nav" aria-label="قائمة المنصة">
            {NAV.map((item) => (
              <NavLink key={item.to} to={item.to} end={item.end} onClick={() => setOpen(false)}>
                <Icon name={item.icon} size={20} strokeWidth={1.7} />
                <span>{item.label}</span>
              </NavLink>
            ))}
          </nav>
          <div className="side-foot">
            {user.store ? (
              <Link to="/dashboard" className="platform-back">
                <Icon name="arrow" size={16} />
                العودة إلى متجري
              </Link>
            ) : null}
            <div className="user-card">
              <span className="avatar" aria-hidden="true">
                {initialOf(user.name)}
              </span>
              <span className="who">
                <b>{user.name}</b>
                <span>مالك المنصة</span>
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
          <span className="topbar-title">إدارة المنصة</span>
          <span className="topbar-meta">
            <span className="role-chip">مالك المنصة</span>
            <span className="m">{user.email}</span>
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
