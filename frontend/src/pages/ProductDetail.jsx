import { useEffect, useRef, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import Icon from "../components/Icon";
import { ConfirmSummary, Crumbs, DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, Field, Segments, StatusBadge } from "../components/ui";
import { newIdempotencyKey, session } from "../services/apiClient";
import { lookupCatalog, useAdjustStock, useMovements, useProduct, useProductStatus, useSaveProduct } from "../services/backoffice";
import { canManage, stockState, cartonPieces, cartonsLabel } from "../lib/domain";
import { dateTime, latinDigits } from "../lib/format";

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
  const status = useProductStatus();
  const [confirmStop, setConfirmStop] = useState(false);

  if (!isNew && product.isError) return <ErrorState error={product.error} title="تعذّر فتح الصنف" onRetry={() => product.refetch()} />;
  if (!isNew && product.isPending) return <div className="card sk" style={{ height: 320 }} />;

  const p = product.data;
  const adjusting = params.get("adjust") === "1" && p;

  return (
    <>
      <Crumbs items={[["البضاعة", "/products"], [isNew ? "صنف جديد" : p.name]]} />
      <div className="split">
        <ProductForm key={p?.id ?? "new"} product={p} manager={manager} onSaved={(saved) => (isNew ? navigate(`/products/${saved.id}`, { replace: true }) : null)} />

        {!isNew ? (
          <section className="card panel" style={{ flex: "1 1 480px" }}>
            <div className="page-head">
              <h2 style={{ fontSize: 17 }}>حركات البضاعة</h2>
              {manager ? (
                <button type="button" className="btn btn-s btn-sm" onClick={() => setParams({ adjust: "1" })}>
                  تعديل الكمية
                </button>
              ) : null}
            </div>
            <div style={{ display: "flex", gap: 10, alignItems: "baseline", flexWrap: "wrap" }}>
              <span className="field-hint">الكمية الموجودة الآن</span>
              <b className="m" style={{ fontSize: 26 }}>
                {p.current_stock}
              </b>
              <span>{p.unit === "kg" ? "كغ" : "قطعة"}</span>
              {p.status === "inactive" ? <StatusBadge status="inactive" label="موقوف" /> : <StatusBadge status={stockState(p)} />}
            </div>
            {p.status === "inactive" ? (
              <div role="status" className="banner tone-pending">
                <Icon name="ban" size={20} />
                <span>
                  هذا الصنف موقوف: لا يظهر في البيع ولا في قائمة البضاعة.
                  {manager ? <span className="sub">أعِده ليرجع كما كان بسعره ومخزونه.</span> : null}
                </span>
              </div>
            ) : null}
            <ErrorBanner error={status.error} />
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
            {manager && p.status === "inactive" ? (
              <button type="button" className="btn btn-p btn-sm" disabled={status.isPending} onClick={() => status.mutate({ id: p.id, active: true })} style={{ alignSelf: "flex-start" }}>
                {status.isPending ? "جارٍ الإعادة…" : "إعادة تفعيل الصنف"}
              </button>
            ) : manager ? (
              <button type="button" className="btn btn-t danger" onClick={() => setConfirmStop(true)} style={{ alignSelf: "flex-start" }}>
                إيقاف الصنف
              </button>
            ) : null}
          </section>
        ) : null}
      </div>
      {adjusting ? <AdjustDialog product={p} onClose={() => setParams({})} /> : null}
      {confirmStop ? (
        <Dialog title={`إيقاف «${p.name}»؟`} role="alertdialog" tone="warning" icon="ban" onClose={() => setConfirmStop(false)}>
          <p>لن يظهر في البيع ولا في قائمة البضاعة. حركاته وفواتيره السابقة تبقى في السجل.</p>
          <p className="field-hint">تستطيع إعادته متى شئت من «البضاعة ← موقوفة»، فيرجع كما كان.</p>
          <div className="dlg-actions">
            <button
              type="button"
              className="btn btn-dd"
              disabled={status.isPending}
              onClick={() => status.mutate({ id: p.id, active: false }, { onSuccess: () => setConfirmStop(false) })}
            >
              {status.isPending ? "جارٍ الإيقاف…" : "إيقاف الصنف"}
            </button>
            <button type="button" className="btn btn-g" onClick={() => setConfirmStop(false)}>
              رجوع
            </button>
          </div>
        </Dialog>
      ) : null}
    </>
  );
}

