import { useState } from "react";
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

function App() {
  return (
    <>
      <header>
        <Navbar />
      </header>
      <main>
        <Hero />
        <Features />
        <WhyErpSystem />
        <Steps />
        <Mission />
        <Plans />
        <FAQ />
        <CTA />
      </main>
      <footer className="footer-section">
        <Footer />
      </footer>
    </>
  );
}

export default App;
