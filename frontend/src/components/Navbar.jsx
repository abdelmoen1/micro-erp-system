import Button from "./Button";
function Navbar() {
  return (
    <nav>
      <div className="container">
        <a href="#" className="logo-link">
          <div className="logo-icon">M</div>
          <span>Micro ERP</span>
        </a>
        <ul className="nav-links">
          <li>
            <a href="#features">Features</a>
          </li>

          <li>
            <a href="#why">Why us?</a>
          </li>

          <li>
            <a href="#plans">Prices</a>
          </li>

          <li>
            <a href="#faq">F&Q</a>
          </li>
        </ul>
        <div className="nav-actions">
          <button>العربية</button>

          <a href="/login">Login</a>

          <Button />
        </div>
      </div>
    </nav>
  );
}

export default Navbar;
