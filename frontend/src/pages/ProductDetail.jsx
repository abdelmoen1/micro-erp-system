import { useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { ConfirmSummary, Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, Field, Segments, StatusBadge } from "../components/ui";
import { newIdempotencyKey, session } from "../services/apiClient";
import { lookupCatalog, useAdjustStock, useDeactivateProduct, useMovements, useProduct, useSaveProduct } from "../services/backoffice";
import { canManage, stockState } from "../lib/domain";
import { dateTime } from "../lib/format";

const MOVEMENT = {
  opening: "رصيد افتتاحي",
  sale: "بيع",
  sale_void: "إلغاء فاتورة",
  sale_return: "مرتجع",
  adjustment_in: "تعديل: زيادة",
  adjustment_out: "تعديل: خصم",
};

const REASONS = ["جرد الرف", "تالف أو منتهي الصلاحية", "استلام بضاعة", "تصحيح خطأ إدخال"];

/** Thousandths as an integer from a quantity string (comparisons and the delta only). */
const milli = (value) => {
  const text = String(value ?? "0").trim();
  const negative = text.startsWith("-");
  const [whole, fraction = ""] = text.replace("-", "").split(".");
  const n = Number(whole || 0) * 1000 + Number(fraction.padEnd(3, "0").slice(0, 3));
  return negative ? -n : n;
};
const fromMilli = (n, unit) => {
  const sign = n < 0 ? "−" : n > 0 ? "+" : "";
  const abs = Math.abs(n);
  return unit === "kg" ? `${sign}${Math.floor(abs / 1000)}.${String(abs % 1000).padStart(3, "0")}` : `${sign}${abs / 1000}`;
};

/** SCR-W-09 · product form, movement history and stock adjustment with a reason (US-0405). */
export default function ProductDetail() {
  const { id } = useParams();
  const isNew = !id || id === "new";
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const manager = canManage(session.user());
  const product = useProduct(isNew ? null : id);
  const movements = useMovements(isNew ? null : id);
  const deactivate = useDeactivateProduct();

  if (!isNew && product.isError) return <ErrorState error={product.error} title="تعذّر فتح المنتج" onRetry={() => product.refetch()} />;
  if (!isNew && product.isPending) return <div className="card sk" style={{ height: 320 }} />;

  const p = product.data;
  const adjusting = params.get("adjust") === "1" && p;

  return (
    <>
      <Crumbs items={[["المنتجات", "/products"], [isNew ? "منتج جديد" : p.name]]} />
      <div className="split">
        <ProductForm key={p?.id ?? "new"} product={p} manager={manager} onSaved={(saved) => (isNew ? navigate(`/products/${saved.id}`, { replace: true }) : null)} />

        {!isNew ? (
          <section className="card panel" style={{ flex: "1 1 480px" }}>
            <div className="page-head">
              <h2 style={{ fontSize: 17 }}>حركات المخزون</h2>
              {manager ? (
                <button type="button" className="btn btn-s btn-sm" onClick={() => setParams({ adjust: "1" })}>
                  تعديل المخزون
                </button>
              ) : null}
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>
              <span className="field-hint">المخزون الآن</span>
              <b className="m" style={{ fontSize: 26 }}>
                {p.current_stock}
              </b>
              <span>{p.unit === "kg" ? "كغ" : "قطعة"}</span>
              <StatusBadge status={stockState(p)} />
            </div>
            <DataTable
              query={movements}
              rows={movements.data ?? []}
              minWidth={460}
              columns={[
                { key: "at", label: "التاريخ", render: (m) => <span className="m">{dateTime(m.created_at)}</span> },
                {
                  key: "type",
                  label: "الحركة",
                  render: (m) => (
                    <>
                      <b style={{ fontWeight: 600 }}>{MOVEMENT[m.type] ?? m.type}</b>
                      {m.reference_type === "invoice" ? (
                        <Link className="m" to={`/sales/${m.reference_id}`}>
                          {" "}
                          #{m.reference_id}
                        </Link>
                      ) : null}
                      {m.reason ? <span className="cell-sub">{m.reason}</span> : null}
                    </>
                  ),
                },
                {
                  key: "qty",
                  label: "الكمية",
                  numeric: true,
                  render: (m) => (
                    <span className="m" style={{ fontWeight: 700, color: milli(m.quantity) < 0 ? "var(--debt-fg)" : "var(--success-fg)" }}>
                      {milli(m.quantity) > 0 ? "+" : ""}
                      {m.quantity}
                    </span>
                  ),
                },
                { key: "after", label: "بعدها", numeric: true, render: (m) => <span className="m">{m.balance_after}</span> },
              ]}
              empty={<EmptyState icon="products" title="لا حركات بعد" />}
            />
            {manager && p.status === "active" ? (
              <button type="button" className="btn btn-t danger" disabled={deactivate.isPending} onClick={() => deactivate.mutate(p.id)} style={{ alignSelf: "flex-start" }}>
                إيقاف المنتج
              </button>
            ) : null}
          </section>
        ) : null}
      </div>
      {adjusting ? <AdjustDialog product={p} onClose={() => setParams({})} /> : null}
    </>
  );
}

function ProductForm({ product, manager, onSaved }) {
  const [form, setForm] = useState(() => ({
    name: product?.name ?? "",
    barcode: product?.barcode ?? "",
    unit: product?.unit ?? "piece",
    selling_price: product?.selling_price ?? "",
    cost_price: product?.cost_price ?? "",
    current_stock: product ? product.current_stock : "0",
    minimum_stock: product?.minimum_stock ?? "",
  }));
  const [match, setMatch] = useState(null);
  const save = useSaveProduct();

  // New products only: a barcode another store saved fills the shared name and unit; one already
  // in this store points to it instead (its stock changes by adjustment, not a second product).
  const checkCatalog = async () => {
    const code = form.barcode.trim();
    if (product || !code) return setMatch(null);
    try {
      const found = await lookupCatalog(code);
      setMatch(found);
      if (!found.product && found.catalog_product) {
        setForm((f) => ({ ...f, name: found.catalog_product.name, unit: found.catalog_product.unit }));
      }
    } catch {
      setMatch(null); // The server checks the barcode again on save.
    }
  };
  const err = (field) => save.error?.fieldError?.(field);
  const set = (field) => (e) => setForm({ ...form, [field]: e.target.value });
  const readOnly = !manager;

  const submit = (e) => {
    e.preventDefault();
    const body = {
      name: form.name.trim(),
      barcode: form.barcode.trim() || null,
      unit: form.unit,
      selling_price: String(form.selling_price).trim(),
      cost_price: String(form.cost_price).trim() || null,
      ...(String(form.minimum_stock).trim() ? { minimum_stock: String(form.minimum_stock).trim() } : {}),
      ...(product ? {} : { current_stock: String(form.current_stock).trim() || "0" }),
    };
    save.mutate(product ? { id: product.id, ...body } : body, { onSuccess: onSaved });
  };

  return (
    <form className="card panel form-stack" style={{ flex: "1 1 420px" }} onSubmit={submit} noValidate>
      <h1 style={{ fontSize: 22 }}>{product ? product.name : "منتج جديد"}</h1>
      <Field id="pf-name" label="اسم المنتج" error={err("name")}>
        <input id="pf-name" className={`fld${err("name") ? " err" : ""}`} value={form.name} onChange={set("name")} readOnly={readOnly} />
      </Field>
      <Field id="pf-barcode" label="الباركود" optional error={err("barcode")}>
        <input id="pf-barcode" className={`fld ltr m${err("barcode") ? " err" : ""}`} value={form.barcode} onChange={set("barcode")} onBlur={checkCatalog} readOnly={readOnly} />
      </Field>
      {match?.product ? (
        <p role="status" className="banner tone-pending">
          <span>
            هذا الباركود مسجّل في متجرك: <Link to={`/products/${match.product.id}`}>{match.product.name}</Link>
            <span className="sub">لن يُضاف مرة ثانية. عدّل مخزونه من صفحته.</span>
          </span>
        </p>
      ) : match?.catalog_product ? (
        <p role="status" className="banner tone-info">
          <span>
            منتج معروف في حسبة، فملأنا اسمه ووحدته.
            <span className="sub">أدخل سعر البيع والتكلفة والكمية لمتجرك. تعديل الاسم يخص متجرك وحده.</span>
          </span>
        </p>
      ) : null}
      <div className="field">
        <span className="field-label">يُباع</span>
        <Segments
          label="الوحدة"
          value={form.unit}
          options={[
            ["piece", "بالقطعة"],
            ["kg", "بالوزن (كغ)"],
          ]}
          onChange={(unit) => !readOnly && setForm({ ...form, unit })}
        />
        {err("unit") ? <span className="field-error">{err("unit")}</span> : <span className="field-hint">السعر لكل {form.unit === "kg" ? "كغ، والكمية حتى 3 خانات عشرية" : "قطعة"}.</span>}
      </div>
      <div className="grid2">
        <Field id="pf-price" label={form.unit === "kg" ? "سعر البيع لكل كغ" : "سعر البيع"} error={err("selling_price")}>
          <input id="pf-price" className="fld ltr m" inputMode="decimal" value={form.selling_price} onChange={set("selling_price")} readOnly={readOnly} />
        </Field>
        <Field id="pf-cost" label="سعر الشراء" optional error={err("cost_price")}>
          <input id="pf-cost" className="fld ltr m" inputMode="decimal" value={form.cost_price ?? ""} onChange={set("cost_price")} readOnly={readOnly} />
        </Field>
        <Field id="pf-stock" label={product ? "المخزون الحالي" : "المخزون الآن"} error={err("current_stock")} hint={product ? "يتغير بالبيع أو بتعديل المخزون مع سبب." : null}>
          <input id="pf-stock" className="fld ltr m" inputMode="decimal" value={form.current_stock} onChange={set("current_stock")} readOnly={Boolean(product) || readOnly} />
        </Field>
        <Field id="pf-min" label="الحد الأدنى للتنبيه" optional error={err("minimum_stock")}>
          <input id="pf-min" className="fld ltr m" inputMode="decimal" value={form.minimum_stock} onChange={set("minimum_stock")} readOnly={readOnly} />
        </Field>
      </div>
      <ErrorBanner error={save.error && !Object.keys(save.error.errors ?? {}).length ? save.error : null} />
      {save.isSuccess && product ? (
        <p role="status" className="banner tone-success">
          حُفظت التعديلات.
        </p>
      ) : null}
      {manager ? (
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={save.isPending}>
            {save.isPending ? "جارٍ الحفظ…" : product ? "حفظ التعديلات" : "حفظ المنتج"}
          </button>
          <Link className="btn btn-g" to="/products">
            إلغاء
          </Link>
        </div>
      ) : (
        <p className="field-hint">تعديل المنتجات للمالك أو المدير.</p>
      )}
    </form>
  );
}

function AdjustDialog({ product, onClose }) {
  const [mode, setMode] = useState("count");
  const [value, setValue] = useState("");
  const [reason, setReason] = useState(REASONS[0]);
  const [key] = useState(newIdempotencyKey);
  const adjust = useAdjustStock();
  const unit = product.unit;
  const pattern = unit === "kg" ? /^-?\d{1,7}(\.\d{1,3})?$/ : /^-?\d{1,7}$/;
  const valid = pattern.test(value.trim()) && !(mode === "count" && value.trim().startsWith("-"));
  const delta = valid ? (mode === "count" ? milli(value) - milli(product.current_stock) : milli(value)) : null;
  const after = delta === null ? null : milli(product.current_stock) + delta;

  const submit = (e) => {
    e.preventDefault();
    if (!delta) return;
    adjust.mutate({ product_id: product.id, quantity: fromMilli(delta, unit).replace("−", "-").replace("+", ""), reason, key }, { onSuccess: onClose });
  };

  return (
    <Dialog title={`تعديل مخزون: ${product.name}`} onClose={onClose}>
      <form className="form-stack" onSubmit={submit} noValidate>
        <Segments
          label="نوع التعديل"
          value={mode}
          options={[
            ["count", "العدد الفعلي على الرف"],
            ["delta", "إضافة أو خصم كمية"],
          ]}
          onChange={(m) => {
            setMode(m);
            setValue("");
          }}
        />
        <Field
          id="adj-qty"
          label={mode === "count" ? `العدد الفعلي${unit === "kg" ? " (كغ)" : ""}` : "الكمية (سالبة للخصم)"}
          error={value && !valid ? (unit === "kg" ? "حتى 3 خانات عشرية." : "عدد صحيح للمنتج بالقطعة.") : adjust.error?.fieldError?.("quantity")}
        >
          <input id="adj-qty" className="fld ltr m" inputMode="decimal" value={value} onChange={(e) => setValue(e.target.value)} style={{ fontSize: 20, fontWeight: 600 }} />
        </Field>
        <Field id="adj-reason" label="السبب" error={adjust.error?.fieldError?.("reason")}>
          <select id="adj-reason" className="fld" value={reason} onChange={(e) => setReason(e.target.value)}>
            {REASONS.map((r) => (
              <option key={r}>{r}</option>
            ))}
          </select>
        </Field>
        <ConfirmSummary
          rows={[
            ["المسجّل الآن", product.current_stock],
            [mode === "count" ? "العدد الفعلي" : "التعديل", valid ? value : "—"],
          ]}
          total={["الفرق الذي سيُسجَّل", delta === null ? "—" : fromMilli(delta, unit), delta < 0 ? "var(--debt-fg)" : "var(--success-fg)"]}
        />
        {after !== null && after < 0 ? <p className="field-error">المخزون لا يصبح سالباً بالتعديل.</p> : null}
        <ErrorBanner error={adjust.error && !Object.keys(adjust.error.errors ?? {}).length ? adjust.error : null} />
        <div className="dlg-actions">
          <button type="submit" className="btn btn-p" disabled={!delta || adjust.isPending || after < 0}>
            {adjust.isPending ? "جارٍ الحفظ…" : "حفظ التعديل"}
          </button>
          <button type="button" className="btn btn-g" onClick={onClose}>
            إلغاء
          </button>
        </div>
      </form>
    </Dialog>
  );
}
