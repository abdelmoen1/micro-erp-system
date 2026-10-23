import { useState } from "react";
import { useSearchParams } from "react-router-dom";
import Icon from "../components/Icon";
import { amountNumber, arCount, dayMonthYear, isPositiveAmount, monthName, shekel, shortReference, weekdayName } from "../lib/format";
import { session } from "../services/apiClient";
import { useDashboard, useLowStock, useProductCount } from "../services/dashboard";

const PERIODS = [
  ["today", "اليوم"],
  ["this_week", "هذا الأسبوع"],
  ["this_month", "هذا الشهر"],
  ["this_year", "هذه السنة"],
];

const CHART_TITLE = {
  today: ["اليوم حسب الساعة", "الساعة"],
  this_week: ["هذا الأسبوع حسب اليوم", "اليوم"],
  this_month: ["هذا الشهر حسب اليوم", "اليوم"],
  this_year: ["هذه السنة حسب الشهر", "الشهر"],
};

/** «الثلاثاء · 20/10/2026», «من السبت · 17/10 – 23/10/2026», … in the store timezone. */
function periodLine(period, data) {
  const tz = data?.period?.timezone;
  const from = data?.period?.from ? new Date(data.period.from) : new Date();
  const to = data?.period?.to ? new Date(data.period.to) : new Date();
  const short = (d) => dayMonthYear(d, tz).slice(0, 5);
  switch (period) {
    case "today":
      return [weekdayName(from, tz), dayMonthYear(from, tz)];
    case "this_week":
      return [`من ${weekdayName(from, tz)}`, `${short(from)} – ${dayMonthYear(to, tz)}`];
    case "this_month":
      return [monthName(from, tz), `${short(from)} – ${dayMonthYear(to, tz)}`];
    default:
      return ["السنة", dayMonthYear(from, tz).slice(6)];
  }
}

/** Chart buckets: hours today, days for week / month, months for the year. */
function buckets(period, data) {
  if (!data) return [];
  const tz = data.period?.timezone;
  // An API without the hourly series (before S2) falls through to the daily one.
  if (period === "today" && data.charts?.sales_hourly) {
    return data.charts.sales_hourly.map((b) => ({
      label: `${b.hour}:00`,
      tick: Number(b.hour) % 3 === 0 ? b.hour : "",
      amount: b.amount,
    }));
  }
  return (data.charts?.sales ?? []).map((b) => {
    if (period === "this_year" || b.month) {
      const d = new Date(`${b.month ?? String(b.date).slice(0, 7)}-01T12:00:00Z`);
      return { label: monthName(d, "UTC"), tick: String(d.getUTCMonth() + 1), amount: b.amount };
    }
    const d = new Date(`${b.date}T12:00:00Z`);
    const day = d.getUTCDate();
    if (period === "this_week") return { label: weekdayName(d, tz ?? "UTC"), tick: String(day), amount: b.amount };
    return { label: `${day}/${d.getUTCMonth() + 1}`, tick: day === 1 || day % 5 === 0 ? String(day) : "", amount: b.amount };
  });
}

function Kpi({ label, icon, tone = "brand", value, sub, loading, color }) {
  return (
    <div className="card kpi">
      <div className="kpi-top">
        <span className="kpi-label">{label}</span>
        <span className={`kpi-ic ${tone}`} aria-hidden="true">
          <Icon name={icon} size={18} strokeWidth={1.8} />
        </span>
      </div>
      {loading ? (
        <>
          <span className="sk" style={{ width: "60%", height: 28, marginTop: 4 }} />
          <span className="sk" style={{ width: "80%", height: 12, marginTop: 6 }} />
        </>
      ) : (
        <>
          <span className="kpi-value m" style={{ color }}>
            {value}
          </span>
          <span className="kpi-sub">{sub}</span>
        </>
      )}
    </div>
  );
}

const CW = 1000;
const CH = 220;

