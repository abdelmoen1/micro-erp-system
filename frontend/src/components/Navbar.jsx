const links = [
  ["featuers", "#features"],
  ["whyus", "#why"],
  ["prices", "#plans"],
  ["faq", "#faq"],
];
import { useState } from "react";
function Navbar({ t, lang, setLang }) {
  const [isOpen, setIsOpen] = useState(false);

  const toggleMenu = () => {
    setIsOpen(!isOpen);
  };
  return (
    <>
      {" "}
      <nav>
        <div className="container">
          <a href="#" className="logo-link">
            <div className="logo-icon">M</div>
            <span>Micro ERP</span>
          </a>
          <ul className="nav-links">
            <>
              {links.map(([key, href]) => (
                <li key={key}>
                  <a href={href}>{t.nav[key]}</a>
                </li>
              ))}
            </>
          </ul>
          <div className="nav-actions">
            <button onClick={() => setLang(lang === "en" ? "ar" : "en")}>
              {lang === "en" ? "العربية" : "English"}
            </button>

            <a href="/login">{t.nav.login}</a>

            <a href="/register" className="register-button">
              {t.nav.signup}
            </a>
            <button
              className="mobile-only-btn"
              aria-expanded={isOpen}
              aria-label="Menu"
              onClick={toggleMenu}
            >
              {isOpen === false ? "☰" : "✕"}
            </button>
          </div>
        </div>
      </nav>
      <div
        className="mobile-menu-container"
        style={
          isOpen === true ? { visibility: "visible" } : { visibility: "hidden" }
        }
      >
        <ul>
          {" "}
          <>
            {links.map(([key, href]) => (
              <li key={key}>
                <a href={href} className="menu-link">
                  {t.nav[key]}
                </a>
              </li>
            ))}
          </>
        </ul>
        <div className="menu-actions">
          <a href="/login" className="btn-login">
            تسجيل الدخول
          </a>
          <a href="/register" className="btn-register">
            ابدأ مجاناً
          </a>
        </div>
      </div>
    </>
  );
}

export default Navbar;
