function Footer() {
  return (
    <div className="container">
      <div className="footer-grid">
        <div className="footer-brand-col">
          <div className="footer-logo-wrapper">
            <div className="footer-logo-icon">M</div>
            <span className="footer-brand-name">Micro ERP</span>
          </div>
          <p className="footer-brand-desc">
            A complete management system designed for small shops and
            businesses.
          </p>
          <p className="social-label">Follow us</p>
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

        <div className="footer-nav-col">
          <h4 className="footer-nav-title">Solutions</h4>
          <ul className="footer-nav-list">
            <li>
              <a href="#" className="footer-nav-link">
                Small Business
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Restaurants
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Services
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Retail
              </a>
            </li>
          </ul>
        </div>

        <div className="footer-nav-col">
          <h4 className="footer-nav-title">Company</h4>
          <ul className="footer-nav-list">
            <li>
              <a href="#" className="footer-nav-link">
                About Us
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Team
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Blog
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Contact
              </a>
            </li>
          </ul>
        </div>

        <div className="footer-nav-col">
          <h4 className="footer-nav-title">Learn</h4>
          <ul className="footer-nav-list">
            <li>
              <a href="#" className="footer-nav-link">
                Blog
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Docs
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Case Studies
              </a>
            </li>
            <li>
              <a href="#" className="footer-nav-link">
                Templates
              </a>
            </li>
          </ul>
        </div>
      </div>

      <div className="footer-bottom-bar">
        <span className="footer-copyright">
          © Micro ERP 2026. All Rights Reserved.
        </span>
        <button className="footer-lang-btn">العربية</button>
      </div>
    </div>
  );
}

export default Footer;
