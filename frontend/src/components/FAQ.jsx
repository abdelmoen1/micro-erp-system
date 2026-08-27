import React, { useState } from "react";

function FAQ({t}) {
  const [openIndex, setOpenIndex] = useState(0);

  const toggleAccordion = (index) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  return (
    <section id="faq" className="faq-section">
      <div className="container faq-container">
        <p className="faq-subtitle">{t.faqEyebrow}</p>
        <h2 className="faq-title">{t.faqTitle}</h2>

        <div className="faq-list">
          {t.faqs.map((item, index) => {
            const isOpen = openIndex === index;
            return (
              <div key={index} className="faq-item">
                <button
                  aria-expanded={isOpen}
                  className="faq-trigger"
                  onClick={() => toggleAccordion(index)}
                >
                  <span className="faq-question">{item.q}</span>
                  <span
                    className={`faq-arrow ${isOpen ? "arrow-rotated" : ""}`}
                  >
                    ▾
                  </span>
                </button>

                <div
                  className={`faq-content ${isOpen ? "content-visible" : "content-hidden"}`}
                >
                  <p className="faq-answer">{item.a}</p>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}

export default FAQ;
