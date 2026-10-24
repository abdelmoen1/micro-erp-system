import { useEffect, useRef, useState } from "react";
import { Link } from "react-router-dom";
import HisbahLogo, { HisbahMark } from "../components/HisbahLogo";
import Icon from "../components/Icon";
import { session } from "../services/apiClient";
import "../styles/landing.css";

// Everything the page claims is something the product does today (S2): barcode and weighed
// sales, partial payment and debt with a per-customer limit, final invoices voided with a
// reason, stock with low-stock alerts, roles, and the web dashboard. Screens are illustrations.

const NAV = [
  ["#pos", "البيع"],
  ["#debts", "الديون"],
  ["#dashboard", "لوحة الإدارة"],
  ["#faq", "الأسئلة"],
];

/** The items scattered along the hero's lower edge: a shop's day, one ticket at a time. */
// x is measured from the start (right) edge, y from the top of the hero; the copy sits in the middle.
const TICKETS = [
  { x: 3, y: 17, r: -8, icon: "barcode", t: "6251234567890", ltr: true },
  { x: 72, y: 15, r: 6, t: "حليب طويل الأجل", s: "₪6.50" },
  { x: 12, y: 39, r: 5, icon: "scale", t: "لوز نيء", s: "0.750 كغ" },
  { x: 82, y: 37, r: -6, t: "أبو محمد", s: "باقي ₪44.50", debt: true },
  { x: 4, y: 61, r: -5, icon: "check", t: "تم البيع", ok: true },
  { x: 74, y: 60, r: 7, t: "كولا علبة", s: "×2" },
  { x: 14, y: 82, r: 6, t: "سكر 1 كغ", s: "₪5.00" },
  { x: 83, y: 81, r: -7, icon: "scale", t: "بهارات مشكلة", s: "0.250 كغ" },
];

const FAQ = [
  ["هل يحتاج حسبة إلى إنترنت؟", "نعم، حالياً. البيع يُحفظ على الخادم لحظة تأكيده. وإن انقطع الاتصال أثناء الحفظ تعيد المحاولة، ولا يتكرر البيع مرتين. العمل دون اتصال قيد التطوير."],
  ["أبيع بالكيلو وبالقطعة معاً، هل يناسبني؟", "نعم. تحدد لكل منتج وحدته: قطعة أو كيلو. منتجات الكيلو تفتح شاشة لإدخال الوزن حتى الغرام، ويُحسب السعر تلقائياً."],
  ["ماذا لو أخطأ الموظف في فاتورة؟", "لا تُعدَّل الفاتورة بعد حفظها. يلغيها المالك أو المدير مع كتابة السبب، فيعود المخزون ويُلغى الدين المرتبط، وتبقى الفاتورة في السجل بحالة «ملغاة»."],
  ["هل أستطيع تحديد سقف دين لكل زبون؟", "نعم. إن تجاوز البيع سقف الزبون يُمنع الموظف من إتمامه، ويستطيع المالك أو المدير المتابعة بعد موافقة صريحة تُسجَّل باسمه."],
  ["من يرى بيانات متجري؟", "أنت وموظفوك فقط. كل متجر يرى بياناته وحده، والعمليات المالية مسجّلة في سجل تدقيق باسم من قام بها."],
  ["هل أحتاج أجهزة خاصة؟", "لا. البيع من جوال أندرويد يمسح الباركود بكاميرته، والإدارة من متصفح أي حاسوب."],
];

function Feature({ id, kicker, title, text, points, panel, tone, flip, children }) {
  return (
    <section id={id} className={`lp-feature${flip ? " flip" : ""}`} aria-labelledby={`${id}-t`} data-reveal>
      <div className="lp-wrap lp-feature-grid">
        <div className="lp-copy">
          <p className="lp-kicker">{kicker}</p>
          <h2 id={`${id}-t`}>{title}</h2>
          <p className="lp-text">{text}</p>
          {points ? (
            <ul className="lp-points">
              {points.map((p) => (
                <li key={p}>{p}</li>
              ))}
            </ul>
          ) : null}
          {children}
        </div>
        <div className={`lp-panel tone-${tone}`} aria-hidden="true">
          {panel}
        </div>
      </div>
    </section>
  );
}

