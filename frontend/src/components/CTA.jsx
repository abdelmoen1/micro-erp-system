function CTA() {
  return (
    <section className="cta-section">
      <div className="container">
        <div className="cta-box">
          <p className="cta-subtitle">Get started</p>
          <h2 className="cta-title">
            Ready to level up{"\n"}your store management?
          </h2>
          <p className="cta-description">
            Supports small shops and businesses with simple invoicing and
            effective management tools.
          </p>

          <div className="cta-actions">
            <a href="/register" className="btn-primary">
              Get Started Now
            </a>
            <a href="#features" className="btn-secondary">
              Learn More ↗
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

export default CTA;
