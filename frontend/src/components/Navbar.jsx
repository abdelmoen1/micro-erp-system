const links = [
  ["featuers", "#features"],
  ["whyus", "#why"],
  ["prices", "#plans"],
  ["faq", "#faq"],
];
function Navbar({ t, lang, setLang }) {
  return (
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
        </div>
      </div>
    </nav>
  );
}

export default Navbar;
