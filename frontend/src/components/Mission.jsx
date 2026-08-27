function Mission({ t }) {
  const metrics = [
    { value: t.metric1Num, label: t.metric1Label },
    { value: t.metric2Num, label: t.metric2Label },
    { value: t.metric3Num, label: t.metric3Label },
  ];
  return (
    <section className="mission-section">
      <div className="container mission-container">
        <p className="mission-subtitle">{t.missionEyebrow}</p>
        <h2 className="mission-title">{t.missionTitle}</h2>
        <p className="mission-description">
          {t.missionSub}
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