function ProductForm({ product, manager, onSaved }) {
  const [form, setForm] = useState(() => ({
    name: product?.name ?? "",
    barcode: product?.barcode ?? "",
    // By the carton unless the product is weighed or already has no carton.
    mode: product ? (product.unit === "kg" ? "kg" : product.pack_size ? "carton" : "piece") : "carton",
    selling_price: product?.selling_price ?? "",
    cost_price: product?.cost_price ?? "",
    current_stock: product ? product.current_stock : "0",
    minimum_stock: product?.minimum_stock ?? "",
    pack_size: product?.pack_size ? String(product.pack_size) : "",
    pack_price: product?.pack_price ?? "",
    cartons: "",
    loose: "",
  }));
  const [match, setMatch] = useState(null);
  const [tried, setTried] = useState(false);
  const save = useSaveProduct();
  const unit = form.mode === "kg" ? "kg" : "piece";
  const byCarton = form.mode === "carton";
  // New products only: the stock is counted in cartons; afterwards it moves by sales and adjustments.
  const countCartons = byCarton && !product;
  const total = cartonPieces(form.pack_size, form.cartons, form.loose);

  // New products only: a barcode another store saved fills the shared name and unit; one already
  // in this store points to it instead (its stock changes by adjustment, not a second product).
  const checkCatalog = async () => {
    const code = form.barcode.trim();
    if (product || !code) return setMatch(null);
    try {
      const found = await lookupCatalog(code);
      setMatch(found);
      if (!found.product && found.catalog_product) {
        const weighed = found.catalog_product.unit === "kg";
        setForm((f) => ({ ...f, name: found.catalog_product.name, mode: weighed ? "kg" : f.mode === "kg" ? "carton" : f.mode }));
      }
    } catch {
      setMatch(null); // The server checks the barcode again on save.
    }
  };

  // The carton count is checked here (the server only sees the worked-out pieces).
  const size = /^\d{1,6}$/.test(String(form.pack_size).trim()) ? Number(form.pack_size) : null;
  const localErrors = countCartons
    ? {
        cartons: /^\d{1,6}$/.test(form.cartons.trim()) ? null : "أدخل عدد الكراتين: عدد صحيح، 0 أو أكثر.",
        loose:
          form.loose.trim() && !/^\d{1,6}$/.test(form.loose.trim())
            ? "أدخل عدداً صحيحاً."
            : size && Number(form.loose || 0) >= size
              ? `القطع الزيادة أقل من ${size}؛ وإلا فهي كرتونة كاملة.`
              : null,
      }
    : {};
  const err = (field) => (tried ? localErrors[field] : null) ?? save.error?.fieldError?.(field === "cartons" ? "current_stock" : field);
  const set = (field) => (e) => setForm({ ...form, [field]: e.target.value });
  // Numbers typed on an Arabic keyboard (٢٫٥) are kept as 2.5.
  const setNumber = (field) => (e) => setForm({ ...form, [field]: latinDigits(e.target.value) });
  const readOnly = !manager;
  const formRef = useRef(null);
  const priceUnit = unit === "kg" ? "كيلو واحد" : "قطعة واحدة";

  // A refused save moves to the first field marked, so the message is never off-screen.
  useEffect(() => {
    if ((save.error && Object.keys(save.error.errors ?? {}).length) || tried) formRef.current?.querySelector('[aria-invalid="true"]')?.focus();
  }, [save.error, tried]);

  const submit = (e) => {
    e.preventDefault();
    setTried(true);
    if (Object.values(localErrors).some(Boolean)) return;
    const body = {
      name: form.name.trim(),
      barcode: form.barcode.trim() || null,
      unit,
      selling_price: String(form.selling_price).trim(),
      cost_price: String(form.cost_price).trim() || null,
      ...(String(form.minimum_stock).trim() ? { minimum_stock: String(form.minimum_stock).trim() } : {}),
      // A carton is sent whole or cleared whole (both null), so it can never be half-set.
      ...(byCarton
        ? { pack_size: String(form.pack_size).trim(), pack_price: String(form.pack_price).trim() }
        : product?.pack_size
          ? { pack_size: null, pack_price: null }
          : {}),
      ...(product ? {} : { current_stock: countCartons ? String(total ?? "") : String(form.current_stock).trim() || "0" }),
    };
    save.mutate(product ? { id: product.id, ...body } : body, { onSuccess: onSaved });
  };

  return (
    <form ref={formRef} className="card panel form-stack" style={{ flex: "1 1 420px" }} onSubmit={submit} noValidate>
      <h1 style={{ fontSize: 22 }}>{product ? product.name : "صنف جديد"}</h1>
      <Field id="pf-name" label="اسم الصنف" required={!readOnly} error={err("name")}>
        <input id="pf-name" className="fld" value={form.name} onChange={set("name")} readOnly={readOnly} />
      </Field>
      <Field id="pf-barcode" label="الباركود" optional error={err("barcode")}>
        <input id="pf-barcode" className="fld ltr m" value={form.barcode} onChange={setNumber("barcode")} onBlur={checkCatalog} readOnly={readOnly} />
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
            صنف معروف في حسبة، فملأنا اسمه ووحدته.
            <span className="sub">أدخل سعر البيع والتكلفة والكمية لمتجرك. تعديل الاسم يخص متجرك وحده.</span>
          </span>
        </p>
      ) : null}
      <div className="field">
        <span className="field-label">يُباع</span>
        <Segments
          label="الوحدة"
          value={form.mode}
          options={[
            ["carton", "بالكرتونة"],
            ["piece", "بالقطعة"],
            ["kg", "بالوزن (كغ)"],
          ]}
          onChange={(mode) => !readOnly && setForm({ ...form, mode })}
        />
        {err("unit") ? (
          <span className="field-error">{err("unit")}</span>
        ) : (
          <span className="field-hint">
            {form.mode === "kg"
              ? "الأسعار لكل كيلو، والكمية حتى 3 خانات عشرية."
              : byCarton
                ? "تعدّ الكراتين، ونحسب نحن عدد القطع. البيع بالقطعة أو بالكرتونة."
                : "الأسعار والكمية بالقطعة."}
          </span>
        )}
      </div>
      <div className="grid2">
        <Field id="pf-price" label={byCarton ? "سعر القطعة الواحدة" : "السعر للزبون (سعر البيع)"} required={!readOnly} error={err("selling_price")} hint={`ما يدفعه الزبون مقابل ${priceUnit}.`}>
          <input id="pf-price" className="fld ltr m" inputMode="decimal" value={form.selling_price} onChange={setNumber("selling_price")} readOnly={readOnly} />
        </Field>
        <Field id="pf-cost" label="تكلفة الصنف عليك (سعر الشراء)" optional error={err("cost_price")} hint="ما تدفعه أنت للمورّد. لا يظهر للزبون.">
          <input id="pf-cost" className="fld ltr m" inputMode="decimal" value={form.cost_price ?? ""} onChange={setNumber("cost_price")} readOnly={readOnly} />
        </Field>
      </div>
      {byCarton ? <CartonFields form={form} setNumber={setNumber} err={err} readOnly={readOnly} countCartons={countCartons} total={total} /> : null}
      <div className="grid2">
        {countCartons ? null : (
          <Field
            id="pf-stock"
            label={product ? "الكمية الموجودة" : "الكمية الموجودة الآن"}
            required={!product && !readOnly}
            error={err("current_stock")}
            hint={product ? (byCarton ? `${cartonsLabel({ ...product, pack_size: size ?? product.pack_size })}. يتغير بالبيع أو بتعديل الكمية مع سبب.` : "يتغير بالبيع أو بتعديل الكمية مع سبب.") : null}
          >
            <input id="pf-stock" className="fld ltr m" inputMode={unit === "kg" ? "decimal" : "numeric"} value={form.current_stock} onChange={setNumber("current_stock")} readOnly={Boolean(product) || readOnly} />
          </Field>
        )}
        <Field id="pf-min" label="نبّهني لمّا توصل الكمية إلى" optional error={err("minimum_stock")} hint="بالقطعة. يظهر الصنف في «مخزون منخفض» عند هذا الرقم أو أقل.">
          <input id="pf-min" className="fld ltr m" inputMode={unit === "kg" ? "decimal" : "numeric"} value={form.minimum_stock} onChange={setNumber("minimum_stock")} readOnly={readOnly} />
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
            {save.isPending ? "جارٍ الحفظ…" : product ? "حفظ التعديلات" : "حفظ الصنف"}
          </button>
          <Link className="btn btn-g" to="/products">
            إلغاء
          </Link>
        </div>
      ) : (
        <p className="field-hint">تعديل البضاعة للمالك أو المدير.</p>
      )}
    </form>
  );
}