/** Catmull-Rom through the points as cubic Béziers, kept inside the plot (no dip below zero). */
function smoothPath(points) {
  if (points.length < 2) return points.length ? `M${points[0][0]},${points[0][1]}` : "";
  const clamp = (v) => Math.min(CH, Math.max(0, v));
  let d = `M${points[0][0]},${points[0][1]}`;
  for (let i = 0; i < points.length - 1; i++) {
    const [p0, p1, p2, p3] = [points[i - 1] ?? points[i], points[i], points[i + 1], points[i + 2] ?? points[i + 1]];
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, clamp(p1[1] + (p2[1] - p0[1]) / 6)];
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, clamp(p2[1] - (p3[1] - p1[1]) / 6)];
    d += ` C${c1[0]},${c1[1]} ${c2[0]},${c2[1]} ${p2[0]},${p2[1]}`;
  }
  return d;
}

/** Sales as a smooth area (time runs left to right); the pointer picks the nearest bucket. */
function AreaChart({ rows, values, max, hover, setHover }) {
  const n = values.length;
  const x = (i) => (n <= 1 ? CW / 2 : (i / (n - 1)) * CW);
  const y = (v) => CH - 4 - (max > 0 ? (v / max) * (CH - 24) : 0);
  const points = values.map((v, i) => [x(i), y(v)]);
  const line = smoothPath(points);
  const area = `${line} L${x(n - 1)},${CH} L${x(0)},${CH} Z`;
  const pick = (event) => {
    const box = event.currentTarget.getBoundingClientRect();
    const ratio = (event.clientX - box.left) / box.width;
    setHover(Math.max(0, Math.min(n - 1, Math.round(ratio * (n - 1)))));
  };
  const at = hover >= 0 ? points[hover] : null;

  return (
    <div className="area" onMouseMove={pick} onMouseLeave={() => setHover(-1)} aria-hidden="true">
      <svg viewBox={`0 0 ${CW} ${CH}`} preserveAspectRatio="none" focusable="false">
        <defs>
          <linearGradient id="area-fill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="var(--accent-600)" stopOpacity="0.28" />
            <stop offset="100%" stopColor="var(--accent-600)" stopOpacity="0" />
          </linearGradient>
        </defs>
        {[0.25, 0.5, 0.75].map((f) => (
          <line key={f} x1="0" x2={CW} y1={CH * f} y2={CH * f} className="area-grid" vectorEffect="non-scaling-stroke" />
        ))}
        <path d={area} fill="url(#area-fill)" className="area-fill" />
        <path d={line} className="area-line" vectorEffect="non-scaling-stroke" />
        {at ? <line x1={at[0]} x2={at[0]} y1="0" y2={CH} className="area-guide" vectorEffect="non-scaling-stroke" /> : null}
      </svg>
      {at ? (
        <>
          <span className="area-dot" style={{ left: `${(at[0] / CW) * 100}%`, top: `${(at[1] / CH) * 100}%` }} />
          <span className="area-tip" style={{ left: `${Math.min(88, Math.max(12, (at[0] / CW) * 100))}%`, top: `${(at[1] / CH) * 100}%` }}>
            <b>{rows[hover].label}</b>
            <span className="m">{shekel(rows[hover].amount)}</span>
          </span>
        </>
      ) : null}
    </div>
  );
}

