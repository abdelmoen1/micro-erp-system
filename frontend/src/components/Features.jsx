import FeatCards from "./FeatCards";

function Features() {
  return (
    <section id="features" className="features-section">
      <div className="container">
        <div className="features-header">
          <div>
            <p className="features-subtitle">Why Micro ERP</p>
            <h2 className="features-title">
              Experience that grows with your scale.
            </h2>
          </div>
          <p className="features-description">
            Design a management system that works for your store and streamlines
            daily operations.
          </p>
        </div>

        <div className="feat-grid">
          <FeatCards />
        </div>
      </div>
    </section>
  );
}

export default Features;