/** Shekels → agorot, or null when not a valid price. */
const toAgorot = (v) => (/^\d{1,8}(\.\d{1,2})?$/.test(String(v).trim()) ? Math.round(Number(v) * 100) : null);

/**
 * The carton: how many pieces in one and the wholesale price of a whole carton. A new product also
 * counts its cartons on hand and the extra pieces of an opened one; the total in pieces is shown
 * before saving. The price hint shows what one piece costs inside the carton, so a per-piece price
 * typed in the carton field is obvious before the server refuses it.
 */
function CartonFields({ form, setNumber, err, readOnly, countCartons, total }) {
  const size = /^\d{1,6}$/.test(String(form.pack_size).trim()) ? Number(form.pack_size) : null;
  const packCents = toAgorot(form.pack_price);
  const pieceCents = toAgorot(form.selling_price);
  const perPiece = size && size > 1 && packCents ? packCents / size : null;
  const hint =
    perPiece === null
      ? "سعر الكرتونة كاملة، وليس سعر القطعة."
      : `القطعة داخل الكرتونة بـ ${(perPiece / 100).toFixed(2)} ₪${pieceCents ? ` مقابل ${(pieceCents / 100).toFixed(2)} ₪ بالمفرد` : ""}.`;
  return (
    <>
      <div className="grid2">
        {countCartons ? (
          <Field id="pf-cartons" label="عدد الكراتين عندك" required={!readOnly} error={err("cartons")}>
            <input id="pf-cartons" className="fld ltr m" inputMode="numeric" value={form.cartons} onChange={setNumber("cartons")} readOnly={readOnly} />
          </Field>
        ) : null}
        <Field id="pf-pack-size" label="عدد القطع في الكرتونة" required={!readOnly} error={err("pack_size")}>
          <input id="pf-pack-size" className="fld ltr m" inputMode="numeric" value={form.pack_size} onChange={setNumber("pack_size")} readOnly={readOnly} />
        </Field>
        {countCartons ? (
          <Field id="pf-loose" label="قطع زيادة" optional error={err("loose")} hint="من كرتونة مفتوحة.">
            <input id="pf-loose" className="fld ltr m" inputMode="numeric" value={form.loose} onChange={setNumber("loose")} readOnly={readOnly} />
          </Field>
        ) : null}
        <Field id="pf-pack-price" label="سعر الكرتونة (جملة)" required={!readOnly} error={err("pack_price")} hint={err("pack_price") ? null : hint}>
          <input id="pf-pack-price" className="fld ltr m" inputMode="decimal" value={form.pack_price} onChange={setNumber("pack_price")} readOnly={readOnly} />
        </Field>
      </div>
      {countCartons && total !== null ? (
        <p role="status" className="carton-total">
          المجموع: <b className="m">{total}</b> قطعة
        </p>
      ) : null}
    </>
  );
}