function SalesChart({ period, rows, loading }) {
  const [hover, setHover] = useState(-1);
  const [table, setTable] = useState(false);
  const [title, column] = CHART_TITLE[period];
  const values = rows.map((r) => amountNumber(r.amount));
  const max = Math.max(0, ...values);
  const maxRow = rows[values.indexOf(max)];
  const empty = !loading && max === 0;
  const hovered = hover >= 0 ? rows[hover] : null;

  return (
    <section className="card panel" aria-labelledby="w5-chart-t" style={{ flex: "2 1 480px" }}>
      <div className="panel-head">
        <h2 id="w5-chart-t">المبيعات {title}</h2>
        {!empty && !loading ? (
          <button type="button" className="text-btn" onClick={() => setTable((t) => !t)} aria-pressed={table}>
            {table ? "عرض كرسم" : "عرض كجدول"}
          </button>
        ) : null}
      </div>
      {loading ? (
        <div className="sk" style={{ height: 220 }} />
      ) : empty ? (
        <div className="chart-empty">
          <b>لا مبيعات في هذه الفترة</b>
          <span style={{ fontSize: 14, color: "var(--ink-muted)" }}>المبيعات تُسجَّل من تطبيق الجوال وتظهر هنا مباشرة.</span>
        </div>
      ) : table ? (
        <div className="table-box">
          <table>
            <thead>
              <tr style={{ background: "var(--ground)" }}>
                <th scope="col" style={{ textAlign: "right", padding: "8px 12px" }}>
                  {column}
                </th>
                <th scope="col" style={{ textAlign: "left", padding: "8px 12px" }}>
                  المبيعات
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.label} style={{ borderTop: "1px solid var(--border)" }}>
                  <td style={{ padding: "6px 12px" }}>{r.label}</td>
                  <td className="m" style={{ padding: "6px 12px", textAlign: "left" }}>
                    {shekel(r.amount)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <>
          <div className="chart-note" aria-live="polite">
            {hovered ? (
              <>
                <b style={{ color: "var(--ink)" }}>{hovered.label}</b> · <span className="m" style={{ color: "var(--ink)", fontWeight: 700 }}>{shekel(hovered.amount)}</span>
              </>
            ) : (
              <>
                مرّر فوق الرسم لرؤية القيمة · أعلى قيمة <span className="m" style={{ color: "var(--ink)", fontWeight: 700 }}>{shekel(maxRow?.amount)}</span>
              </>
            )}
          </div>
          <AreaChart rows={rows} values={values} max={max} hover={hover} setHover={setHover} />
          <div className="ticks" aria-hidden="true">
            {rows.map((r) => (
              <span key={r.label} className="m">
                {r.tick}
              </span>
            ))}
          </div>
        </>
      )}
    </section>
  );
}

