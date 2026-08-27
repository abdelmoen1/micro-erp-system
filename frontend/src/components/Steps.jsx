function Steps({t}) {
  const steps = [
    {
      number: "1",
      title: t.step1Title,
      desc: t.step1Desc,
    },
    {
      number: "2",
      title: t.step2Title,
      desc: t.step2Desc,
    },
    {
      number: "3",
      title: t.step3Title,
      desc: t.step3Desc,
    },
  ];
  return (
    <section className="steps-section">
      <div className="container">
        <p className="steps-subtitle">{t.stepsEyebrow}</p>
        <h2 className="steps-title">
          {t.stepsTitle}
        </h2>

        <div className="steps-grid">
          <>
            {steps.map((step) => (
              <div className="step-card">
                <div className="step-number">{step.number}</div>
                <h3 className="step-card-title">{step.title}</h3>
                <p className="step-card-text">{step.desc}</p>
              </div>
            ))}
          </>
        </div>
      </div>
    </section>
  );
}

export default Steps;