function AdjustDialog({ product, onClose }) {
  const [mode, setMode] = useState("count");
  const [value, setValue] = useState("");
  const [reason, setReason] = useState(REASONS[0]);
  const [key] = useState(newIdempotencyKey);
  const adjust = useAdjustStock();
  const unit = product.unit;
  // «cartons»: goods received by the carton; the server adds cartons × pack size pieces.
  const cartons = mode === "cartons";
  const pattern = cartons ? /^\d{1,5}$/ : unit === "kg" ? /^-?\d{1,7}(\.\d{1,3})?$/ : /^-?\d{1,7}$/;
  const valid = pattern.test(value.trim()) && !(mode === "count" && value.trim().startsWith("-")) && !(cartons && Number(value) === 0);
  const delta = valid
    ? mode === "count"
      ? milli(value) - milli(product.current_stock)
      : cartons
        ? Number(value) * product.pack_size * 1000
        : milli(value)
    : null;
  const after = delta === null ? null : milli(product.current_stock) + delta;

  const submit = (e) => {
    e.preventDefault();
    if (!delta) return;
    const body = cartons
      ? { product_id: product.id, quantity: value.trim(), unit: "pack", reason, key }
      : { product_id: product.id, quantity: fromMilli(delta, unit).replace("−", "-").replace("+", ""), reason, key };
    adjust.mutate(body, { onSuccess: onClose });
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
            ...(product.pack_size ? [["cartons", `استلام كراتين (${product.pack_size} قطعة)`]] : []),
          ]}
          onChange={(m) => {
            setMode(m);
            setValue("");
          }}
        />
        <Field
          id="adj-qty"
          label={mode === "count" ? `العدد الفعلي${unit === "kg" ? " (كغ)" : ""}` : cartons ? "عدد الكراتين المستلمة" : "الكمية (سالبة للخصم)"}
          error={
            value && !valid
              ? cartons
                ? "عدد صحيح من الكراتين أكبر من صفر."
                : unit === "kg"
                  ? "حتى 3 خانات عشرية."
                  : "عدد صحيح للصنف بالقطعة."
              : adjust.error?.fieldError?.("quantity")
          }
        >
          <input id="adj-qty" className="fld ltr m" inputMode="decimal" value={value} onChange={(e) => setValue(latinDigits(e.target.value))} style={{ fontSize: 20, fontWeight: 600 }} />
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
            cartons
              ? ["الكراتين", valid ? `${value} × ${product.pack_size} قطعة` : "—"]
              : [mode === "count" ? "العدد الفعلي" : "التعديل", valid ? value : "—"],
          ]}
          total={["الفرق الذي سيُسجَّل", delta === null ? "—" : fromMilli(delta, unit), delta < 0 ? "var(--debt-fg)" : "var(--success-fg)"]}
        />
        {after !== null && after < 0 ? <p className="field-error">الكمية لا تصير سالبة بالتعديل.</p> : null}
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
