import { useState } from "react";
import reactLogo from "./assets/react.svg";
import viteLogo from "./assets/vite.svg";
import heroImg from "./assets/hero.png";
import Navbar from "./components/Navbar";
import Hero from "./components/Hero";
import Features from "./components/Features";
import WhyErpSystem from "./components/WhyErpSystem";
import Steps from "./components/Steps";
import "./App.css";
import Mission from "./components/Mission";

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
      </main>
    </>
  );
}

export default App;
