import { useEffect, useState } from "react";
import reactLogo from "./assets/react.svg";
import viteLogo from "./assets/vite.svg";
import heroImg from "./assets/hero.png";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import WhyErpSystem from "./components/WhyErpSystem";
import Steps from "./components/Steps";
import Mission from "./components/Mission";
import Plans from "./components/Plans";
import FAQ from "./components/FAQ";
import CTA from "./components/CTA";
import Footer from "./components/Footer";
import "./App.css";
import { translation } from "./data/translation";

function App() {
  const [lang, setLang] = useState("en");
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
        <Hero t={t} />
        <Features t={t} />
        <WhyErpSystem t={t} />
        <Steps t={t} />
        <Mission t={t} />
        <Plans t={t} />
        <FAQ t={t} />
        <CTA t={t} />
      </main>
      <footer className="footer-section">
        <Footer t={t} lang={lang} setLang={setLang} />
      </footer>
    </div>
  );
}

export default App;
