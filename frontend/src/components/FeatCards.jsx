function FeatCards() {
  const features = [
    {
      icon: "🧾",
      title: "Free invoices",
      desc: "Create a complete financial experience and automate invoice issuance and payment tracking.",
    },
    {
      icon: "🏪",
      title: "Multiple stores",
      desc: "Run each store's operations independently and generate custom reports per branch.",
    },
    {
      icon: "🔐",
      title: "Unmatched security",
      desc: "Manage your store data securely with full isolation and role-based permissions.",
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
