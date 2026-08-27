function WhySection({ t }) {
  return (
    <section id="why" className="why-section">
      <div className="container">
        <p className="why-subtitle">{t.whyEyebrow}</p>
        <h2 className="why-title">{t.whyTitle}</h2>

        <div className="why-grid">
          <div className="flex-column-gap20">
            <div className="why-card card-padding32">
              <div className="stat-number">{t.stat1Num}</div>
              <p className="stat-text">{t.stat1Label}</p>
            </div>

            <div className="why-card card-padding24">
              <h3 className="card-title">{t.stat2Title}</h3>
              <p className="card-text mb16">{t.stat2Sub}</p>

              <div className="report-icons-container">
                <div className="icon-box bg-teal">📊</div>
                <div className="gradient-line"></div>
                <div className="icon-box bg-navy">📱</div>
              </div>
            </div>
          </div>
          <div className="flex-column-gap20">
            <div className="why-card card-padding24">
              <h3 class="card-title">{t.stat3Title}</h3>
              <p class="card-text">{t.stat3Sub}</p>
            </div>

            <div className="why-card card-padding20">
              <div className="chart-header">
                <span className="chart-title">{t.chartLabel}</span>
                <span className="chart-badge">{t.chartPeriod}</span>
              </div>

              <div className="chart-amount">{t.chartNum}</div>

              <svg
                className="chart-svg"
                width="100%"
                viewBox="0 0 260 72"
                preserveAspectRatio="none"
              >
                <defs>
                  <linearGradient id="cg" x1="0" x2="0" y1="0" y2="1">
                    <stop offset="0%" stopColor="#2A8E9E" stopOpacity={0.18} />
                    <stop offset="100%" stopColor="#2A8E9E" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <path
                  d="M8,52.8 L48.666666666666664,38.8 L89.33333333333333,47.2 L130,30.4 L170.66666666666666,36 L211.33333333333334,19.200000000000003 L252,27.6 L252,72 L8,72 Z"
                  fill="url(#cg)"
                />
                <path
                  d="M8,52.8 L48.666666666666664,38.8 L89.33333333333333,47.2 L130,30.4 L170.66666666666666,36 L211.33333333333334,19.200000000000003 L252,27.6"
                  fill="none"
                  stroke="#2A8E9E"
                  strokeWidth="2.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
                <circle cx="252" cy="27.6" r="4" fill="#2A8E9E" />
              </svg>

              <div className="chart-months">
                <span className="month-label">Jan</span>
                <span className="month-label">Feb</span>
                <span className="month-label">Mar</span>
                <span className="month-label">Apr</span>
                <span className="month-label">May</span>
                <span className="month-label">Jun</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}

export default WhySection;
