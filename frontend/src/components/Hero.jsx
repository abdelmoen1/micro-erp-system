import HeroCard from "./HeroCard";
function Hero({ t }) {
  return (
    <section className="hero-section">
      <div className="container">
        <div className="hero-grid">
          <div className="hero-title">
            <p>{t.heroSubTitle}</p>
            <h1>{t.heroTitle}</h1>
            <p>{t.heroSub}</p>
            <div className="hero-form">
              <input
                type="email"
                name="email"
                placeholder={t.heroPlaceholder}
              />
              <a href="/register" className="register-button">
                {t.heroCta}
              </a>
            </div>
            <div className="hero-foot">
              <p>{t.partnerLabel}</p>
              <ul>
                <li>Noon</li>
                <li>Salla</li>
                <li>Zid</li>
                <li>Foodics</li>
              </ul>
            </div>
          </div>
          <div>
            <HeroCard t={t} />
          </div>
        </div>
      </div>
    </section>
  );
}

export default Hero;
