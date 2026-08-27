function HeroCard({ t }) {
  const cardDir = t.lang === "ar" ? "rtl" : "ltr";
  const badgStyle = {
    direction: cardDir,
    left: cardDir === "ltr" ? "-20px" : "100px",
  };
  const badgPayment = {
    direction: cardDir,
    right: cardDir === "ltr" ? "-10px" : "100px",
  };
  return (
    <div className="flex-center-pb40">
      <div className="pos-relative-ltr">
        <div className="invoice-card" style={{ direction: cardDir }}>
          <div className="user-header">
            <div className="user-avatar">م</div>
            <div>
              <div className="user-name">{t.heroCardName}</div>
              <div className="user-email">owner@store.com</div>
            </div>
          </div>

          <div className="sales-details">
            <div className="sales-date">{t.heroCardDate}</div>
            <div className="sales-amount">{t.heroCardAmount}</div>
            <div className="sales-label">{t.heroCardSub}</div>
          </div>

          <div className="tags-container">
            <span className="tag-cash">{t.heroCardBadge1}</span>
            <span className="tag-deferred">{t.heroCardBadge1}</span>
          </div>

          <button className="btn-view-invoice">{t.heroCardBtn}</button>
        </div>

        <div className="badge-payment" style={badgPayment}>
          <span className="status-dot-green"></span>
          {t.heroCardPayment}
        </div>

        <div className="badge-clients" style={badgStyle}>
          <div className="clients-label">{t.heroCardCustomres}</div>
          <div className="clients-count">137</div>
          <div className="clients-growth">{t.heroCardUp}</div>
        </div>
      </div>
    </div>
  );
}

export default HeroCard;
