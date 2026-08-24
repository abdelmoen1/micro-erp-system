function HeroCard() {
  return (
    <div className="flex-center-pb40">
      <div className="pos-relative-ltr">
        <div className="invoice-card">
          <div className="user-header">
            <div className="user-avatar">م</div>
            <div>
              <div className="user-name">Mohammed Al-Otaibi</div>
              <div className="user-email">owner@store.com</div>
            </div>
          </div>

          <div className="sales-details">
            <div className="sales-date">August 2026</div>
            <div className="sales-amount">SAR 24,800</div>
            <div className="sales-label">Total Sales</div>
          </div>

          <div className="tags-container">
            <span className="tag-cash">Cash</span>
            <span className="tag-deferred">Deferred</span>
          </div>

          <button className="btn-view-invoice">View Invoice</button>
        </div>

        <div className="badge-payment">
          <span className="status-dot-green"></span>
          New payment: SAR 1,200
        </div>

        <div className="badge-clients">
          <div className="clients-label">Active clients</div>
          <div className="clients-count">137</div>
          <div className="clients-growth">↑ 5 new this week</div>
        </div>
      </div>
    </div>
  );
}

export default HeroCard;
