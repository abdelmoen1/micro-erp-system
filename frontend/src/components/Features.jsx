import FeatCards from "./FeatCards";

function Features({ t }) {
  return (
    <section id="features" className="features-section">
      <div className="container">
        <div className="features-header">
          <div>
            <p className="features-subtitle">{t.featureEyebrow}</p>
            <h2 className="features-title">{t.featureTitle}</h2>
          </div>
          <p className="features-description">{t.featureSub}</p>
        </div>

        <div className="feat-grid">
          <FeatCards t={t} />
        </div>
      </div>
    </section>
  );
}

export default Features;
