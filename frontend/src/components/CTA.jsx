function CTA({ t }) {
  return (
    <section className="cta-section">
      <div className="container">
        <div className="cta-box">
          <p className="cta-subtitle">{t.ctaEyebrow}</p>
          <h2 className="cta-title">{t.ctaTitle}</h2>
          <p className="cta-description">{t.ctaSub}</p>

          <div className="cta-actions">
            <a href="/register" className="btn-primary">
              {t.ctaBtn}
            </a>
            <a href="#features" className="btn-secondary">
              {t.ctaLink}
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

export default CTA;
