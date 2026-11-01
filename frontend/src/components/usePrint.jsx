import { useState } from "react";
import { flushSync } from "react-dom";
import PrintSheet from "./PrintSheet";

/**
 * The browser's print dialog for a document from lib/printDocs: any printer the computer has, in
 * any paper size, or a PDF. The caller renders the returned sheet.
 */
export function usePrint() {
  const [doc, setDoc] = useState(null);
  const print = (next) => {
    // The paper has to be in the page before the dialog freezes it.
    flushSync(() => setDoc(next));
    window.print();
  };
  return { print, sheet: doc ? <PrintSheet doc={doc} /> : null };
}
