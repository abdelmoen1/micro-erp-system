import { useAuthOptions } from "../services/useAuth";

/** When the SMS does not arrive: ask the team on WhatsApp, who read the code from the admin page. */
export default function OtpWhatsapp({ phone }) {
  const number = useAuthOptions().data?.supportWhatsapp;
  if (!number) return null;
  const text = encodeURIComponent(`بدي رمز تفعيل حسبة لرقم ${phone}`);
  return (
    <p>
      ما وصلتك الرسالة؟{" "}
      <a href={`https://wa.me/${number}?text=${text}`} target="_blank" rel="noreferrer">
        اطلب الرمز على واتساب
      </a>
    </p>
  );
}
