const links = [
  ["featuers", "#features"],
  ["whyus", "#why"],
  ["prices", "#plans"],
  ["faq", "#faq"],
];
import { Link } from "react-router-dom";
import { useState } from "react";
import hesba from "../assets/hesba.png";
import favIcon from "../assets/favIcon.png";
function Navbar({ t, lang, setLang }) {
  const [isOpen, setIsOpen] = useState(false);

  const toggleMenu = () => {
    setIsOpen(!isOpen);
  };
  const visabel =
    isOpen === true ? { visibility: "visible" } : { visibility: "hidden" };
  return (
    <>
      {" "}
      <nav>
        <div className="container">
          <a href="#" className="logo-link">
            <div>
              <img className="fav-icon" src={favIcon} alt="" />
            </div>
            <span>
              <img className="name" src={hesba} alt="" />
            </span>
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

            <Link to="/login">{t.nav.login}</Link>

            <Link to="/register" className="register-button">
              {t.nav.signup}
            </Link>
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
      <div className="mobile-menu-container" style={visabel}>
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
            {t.nav.login}
          </a>
          <a href="/register" className="btn-register">
            {t.nav.signup}
          </a>
        </div>
      </div>
    </>
  );
}

export default Navbar;
