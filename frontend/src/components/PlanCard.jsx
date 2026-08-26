function PlanCard() {
  return (
    <div className="plan-card plan-basic">
      <div className="plan-card-header">
        <div>
          <div className="plan-name font-dark">Basic</div>
          <div className="plan-price font-dark">Free</div>
        </div>
        <a href="/register" className="arrow-btn border-btn">
          ↗
        </a>
      </div>
      <p className="plan-description text-gray">
        For small shops just starting out.
      </p>

      <ul className="plan-features-list">
        <li className="feature-item item-dark">
          <span className="checkmark-teal">✓</span>1 store
        </li>
        <li className="feature-item item-dark">
          <span className="checkmark-teal">✓</span>Up to 3 employees
        </li>
        <li className="feature-item item-dark">
          <span className="checkmark-teal">✓</span>Unlimited invoices
        </li>
        <li className="feature-item item-dark">
          <span className="checkmark-teal">✓</span>Basic reports
        </li>
      </ul>

      <a href="/register" className="plan-action-btn action-basic">
        Get Started Free ↗
      </a>
    </div>
  );
}

export default PlanCard;