/** The public landing page (Arabic only). */
export default function Landing() {
  const [scrolled, setScrolled] = useState(false);
  const root = useRef(null);
  // A stored session swaps «sign in / create a store» for the dashboard. An expired token is
  // caught by the dashboard's first call (401 → /login?expired=1), so it is not checked here.
  const [signedIn] = useState(() => Boolean(session.token()));
  const storeName = signedIn ? session.user()?.store?.name : null;

  // Sections fade up once as they enter the viewport. Without IntersectionObserver nothing is hidden.
  useEffect(() => {
    const el = root.current;
    if (!el || !("IntersectionObserver" in window)) return undefined;
    el.classList.add("reveal-on");
    const io = new IntersectionObserver(
      (entries) =>
        entries.forEach((e) => {
          if (!e.isIntersecting) return;
          e.target.classList.add("in");
          io.unobserve(e.target);
        }),
      { threshold: 0.18, rootMargin: "0px 0px -40px 0px" },
    );
    el.querySelectorAll("[data-reveal]").forEach((n) => io.observe(n));
    return () => io.disconnect();
  }, []);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div className="lp" ref={root}>
      <a href="#main" className="skip-link">
        تخطَّ إلى المحتوى
      </a>
      <header className={scrolled ? "lp-head scrolled" : "lp-head"}>
        <div className="lp-wrap lp-head-row">
          <Link to="/" className="lp-brand" aria-label="حسبة — الصفحة الرئيسية">
            <HisbahLogo size={34} />
          </Link>
          <nav className="lp-nav" aria-label="أقسام الصفحة">
            {NAV.map(([href, label]) => (
              <a key={href} href={href}>
                {label}
              </a>
            ))}
          </nav>
          <div className="lp-head-actions">
            {signedIn ? (
              <Link to="/dashboard" className="lp-btn solid">
                لوحة التحكم
              </Link>
            ) : (
              <>
                <Link to="/login" className="lp-btn outline">
                  تسجيل الدخول
                </Link>
                <Link to="/join" className="lp-btn solid">
                  أنشئ متجرك
                </Link>
              </>
            )}
          </div>
        </div>
      </header>

      <main id="main">
        <section className="lp-hero" aria-labelledby="hero-t">
          <div className="lp-wrap lp-hero-copy">
            <div className="lp-pills">
              <span className="lp-pill">
                <i className="on" aria-hidden="true" />
                لوحة الإدارة متاحة الآن
              </span>
              <span className="lp-pill">
                <i aria-hidden="true" />
                البيع من تطبيق الجوال
              </span>
            </div>
            <h1 id="hero-t">
              دفتر متجرك،
              <br />
              في جيبك
            </h1>
            <p className="lp-lede">
              حسبة يسجّل البيع والدين والمخزون لمتجرك: تبيع من الجوال داخل المحل، وتتابع كل شيء من لوحة الإدارة. مصمم للبقالات والمحامص ومحلات البهارات.
            </p>
            <Link to={signedIn ? "/dashboard" : "/join"} className="lp-cta-card">
              <span className="cta-tile" aria-hidden="true">
                <HisbahMark size={30} />
              </span>
              {signedIn ? (
                <span>
                  <b>افتح لوحة التحكم</b>
                  <small>{storeName ?? "مبيعات اليوم وديونه ومخزونه"}</small>
                </span>
              ) : (
                <span>
                  <b>أنشئ متجرك في حسبة</b>
                  <small>البيع من الجوال، والإدارة من الحاسوب</small>
                </span>
              )}
            </Link>
            <a href="#dashboard" className="lp-underline">
              تملك متجراً؟ اعرف عن لوحة الإدارة
            </a>
          </div>
          <div className="lp-tickets" aria-hidden="true">
            {TICKETS.map((k, i) => (
              <span
                key={k.t}
                className={`ticket${k.debt ? " debt" : ""}${k.ok ? " ok" : ""}`}
                style={{ "--x": `${k.x}%`, "--y": `${k.y}%`, "--r": `${k.r}deg`, "--i": i }}
              >
                {k.icon ? <Icon name={k.icon} size={18} strokeWidth={2.2} /> : null}
                <b className={k.ltr ? "m" : undefined}>{k.t}</b>
                {k.s ? <span className="m">{k.s}</span> : null}
              </span>
            ))}
          </div>
        </section>

        <Feature
          id="pos"
          tone="sand"
          kicker="البيع بالباركود والوزن"
          title={<>امسح المنتج، والسعر محسوب</>}
          text="امسح الباركود بكاميرا الجوال. مسح المنتج نفسه مرة ثانية يزيد الكمية بدل أن يكرر السطر، ومنتجات الكيلو تُوزن حتى الغرام."
          panel={
            <div className="mock-pos">
              <div className="mock-search">
                <Icon name="barcode" size={22} strokeWidth={2.2} />
                <span className="m">6251234567890</span>
                <i className="caret" />
                <i className="beam" />
              </div>
              <div className="mock-card tilt-l">
                <div className="mock-row hl">
                  <span>
                    <b>حليب طويل الأجل 1 لتر</b>
                    <small>
                      <span className="m">2</span> قطعة · <span className="chip ink">+1 بالمسح</span>
                    </small>
                  </span>
                  <b className="m">₪13.00</b>
                </div>
                <div className="mock-row">
                  <span>
                    <b>لوز نيء</b>
                    <small className="m">0.750 كغ</small>
                  </span>
                  <b className="m">₪30.00</b>
                </div>
                <div className="mock-row">
                  <span>
                    <b>كولا علبة</b>
                    <small>
                      <span className="m">1</span> قطعة
                    </small>
                  </span>
                  <b className="m">₪3.50</b>
                </div>
              </div>
            </div>
          }
        />

        <Feature
          id="debts"
          tone="mint"
          flip
          kicker="الدين والدفع الجزئي"
          title={<>الدين باسم الزبون، والباقي محسوب</>}
          text="يدفع الزبون جزءاً ويُسجَّل الباقي ديناً باسمه."
          points={["موعد سداد لكل دين", "سقف دين لكل زبون لا يتخطاه الموظف", "تسجيل الدفعات وسداد كل الديون دفعة واحدة", "قائمة بالديون المستحقة في لوحة الإدارة"]}
          panel={
            <div className="mock-card tilt-r mock-status">
              <p className="mock-title">أبو محمد</p>
              <div className="st done">
                <Icon name="check" size={16} strokeWidth={3} />
                <span>
                  فاتورة بـ <b className="m">₪64.50</b>
                </span>
              </div>
              <div className="st done">
                <Icon name="check" size={16} strokeWidth={3} />
                <span>
                  دفع نقداً <b className="m">₪20.00</b>
                </span>
              </div>
              <div className="st">
                <i />
                <span>
                  باقي ديناً <b className="m">₪44.50</b>
                </span>
                <span className="chip sand">سقف ₪300</span>
              </div>
            </div>
          }
        />

        <Feature
          id="invoices"
          tone="lilac"
          kicker="فاتورة لا تُمحى"
          title={<>كل بيع له فاتورة نهائية</>}
          text="الفاتورة نهائية بعد البيع. الخطأ يُصحَّح بإلغاء له سبب، يعيد المخزون ويلغي الدين، ويبقى في السجل باسم من ألغاه."
          panel={
            <div className="mock-card tilt-r mock-receipt">
              <div className="rc-head">
                <b>بقالة النور</b>
                <span className="chip mint">
                  فاتورة <span className="m">#1042</span>
                </span>
              </div>
              <div className="rc-line">
                <span>
                  حليب طويل الأجل × <span className="m">2</span>
                </span>
                <span className="m">13.00</span>
              </div>
              <div className="rc-line">
                <span>
                  لوز نيء <span className="m">0.750</span> كغ
                </span>
                <span className="m">30.00</span>
              </div>
              <div className="rc-total">
                <b>الإجمالي</b>
                <b className="m">₪64.50</b>
              </div>
              <div className="rc-pay">
                <span className="chip">
                  نقداً <span className="m">20.00</span>
                </span>
                <span className="chip coral">
                  دين <span className="m">44.50</span>
                </span>
              </div>
            </div>
          }
        />

        <Feature
          id="stock"
          tone="coral"
          flip
          kicker="المنتجات والمخزون"
          title={<>المخزون ينقص مع كل بيع</>}
          text="بالقطعة أو بالكيلو، مع الباركود وسعر البيع والحد الأدنى. البيع فوق الكمية المسجلة مسموح مع تنبيه للمراجعة، وقائمة بما قارب على النفاد."
          panel={
            <div className="mock-labels">
              {[
                ["products", "بالقطعة", "mint"],
                ["scale", "بالكيلو", "sand"],
                ["low", "قارب على النفاد", "coral"],
                ["sales", "حركة المخزون", "sky"],
              ].map(([icon, text, tone], i) => (
                <span key={text} className={`label tilt-${i % 2 ? "r" : "l"}${icon === "low" ? " alert" : ""}`}>
                  <span className={`ic-dot ${tone}`}>
                    <Icon name={icon} size={18} strokeWidth={2} />
                  </span>
                  <b>{text}</b>
                </span>
              ))}
            </div>
          }
        />

        <Feature
          id="staff"
          tone="teal"
          kicker="الموظفون والصلاحيات"
          title={<>كل واحد يرى ما يخصه</>}
          text="المالك يدعو موظفيه. الموظف يبيع ويسجل الدفعات، والمالك أو المدير وحده يلغي الفاتورة أو يتجاوز سقف الدين."
          panel={
            <div className="mock-card tilt-l mock-roles">
              {[
                ["مالك", "كل شيء، ودعوة الموظفين"],
                ["مدير", "يلغي الفواتير ويتجاوز السقف"],
                ["موظف", "يبيع ويسجل الدفعات"],
              ].map(([role, can]) => (
                <div key={role} className="role">
                  <span className="avatar-s">{role[0]}</span>
                  <span>
                    <b>{role}</b>
                    <small>{can}</small>
                  </span>
                </div>
              ))}
            </div>
          }
        />

        <Feature
          id="dashboard"
          tone="sky"
          flip
          kicker="لوحة الإدارة"
          title={<>متجرك كله، في لوحة واحدة</>}
          text="مبيعات اليوم والأسبوع والشهر، ما دخل نقداً وما صار ديناً، والديون المستحقة والمنتجات المنخفضة، من متصفح أي حاسوب."
          panel={
            <div className="mock-window">
              <div className="win-bar">
                <span>لوحة إدارة حسبة</span>
                <i />
                <i />
                <i />
              </div>
              <div className="win-grid">
                <div className="tile">
                  <span className="tl">المبيعات</span>
                  <b className="m">₪64.50</b>
                  <span className="bars">
                    <i style={{ height: "40%" }} />
                    <i style={{ height: "70%" }} />
                    <i style={{ height: "55%" }} />
                    <i style={{ height: "90%" }} />
                  </span>
                </div>
                <div className="tile">
                  <span className="tl">الديون المستحقة</span>
                  <b className="m">₪44.50</b>
                  <span className="chip coral">زبون واحد</span>
                </div>
                <div className="tile">
                  <span className="tl">نقداً / ديناً</span>
                  <span className="split-bar">
                    <i style={{ width: "31%" }} />
                  </span>
                  <small className="m">20.00 / 44.50</small>
                </div>
                <div className="tile">
                  <span className="tl">منخفض المخزون</span>
                  <span className="chip sand">كولا علبة</span>
                  <small>
                    <span className="m">2</span> من حد <span className="m">6</span>
                  </small>
                </div>
              </div>
            </div>
          }
        >
          <Link to={signedIn ? "/dashboard" : "/join"} className="lp-btn solid big">
            {signedIn ? "افتح لوحة التحكم" : "أنشئ متجرك"}
          </Link>
        </Feature>
        <p className="lp-wrap lp-fineprint">الشاشات توضيحية ببيانات تجريبية.</p>

        <section id="faq" className="lp-faq" aria-labelledby="faq-t">
          <div className="lp-wrap narrow" data-reveal>
            <p className="lp-kicker center">الأسئلة الشائعة</p>
            <h2 id="faq-t">عندك سؤال؟</h2>
            <div className="faq-list">
              {FAQ.map(([q, a], i) => (
                <details key={q} name="faq" open={i === 0}>
                  <summary>
                    <span>{q}</span>
                    <span className="faq-ic" aria-hidden="true">
                      <Icon name="plus" size={18} strokeWidth={2.4} className="plus" />
                      <Icon name="minus" size={18} strokeWidth={2.4} className="minus" />
                    </span>
                  </summary>
                  <p>{a}</p>
                </details>
              ))}
            </div>
          </div>
        </section>

        <section className="lp-close" aria-labelledby="close-t">
          <div className="lp-wrap lp-close-grid" data-reveal>
            <div className="lp-copy">
              <h2 id="close-t">
                دفتر المحل،
                <br />
                صار أخف
              </h2>
              {signedIn ? (
                <>
                  <p className="lp-text">تابع مبيعات اليوم والديون والمخزون من لوحة التحكم.</p>
                  <div className="lp-close-actions">
                    <Link to="/dashboard" className="lp-btn solid big">
                      افتح لوحة التحكم
                    </Link>
                  </div>
                </>
              ) : (
                <>
                  <p className="lp-text">أنشئ المتجر الآن، وأضف أول منتج، وسجّل أول بيع من الجوال.</p>
                  <div className="lp-close-actions">
                    <Link to="/join" className="lp-btn solid big">
                      أنشئ متجرك
                    </Link>
                    <Link to="/login" className="lp-btn outline big">
                      تسجيل الدخول
                    </Link>
                  </div>
                </>
              )}
            </div>
            <div className="phone" aria-hidden="true">
              <div className="phone-screen">
                <p className="ph-title">بيع جديد</p>
                <div className="ph-search">
                  <Icon name="search" size={14} />
                  <span>ابحث أو امسح الباركود</span>
                </div>
                {[
                  ["حليب طويل الأجل", "2 قطعة", "13.00"],
                  ["لوز نيء", "0.750 كغ", "30.00"],
                  ["كولا علبة", "1 قطعة", "3.50"],
                  ["سكر 1 كغ", "1 قطعة", "5.00"],
                ].map(([n, q, p]) => (
                  <div key={n} className="ph-row">
                    <span>
                      <b>{n}</b>
                      <small className="m">{q}</small>
                    </span>
                    <b className="m">₪{p}</b>
                  </div>
                ))}
                <div className="ph-pay">
                  إتمام البيع <span className="m">₪51.50</span>
                </div>
              </div>
            </div>
          </div>
        </section>
      </main>

      <footer className="lp-foot">
        <div className="lp-wrap">
          <div className="lp-foot-grid">
            <div className="lp-foot-brand">
              <HisbahLogo size={34} />
              <p>البيع والدين والمخزون لمتجرك، بالعربية وبالأرقام كما تقرؤها على الميزان.</p>
            </div>
            <nav aria-label="المتجر">
              <h3>المتجر</h3>
              <a href="#pos">البيع بالباركود</a>
              <a href="#debts">الديون</a>
              <a href="#stock">المخزون</a>
            </nav>
            <nav aria-label="حسبة">
              <h3>حسبة</h3>
              <a href="#dashboard">لوحة الإدارة</a>
              <a href="#faq">الأسئلة الشائعة</a>
            </nav>
            <nav aria-label="حسابك">
              <h3>حسابك</h3>
              {signedIn ? (
                <Link to="/dashboard">لوحة التحكم</Link>
              ) : (
                <>
                  <Link to="/login">تسجيل الدخول</Link>
                  <Link to="/join">إنشاء متجر</Link>
                </>
              )}
            </nav>
          </div>
          <div className="lp-foot-bottom">
            <span>
              © <span className="m">2026</span> حسبة. جميع الحقوق محفوظة.
            </span>
            <span>دفتر متجرك، في جيبك</span>
          </div>
        </div>
        <p className="lp-giant" aria-hidden="true">
          حسبة
        </p>
      </footer>
    </div>
  );
}
