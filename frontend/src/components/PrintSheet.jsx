import { createPortal } from "react-dom";
import { session } from "../services/apiClient";

/** The paper: hidden on screen; when printing it is the only thing on the page (hisbah.css). */
export default function PrintSheet({ doc }) {
  const store = session.user()?.store ?? {};
  return createPortal(
    <section className="print-doc" dir="rtl" aria-hidden="true">
      <header className="print-head">
        <h1>{store.name}</h1>
        {store.address ? <p>{store.address}</p> : null}
        {store.phone ? <p className="m">{store.phone}</p> : null}
        <h2>
          <span>{doc.title}</span> <span className="m">{doc.number}</span>
        </h2>
        {doc.stamp ? <p className="print-stamp">{doc.stamp}</p> : null}
      </header>
      <dl className="print-facts">
        {doc.facts.map(([label, value]) => (
          <div key={label}>
            <dt>{label}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>
      <table className="print-lines">
        <thead>
          <tr>
            <th>الصنف</th>
            <th>الكمية</th>
            <th>السعر</th>
            <th>المبلغ</th>
          </tr>
        </thead>
        <tbody>
          {doc.rows.map((row, i) => (
            <tr key={`${row.name}-${i}`}>
              <td>
                <b>{row.name}</b>
                {row.detail ? <small>{row.detail}</small> : null}
              </td>
              <td className="m">{row.quantity}</td>
              <td className="m">{row.price ?? ""}</td>
              <td className="m">{row.amount}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <dl className="print-totals">
        {doc.totals.map(([label, value, strong]) => (
          <div key={label} className={strong ? "strong" : undefined}>
            <dt>{label}</dt>
            <dd className="m">{value}</dd>
          </div>
        ))}
      </dl>
      {doc.note ? <p className="print-note">{doc.note}</p> : null}
      {doc.footer ? <p className="print-foot">{doc.footer}</p> : null}
    </section>,
    document.body,
  );
}
