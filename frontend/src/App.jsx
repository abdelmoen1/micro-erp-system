import { useEffect, useState, useRef } from "react";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import WhySection from "./components/WhySection";
import Steps from "./components/Steps";
import Mission from "./components/Mission";
import Plans from "./components/Plans";
import FAQ from "./components/FAQ";
import CTA from "./components/CTA";
import Footer from "./components/Footer";
import "./App.css";
import { translation } from "./data/translation";

function ScrollAnimate({ children }) {
  const [isVisible, setIsVisible] = useState(false);
  const elementRef = useRef(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.unobserve(entry.target); // إيقاف المراقبة بعد الظهور الأول للحفاظ على الأداء
        }
      },
      { threshold: 0.15 }, // يبدأ الأنميشن عندما يظهر 15% من القسم على الشاشة
    );

    if (elementRef.current) {
      observer.observe(elementRef.current);
    }

    return () => {
      if (elementRef.current) {
        observer.unobserve(elementRef.current);
      }
    };
  }, []);

  return (
    <div
      ref={elementRef}
      className={`reveal-section ${isVisible ? "is-visible" : ""}`}
    >
      {children}
    </div>
  );
}

function App() {
  const [lang, setLang] = useState("ar");
  const t = translation[lang];

  useEffect(() => {
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = lang;
  }, [lang]);

  return (
    <div>
      <header>
        <Navbar t={t} lang={lang} setLang={setLang} />
      </header>
      <main>
        {/* 2. توزيع الأنميشن على الأقسام بلف كل مكوّن بـ ScrollAnimate */}
        <ScrollAnimate>
          <Hero t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <Features t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <WhySection t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <Steps t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <Mission t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <Plans t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <FAQ t={t} />
        </ScrollAnimate>
        <ScrollAnimate>
          <CTA t={t} />
        </ScrollAnimate>
      </main>
      <footer className="footer-section">
        <Footer t={t} lang={lang} setLang={setLang} />
      </footer>
    </div>
  );
}

export default App;
