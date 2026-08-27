import React, { useState } from "react";

function FAQ() {
  const faqData = [
    {
      question: "What is Micro ERP?",
      answer:
        "Micro ERP is a complete management system for small shops covering invoices, customers, debts, payments, and team management.",
    },
    {
      question: "Does it require technical knowledge?",
      answer:
        "No. The system is designed to be simple. You start in minutes with no technical background needed.",
    },
    {
      question: "Can I add employees?",
      answer:
        "Yes. Add employees with different roles (Owner, Manager, Employee) with custom permissions per role.",
    },
    {
      question: "Is store data kept separate?",
      answer:
        "Absolutely. Every store is fully isolated. No user can access another store's data.",
    },
    {
      question: "Does it work on mobile?",
      answer:
        "Yes, the interface is responsive and works on phone, tablet, and desktop with full efficiency.",
    },
  ];

  const [openIndex, setOpenIndex] = useState(0);

  const toggleAccordion = (index) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  return (
    <section id="faq" className="faq-section">
      <div className="container faq-container">
        <p className="faq-subtitle">FAQ</p>
        <h2 className="faq-title">Got a question?</h2>

        <div className="faq-list">
          {faqData.map((item, index) => {
            const isOpen = openIndex === index;
            return (
              <div key={index} className="faq-item">
                <button
                  aria-expanded={isOpen}
                  className="faq-trigger"
                  onClick={() => toggleAccordion(index)}
                >
                  <span className="faq-question">{item.question}</span>
                  <span
                    className={`faq-arrow ${isOpen ? "arrow-rotated" : ""}`}
                  >
                    ▾
                  </span>
                </button>

                <div
                  className={`faq-content ${isOpen ? "content-visible" : "content-hidden"}`}
                >
                  <p className="faq-answer">{item.answer}</p>
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
