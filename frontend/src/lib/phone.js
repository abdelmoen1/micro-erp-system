import { latinDigits } from "./format";

// The sign-in mobile number in its one local form, 05XXXXXXXX (the server's App\Support\PhoneNumber):
// spaces, dashes, Arabic digits and +970 / 00970 / +972 are accepted while typing.

/** The local form, or null when the text is not a mobile number. */
export function normalizePhone(input) {
  let digits = latinDigits(String(input ?? "").trim()).replace(/[\s\-().]/g, "");
  digits = digits.replace(/^(\+|00)/, "");
  digits = digits.replace(/^(970|972)0?(5\d{8})$/, "0$2");
  return /^05\d{8}$/.test(digits) ? digits : null;
}

/** 059•••••56 for confirmations. */
export const maskPhone = (local) => (local && local.length >= 5 ? `${local.slice(0, 3)}•••••${local.slice(-2)}` : local);

export const PHONE_HINT = "رقم الجوال 10 أرقام يبدأ بـ 05، مثل 0599123456.";

/** Why a code could not be sent: the server's Arabic message, or the network. */
export function otpSendError(error) {
  if (error?.name === "NetworkError" || !error?.status) return "تعذّر الاتصال بالخادم. تحقق من الإنترنت ثم أعد المحاولة.";
  return error.message ?? "تعذّر إرسال الرسالة الآن. حاول بعد قليل.";
}
