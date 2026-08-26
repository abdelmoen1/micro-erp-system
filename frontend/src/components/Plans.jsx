import PlanCard from "./PlanCard";
function Plans() {
  return (
    <section id="plans" className="plans-section">
      <div className="container">
        <div className="plans-header">
          <p className="plans-subtitle">Choose plan</p>
          <h2 className="plans-title">Choose Your Plan</h2>
        </div>

        <div className="plan-grid">
          <PlanCard />
        </div>
      </div>
    </section>
  );
}

export default Plans;
