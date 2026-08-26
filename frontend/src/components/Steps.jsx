function Steps() {
  const steps = [
    {
      number: "1",
      title: "Open your account",
      desc: "Register as a store owner and set up your business profile in  minutes from the dashboard",
    },
    {
      number: "2",
      title: "Add your data",
      desc: "Enter customers, invoices, and payments and assign your employees the right permissions",
    },
    {
      number: "3",
      title: "Watch your store grow",
      desc: "Monitor sales, track debts, and collect payments — everythinginstant and accurate.",
    },
  ];
  return (
    <section className="steps-section">
      <div className="container">
        <p className="steps-subtitle">Steps</p>
        <h2 className="steps-title">
          Start smart management{"\n"}with simple steps.
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
