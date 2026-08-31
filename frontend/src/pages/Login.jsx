import { Link } from "react-router-dom";
import { CiLock } from "react-icons/ci";
import { FaEye, FaEyeSlash } from "react-icons/fa6";
import { IoMailOutline } from "react-icons/io5";
import "../Sign.css";
import { useState } from "react";
function Login() {
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoding] = useState(false);
  const [formData, setFromData] = useState({
    email: "",
    password: "",
  });
  const handleChange = (e) => {
    const { name, value } = e.target;

    setFromData({
      ...formData,
      [name]: value,
    });
  };
  const handleSubmit = (e) => {
    e.preventDefault();
    const newErrors = {};
    const formData = new FormData(e.target);
    const email = formData.get("email");
    const password = formData.get("password");

    if (!email) {
      newErrors.email = "البريد الإلكتروني مطلوب";
    } else if (!password) {
      newErrors.password = "كلمة المرور مطلوبة";
    } else if (password.length < 8) {
      newErrors.password = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    }
    setErrors(newErrors);
    if (Object.keys(newErrors).length === 0) {
      setLoding(!loading);
    }
  };
  return (
    <>
      <div className="auth-layout">
        <div className="auth-card card">
          <div className="auth-header">
            <h2>Welcome Back</h2>
            <p>Sign in to your account</p>
          </div>

          <div className="auth-tabs">
            <Link to="/login" className="auth-tab active">
              Login
            </Link>
            <Link to="/register" className="auth-tab">
              Sign Up
            </Link>
          </div>

          <form
            className="auth-form"
            action=""
            method="POST"
            onSubmit={handleSubmit}
          >
            <div className={`input-wrapper ${errors.email ? "has-error" : ""}`}>
              <IoMailOutline className="input-icon" />
              <input
                type="email"
                name="email"
                id="email"
                onChange={handleChange}
                value={formData.email}
                placeholder="Email Address"
              />
            </div>
            {errors.email && (
              <span className="error-message">{errors.email}</span>
            )}
            <div
              className={`input-wrapper ${errors.password ? "has-error" : ""}`}
            >
              <CiLock className="input-icon" />
              <input
                type={showPassword ? "text" : "password"}
                name="password"
                id="password"
                onChange={handleChange}
                value={formData.password}
                placeholder="Password"
              />
              <button
                type="button"
                className="password-toggle"
                onClick={() => setShowPassword(!showPassword)}
                aria-label="Toggle password visibility"
              >
                {showPassword ? <FaEyeSlash /> : <FaEye />}
              </button>
            </div>
            {errors.password && (
              <span className="error-message">{errors.password}</span>
            )}

            <div className="auth-actions">
              <label htmlFor="remember" className="checkbox-label">
                <input type="checkbox" name="remember" id="remember" />
                <span>Remember me</span>
              </label>
              <Link to="/forgot-password" className="forgot-link">
                Forgot Password?
              </Link>
            </div>

            <button
              type="submit"
              className={`btn btn-primary auth-submit${loading ? " loading-btn" : ""}`}
            >
              {loading ? <span className="loading"></span> : "Log In"}
            </button>
          </form>

          <div className="auth-footer">
            <p>
              Don't have an account? <Link to="/register">Sign up</Link>
            </p>
          </div>
        </div>
      </div>
    </>
  );
}

export default Login;
