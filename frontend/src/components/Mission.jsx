function Mission() {
  const metrics = [
    { value: "98%", label: "Customer satisfaction" },
    { value: "500+", label: "Active stores" },
    { value: "24/7", label: "Technical support" },
  ];
  return (
    <section className="mission-section">
      <div className="container mission-container">
        <p className="mission-subtitle">Our mission</p>
        <h2 className="mission-title">
          We've helped hundreds{"\n"}of small stores.
        </h2>
        <p className="mission-description">
          From retail shops to startups — Micro ERP makes management easier and
          faster.
        </p>

        <div className="metric-grid">
          <>
            {metrics.map((metric) => (
              <div className="metric-item">
                <div className="metric-value">{metric.value}</div>
                <div className="metric-label">{metric.label}</div>
              </div>
            ))}
          </>
        </div>
      </div>
    </section>
  );
}

export default Mission;
