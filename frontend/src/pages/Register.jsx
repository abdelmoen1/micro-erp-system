import { Link } from "react-router-dom";
import { CiLock, CiUser } from "react-icons/ci";
import { FiShield } from "react-icons/fi";
import { FaEye, FaEyeSlash, FaStore } from "react-icons/fa";
import { IoMailOutline, IoStorefrontOutline } from "react-icons/io5";
import "../Sign.css";
import { useState } from "react";
function Register() {
  const [showPassword, setShowPassword] = useState(false);
  const [errors, setErrors] = useState({});
  const [loading, setLoding] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    const newErrors = {};
    const formData = new FormData(e.target);
    const storeName = formData.get("store_name");
    const ownerName = formData.get("owner_name");
    const email = formData.get("email");
    const password = formData.get("password");
    const passwordConfirm = formData.get("password_confirmation");
    const remember = formData.get("remember");

    if (!storeName) {
      newErrors.storeName = "اسم المتجر مطلوب";
    } else if (!ownerName) {
      newErrors.ownerName = "اسم مالك المتجر مطلوب";
    } else if (!email) {
      newErrors.email = "البريد الإلكتروني مطلوب";
    } else if (!password) {
      newErrors.password = "كلمة المرور مطلوبة";
    } else if (password.length < 8) {
      newErrors.password = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    } else if (!passwordConfirm) {
      newErrors.passwordConfirm = "يجب تأكيد كلمة المرور";
    } else if (passwordConfirm !== password) {
      newErrors.passwordConfirm = "لا تطابق في كلمات المرور";
    } else if (!remember) {
      newErrors.remember = "يجب الموافقة على الشروط والأحكام";
    }
    setErrors(newErrors);
    if (Object.keys(newErrors).length === 0) {
      setLoding(!loading);
    }
  };
  return (
    <div className="auth-layout">
      <div className="auth-card card">
        <div className="auth-header">
          <h2>
            Crate new Store <FaStore />
          </h2>
          <p>Create new account</p>
        </div>

        <div className="auth-tabs">
          <Link to="/login" className="auth-tab">
            Login
          </Link>
          <Link to="/register" className="auth-tab active">
            Sign Up
          </Link>
        </div>

        <form
          className="auth-form"
          action=""
          method="POST"
          onSubmit={handleSubmit}
        >
          <div
            className={`input-wrapper ${errors.storeName ? "has-error" : ""}`}
          >
            <IoStorefrontOutline className="input-icon" />
            <input
              type="text"
              name="store_name"
              id="store"
              placeholder="Store Name"
            />
          </div>
          {errors.storeName && (
            <span className="error-message">{errors.storeName}</span>
          )}
          <div
            className={`input-wrapper ${errors.ownerName ? "has-error" : ""}`}
          >
            <CiUser className="input-icon" />
            <input
              type="text"
              name="owner_name"
              id="owner"
              placeholder="Owner Name"
            />
          </div>
          {errors.ownerName && (
            <span className="error-message">{errors.ownerName}</span>
          )}
          <div className={`input-wrapper ${errors.email ? "has-error" : ""}`}>
            <IoMailOutline className="input-icon" />
            <input
              type="email"
              name="email"
              id="email"
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
          <div
            className={`input-wrapper ${errors.passwordConfirm ? "has-error" : ""}`}
          >
            <FiShield className="input-icon" />
            <input
              type={showPassword ? "text" : "password"}
              name="password_confirmation"
              id="password_confirmation"
              placeholder="Confirm Password"
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
          {errors.passwordConfirm && (
            <span className="error-message">{errors.passwordConfirm}</span>
          )}

          <div className="auth-actions">
            <label
              htmlFor="remember"
              className={`checkbox-label ${errors.remember ? "has-error-text" : ""}`}
            >
              <input type="checkbox" name="remember" id="remember" />
              <span>
                I agree to the <a href="#">Terms of Service</a> and{" "}
                <a href="#">Privacy Policy</a>
              </span>
            </label>
          </div>
          {errors.remember && (
            <span className="error-message">{errors.remember}</span>
          )}

          <button
            type="submit"
            className={`btn btn-primary auth-submit${loading ? " loading-btn" : ""}`}
          >
            {loading ? <span className="loading"></span> : "Sign Up"}
          </button>
        </form>

        <div className="auth-footer">
          <p>
            Already have an account? <Link to="/register">Log In</Link>
          </p>
        </div>
      </div>
    </div>
  );
}

export default Register;
