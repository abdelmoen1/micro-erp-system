function FeatCards({ t }) {
  const features = [
    {
      icon: "🧾",
      title: t.feat1Title,
      desc: t.feat1Desc,
    },
    {
      icon: "🏪",
      title: t.feat2Title,
      desc: t.feat2Desc,
    },
    {
      icon: "🔐",
      desc: t.feat3Title,
      desc: t.feat3Desc,
    },
  ];
  return (
    <>
      {features.map((feature) => (
        <article className="feat-card">
          <div className="feat-icon">{feature.icon}</div>
          <h3 className="feat-card-title">{feature.title}</h3>
          <p className="feat-card-text">{feature.desc}</p>
        </article>
      ))}
    </>
  );
}

export default FeatCards;
