function PlanCard({ t }) {
  // 1. تحويل plans إلى مصفوفة (Array) لتتمكن من استخدام .map()
  const plans = [
    {
      title: t.plan1Name,
      price: t.plan1Price, // تأكدت من إضافة السعر هنا لأنك تستخدم plan.price بالأسفل
      desc: t.plan1Desc || t.plan1Price, // تعديل بناءً على استخدامك لـ plan.desc
      features: t.plan1Features , // للتأكد من أنها مصفوفة دائماً لتجنب الكراش
    },
  ];

  return (
    <>
      {plans.map((plan, index) => (
        // نصيحة: تذكر دائماً إضافة خاصية key عند عمل map في ريأكت
        <div key={index} className="plan-card plan-basic">
          <div className="plan-card-header">
            <div>
              <div className="plan-name font-dark">{plan.title}</div>
              <div className="plan-price font-dark">{plan.price}</div>
            </div>
            <a href="/register" className="arrow-btn border-btn">
              ↗
            </a>
          </div>
          <p className="plan-description text-gray">{plan.desc}</p>

          <ul className="plan-features-list">
            {/* 2. تصحيح الترتيب: العنصر أولاً (feature) ثم الترتيب الرقمي (index) */}
            {plan.features.map((feature, featIndex) => (
              <li key={featIndex} className="feature-item item-dark">
                <span className="checkmark-teal">✓</span>
                {feature}
              </li>
            ))}
          </ul>

          <a href="/register" className="plan-action-btn action-basic">
           {t.planBtn1}
          </a>
        </div>
      ))}
    </>
  );
}

export default PlanCard;
