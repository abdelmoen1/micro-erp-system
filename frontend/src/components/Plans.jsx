import PlanCard from "./PlanCard";
function Plans({ t }) {
  return (
    <section id="plans" className="plans-section">
      <div className="container">
        <div className="plans-header">
          <p className="plans-subtitle">{t.planEyebrow}</p>
          <h2 className="plans-title">{t.planTitle}</h2>
        </div>

        <div className="plan-grid">
          <PlanCard t={t} />
        </div>
      </div>
    </section>
  );
}

export default Plans;