function LowStock({ loading }) {
  const low = useLowStock();
  const count = useProductCount();
  const rows = low.data ?? [];
  const busy = loading || low.isPending;
  const noProducts = count.data === 0;

  return (
    <section className="card panel" aria-labelledby="w5-low-t" style={{ flex: "1 1 300px", gap: 10 }}>
      <div className="panel-head">
        <h2 id="w5-low-t">مخزون منخفض</h2>
      </div>
      {busy ? (
        ["70%", "55%", "62%", "48%"].map((w) => (
          <div key={w} style={{ display: "flex", justifyContent: "space-between", padding: "10px 0", borderTop: "1px solid var(--border)" }}>
            <span className="sk" style={{ width: w, height: 14 }} />
            <span className="sk" style={{ width: 60, height: 14 }} />
          </div>
        ))
      ) : low.isError ? (
        // A failed request is not «everything above the minimum».
        <div role="alert" className="state-card" style={{ padding: "24px 8px", gap: 8 }}>
          <b>تعذّر تحميل المخزون</b>
          <button type="button" className="btn btn-g btn-sm" onClick={() => low.refetch()}>
            إعادة المحاولة
          </button>
        </div>
      ) : rows.length === 0 ? (
        <div className="state-card" style={{ padding: "24px 8px", gap: 8 }}>
          <b>{noProducts ? "لا منتجات بعد" : "لا منتجات تحت الحد الأدنى"}</b>
          <span style={{ fontSize: 14, color: "var(--ink-muted)", lineHeight: 1.6 }}>
            {noProducts
              ? "أضف منتجاتك وحدّد الحد الأدنى لكل منها لتظهر هنا عند انخفاضها."
              : "كل المنتجات فوق الحد الأدنى الذي حددته."}
          </span>
        </div>
      ) : (
        <ul className="list">
          {rows.map((p) => {
            const out = amountNumber(p.current_stock) <= 0;
            const unit = p.unit === "kg" ? " كغ" : "";
            return (
              <li key={p.id}>
                <span style={{ display: "flex", flexDirection: "column", minWidth: 0 }}>
                  <span style={{ fontSize: 14, fontWeight: 600 }}>{p.name}</span>
                  <span style={{ fontSize: 12, color: "var(--ink-muted)" }}>
                    الحد الأدنى <span className="m">{p.minimum_stock}</span>
                    {unit}
                  </span>
                </span>
                <span className={out ? "pill out" : "pill low"}>
                  <Icon name={out ? "ban" : "low"} size={14} strokeWidth={2.2} />
                  {out ? (
                    "نفد"
                  ) : (
                    <>
                      متبقٍّ <span className="m">{p.current_stock}</span>
                      {unit}
                    </>
                  )}
                </span>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}

function RecentSales({ rows, loading }) {
  return (
    <section className="card panel" aria-labelledby="w5-rec-t" style={{ gap: 10 }}>
      <div className="panel-head">
        <h2 id="w5-rec-t">آخر المبيعات</h2>
      </div>
      {loading ? (
        ["70%", "55%", "62%", "48%"].map((w) => (
          <div key={w} style={{ display: "flex", justifyContent: "space-between", gap: 16, padding: "12px 0", borderTop: "1px solid var(--border)" }}>
            <span className="sk" style={{ width: 60, height: 14 }} />
            <span className="sk" style={{ width: w, height: 14 }} />
            <span className="sk" style={{ width: 80, height: 14 }} />
          </div>
        ))
      ) : rows.length === 0 ? (
        <p style={{ padding: "24px 8px", textAlign: "center", fontSize: 14, color: "var(--ink-muted)" }}>
          لا فواتير بعد. ستظهر هنا أول فاتورة بعد البيع من تطبيق الجوال.
        </p>
      ) : (
        <div style={{ overflowX: "auto" }}>
          <table style={{ minWidth: 520 }}>
            <thead>
              <tr style={{ color: "var(--ink-muted)", fontSize: 13 }}>
                <th scope="col" style={{ textAlign: "right", padding: "8px 10px" }}>الفاتورة</th>
                <th scope="col" style={{ textAlign: "right", padding: "8px 10px" }}>الزبون</th>
                <th scope="col" style={{ textAlign: "right", padding: "8px 10px" }}>الحالة</th>
                <th scope="col" style={{ textAlign: "left", padding: "8px 10px" }}>المبلغ</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const cash = r.type === "cash";
                return (
                  <tr key={r.id} style={{ borderTop: "1px solid var(--border)" }}>
                    <td className="m" style={{ padding: 10, textAlign: "right", fontWeight: 600 }}>
                      #{r.id}
                    </td>
                    <td style={{ padding: 10, color: r.customer ? "var(--ink)" : "var(--ink-muted)" }}>{r.customer?.name ?? "بدون زبون"}</td>
                    <td style={{ padding: 10 }}>
                      <span className={cash ? "pill paid" : "pill debt"}>
                        <Icon name={cash ? "ok" : "dot"} size={14} strokeWidth={2.2} />
                        {cash ? "مدفوع" : "دين"}
                      </span>
                    </td>
                    <td className="m" style={{ padding: 10, textAlign: "left", fontWeight: 700 }}>
                      {shekel(r.total_amount)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}

/** SCR-W-05 · dashboard (US-0802): period, KPIs, sales chart, low stock, latest sales. */
export default function Dashboard() {
  const [params, setParams] = useSearchParams();
  const period = PERIODS.some(([key]) => key === params.get("period")) ? params.get("period") : "today";
  const setPeriod = (key) => setParams(key === "today" ? {} : { period: key }, { replace: true });
  const dashboard = useDashboard(period);
  const data = dashboard.data;
  const loading = dashboard.isPending;
  const role = session.user()?.role ?? "employee";
  const [sub, range] = periodLine(period, data);

  const s = data?.summary;
  const invoices = s?.invoices_count ?? 0;
  const payments = data?.payments?.count ?? 0;
  const debtors = data?.customers?.with_outstanding_debts ?? 0;
  const actions = role === "employee" ? ["زبون جديد", "تسجيل دفعة"] : ["منتج جديد", "زبون جديد", "تسجيل دفعة"];
  // Before S2 the API had no collected/new-debt split; cash and credit sales are the same idea.
  const cashPart = s?.collected_at_sale ?? s?.cash_sales;
  const debtPart = s?.new_debt ?? s?.credit_sales;
  const firstName = (session.user()?.name ?? "").split(" ")[0];

  return (
    <>
      <header className="dash-head">
        <div className="dash-title">
          <h1>الرئيسية</h1>
          <span className="sub">
            {firstName ? `أهلاً ${firstName} · ` : ""}
            {sub} · <span className="m">{range}</span>
          </span>
        </div>
        <div className="segs" role="group" aria-label="الفترة">
          {PERIODS.map(([key, label]) => (
            <button key={key} type="button" className="seg" aria-pressed={period === key} onClick={() => setPeriod(key)}>
              {label}
            </button>
          ))}
        </div>
      </header>

      <div className="actions">
        {actions.map((label) => (
          <button key={label} type="button" className="btn btn-s btn-sm" disabled title="تُضاف مع شاشات الإدارة القادمة">
            <Icon name="plus" size={16} strokeWidth={2.2} />
            {label}
          </button>
        ))}
      </div>

      {dashboard.isError ? (
        <div role="alert" className="card state-card">
          <Icon name="alert" size={40} color="var(--error-fg)" strokeWidth={1.8} />
          <b style={{ fontSize: 18 }}>تعذّر تحميل لوحة اليوم</b>
          <span style={{ fontSize: 15, color: "var(--ink-muted)" }}>
            تحقق من الاتصال ثم أعد المحاولة.
            {shortReference(dashboard.error?.correlationId) ? (
              <>
                {" "}
                إن تكرر الخطأ، أعطِ رمز المرجع للدعم: <span className="m">{shortReference(dashboard.error.correlationId)}</span>
              </>
            ) : null}
          </span>
          <button type="button" className="btn btn-p btn-sm" onClick={() => dashboard.refetch()}>
            إعادة المحاولة
          </button>
        </div>
      ) : (
        <>
          <div className="kpis" aria-busy={loading}>
            <Kpi
              label="المبيعات"
              icon="sales"
              loading={loading}
              value={shekel(s?.total_sales)}
              sub={
                invoices === 0 ? (
                  "لا فواتير في هذه الفترة"
                ) : (
                  <>
                    كاش <span className="m">{shekel(cashPart)}</span> · دين <span className="m">{shekel(debtPart)}</span>
                  </>
                )
              }
            />
            <Kpi
              label="تحصيلات الديون"
              icon="payments"
              tone="ok"
              loading={loading}
              value={shekel(data?.payments?.total_collected)}
              sub={payments === 0 ? "لا دفعات" : `${arCount(payments, { one: "دفعة واحدة", two: "دفعتان", few: "دفعات", many: "دفعة" })} من زبائن`}
            />
            <Kpi
              label="الديون المستحقة"
              icon="debts"
              tone="danger"
              loading={loading}
              value={shekel(s?.total_remaining_debt)}
              color={isPositiveAmount(s?.total_remaining_debt) ? "var(--debt-fg)" : undefined}
              sub={debtors === 0 ? "لا ديون مفتوحة" : `على ${arCount(debtors, { one: "زبون واحد", two: "زبونين", few: "زبائن", many: "زبوناً" })}`}
            />
            <Kpi label="عدد الفواتير" icon="products" tone="info" loading={loading} value={<span className="m">{invoices}</span>} sub={invoices === 0 ? "ابدأ البيع من تطبيق الجوال" : "في الفترة المحددة"} />
          </div>
          <div className="row2">
            <SalesChart key={period} period={period} rows={buckets(period, data)} loading={loading} />
            <LowStock loading={loading} />
          </div>
          <RecentSales rows={data?.recent_invoices ?? []} loading={loading} />
        </>
      )}
    </>
  );
}
