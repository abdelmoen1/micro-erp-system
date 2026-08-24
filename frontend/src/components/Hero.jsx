import HeroCard from "./HeroCard";
import Button from "./Button";
function Hero() {
  return (
    <section className="hero-section">
      <div className="container">
        <div className="hero-grid">
          <div className="hero-title">
            <p>✦ Built for small businesses</p>
            <h1>Run Your Entire Store From One Place.</h1>
            <p>
              Supports small shops and businesses with simple invoicing, debt
              tracking, and effective sales management tools.
            </p>
            <div className="hero-form">
              <input
                type="email"
                name="email"
                placeholder="Your business email"
              />
              <Button />
            </div>
            <div className="hero-foot">
              <p>Trusted by</p>
              <ul>
                <li>Noon</li>
                <li>Salla</li>
                <li>Zid</li>
                <li>Foodics</li>
              </ul>
            </div>
          </div>
          <div>
            <HeroCard />
          </div>
        </div>
      </div>
    </section>
  );
}

export default Hero;
