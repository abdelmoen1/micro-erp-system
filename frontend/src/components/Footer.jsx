import lightfavicon from "../assets/lightfavicon.png";
import blackHesba from "../assets/blackHesba.png";
function Footer({ t, lang, setLang }) {
  return (
    <div className="container">
      <div className="footer-grid">
        <div className="footer-brand-col">
          <div className="footer-logo-wrapper">
            <div>
              <img className="fav-icon" src={lightfavicon} alt="" />
            </div>
            <span>
              <img className="name" src={blackHesba} alt="" />
            </span>
          </div>
          <p className="footer-brand-desc">{t.footerDesc}</p>
          <p className="social-label">{t.followUs}</p>
          <div className="social-links-group">
            <a href="#" className="social-link-item">
              𝕏
            </a>
            <a href="#" className="social-link-item">
              in
            </a>
            <a href="#" className="social-link-item">
              f
            </a>
          </div>
        </div>

        {t.footerCols?.map((col, index) => (
          <div key={index} className="footer-nav-col">
            <h4 className="footer-nav-title">{col.title}</h4>
            <ul className="footer-nav-list">
              {col.links?.map((link, linkIndex) => (
                <li key={linkIndex}>
                  <a href="#" className="footer-nav-link">
                    {typeof link === "string" ? link : link.text || link[0]}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>

      <div className="footer-bottom-bar">
        <span className="footer-copyright">{t.copyright}</span>
        <button
          className="footer-lang-btn"
          onClick={() => setLang(lang === "ar" ? "en" : "ar")}
        >
          {lang === "ar" ? "English" : "العربية"}
        </button>
      </div>
    </div>
  );
}

export default Footer;
