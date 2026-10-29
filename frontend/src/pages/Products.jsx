import { useDeferredValue, useState } from "react";
import { Link } from "react-router-dom";
import Icon from "../components/Icon";
import { DataTable, Dialog, EmptyState, ErrorBanner, ErrorState, MoneyText, PageHeader, Pager, Segments, StatusBadge } from "../components/ui";
import { canManage, cartonsLabel, stockState } from "../lib/domain";
import { session } from "../services/apiClient";
import { useImportProducts, useNegativeStock, useProducts } from "../services/backoffice";

/** SCR-W-08 · products: search by name or barcode, low / negative stock filters (US-0405). */
export default function Products() {
  const manager = canManage(session.user());
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState("all");
  const [pageNo, setPageNo] = useState(1);
  const [importing, setImporting] = useState(false);
  const query = useDeferredValue(search.trim());

  const list = useProducts({
    search: query,
    page: pageNo,
    status: filter === "inactive" ? "inactive" : "active",
    stock: filter === "low" || filter === "negative" ? filter : undefined,
  });
  const negative = useNegativeStock();
  const negativeCount = negative.data?.length ?? 0;
  const rows = list.data?.data ?? [];

  // The table the shopkeeper asked for: name, cartons (with an opened one), all pieces, piece price.
  // The pieces take the stock colour: low, out, below zero.
  const columns = [
    {
      key: "name",
      label: "المنتج",
      render: (p) => (
        <Link className="row-link" to={`/products/${p.id}`}>
          {p.name}
        </Link>
      ),
    },
    { key: "cartons", label: "عدد الكراتين", numeric: true, render: (p) => <span className="cartons-cell">{cartonsLabel(p)}</span> },
    {
      key: "pieces",
      label: "عدد القطع الكلي",
      numeric: true,
      render: (p) => {
        const state = p.status === "inactive" ? "inactive" : stockState(p);
        return (
          <span className={`m stock-${state}`}>
            {p.current_stock}
            {p.unit === "kg" ? " كغ" : ""}
          </span>
        );
      },
    },
    { key: "price", label: "سعر القطعة", numeric: true, render: (p) => <MoneyText value={p.selling_price} style={{ fontWeight: 600 }} /> },
  ];

  const empty =
    query || filter !== "all" ? (
      <EmptyState icon="search" title={query ? `لا صنف يطابق «${query}»` : "لا أصناف في هذه القائمة"} />
    ) : (
      <EmptyState icon="products" title="ما في بضاعة لسّا" text="أسرع طريقة: استورد قائمتك من ملف CSV دفعة واحدة. أو أضف البضاعة واحداً واحداً، أو امسحها من الجوال.">
        {manager ? (
          <div className="chips">
            <button type="button" className="btn btn-p btn-sm" onClick={() => setImporting(true)}>
              استيراد من ملف CSV
            </button>
            <Link className="btn btn-s btn-sm" to="/products/new">
              إضافة صنف
            </Link>
          </div>
        ) : null}
      </EmptyState>
    );

  return (
    <>
      <PageHeader title="البضاعة" sub={list.data?.meta ? `${list.data.meta.total} صنفاً في هذه القائمة` : " "}>
        {manager ? (
          <>
            <button type="button" className="btn btn-s btn-sm" onClick={() => setImporting(true)}>
              استيراد من ملف CSV
            </button>
            <Link className="btn btn-p btn-sm" to="/products/new">
              <Icon name="plus" size={16} strokeWidth={2.2} />
              صنف جديد
            </Link>
          </>
        ) : null}
      </PageHeader>

      {negativeCount > 0 ? (
        <div role="status" className="banner" style={{ background: "var(--warning-bg)", color: "var(--warning-fg)" }}>
          <Icon name="low" size={20} />
          <span style={{ flex: 1, color: "var(--ink)" }}>
            {negativeCount === 1 ? "صنف بيع" : `${negativeCount} أصناف بيعت`} بأكثر من المخزون المسجّل. راجع العدّ على الرف وصحّح المخزون.
          </span>
          <Link className="btn btn-s btn-sm" to="/products/negative-stock">
            مراجعة المخزون السالب
          </Link>
        </div>
      ) : null}

      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث بالاسم أو الباركود</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="بحث بالاسم أو الباركود"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
        <Segments
          label="تصفية المخزون"
          value={filter}
          options={[
            ["all", "الكل"],
            ["low", "منخفض"],
            ["negative", "سالب", negativeCount || undefined],
            ["inactive", "موقوفة"],
          ]}
          onChange={(v) => {
            setFilter(v);
            setPageNo(1);
          }}
        />
      </div>

      <DataTable query={list} rows={rows} columns={columns} caption="قائمة البضاعة" empty={empty} minWidth={680} />
      <Pager meta={list.data?.meta} onPage={setPageNo} />

      {importing ? <ImportDialog onClose={() => setImporting(false)} /> : null}
    </>
  );
}

const TEMPLATE =
  "name,barcode,unit,selling_price,cost_price,pack_size,pack_price,current_stock,minimum_stock\nشاي أسود 100 كيس,6294003500071,piece,14.00,10.50,,,20,4\nماء 600 مل,6291007030017,piece,2.50,1.80,24,54.00,48,24\nلوز نيء,,kg,60.00,44.00,,,2.500,1\n";

/** US-0408 · check the whole file first; import only when every row is valid (all or nothing). */
function ImportDialog({ onClose }) {
  const [file, setFile] = useState(null);
  const [checked, setChecked] = useState(null);
  const [done, setDone] = useState(null);
  const run = useImportProducts();
  const rowErrors = run.error?.code === "IMPORT_INVALID" ? run.error.details?.errors ?? [] : [];
  const templateHref = `data:text/csv;charset=utf-8,${encodeURIComponent(`﻿${TEMPLATE}`)}`;

  const pick = (f) => {
    setFile(f);
    setChecked(null);
    run.reset();
    if (f) run.mutate({ file: f, dryRun: true }, { onSuccess: setChecked });
  };

  return (
    <Dialog title="استيراد البضاعة من ملف CSV" onClose={onClose} wide>
      {done ? (
        <div className="state-card">
          <Icon name="ok" size={44} color="var(--success-fg)" strokeWidth={1.8} />
          <b className="state-title">استُورد {done.imported} صنفاً</b>
          <span className="state-text">سُجّلت كميات البداية كحركة «رصيد افتتاحي» لكل صنف.</span>
          <button type="button" className="btn btn-p btn-sm" onClick={onClose}>
            عرض البضاعة
          </button>
        </div>
      ) : (
        <>
          <label className="dropzone">
            <Icon name="upload" size={32} color="var(--primary)" strokeWidth={1.8} />
            <b>{file ? file.name : "اختر ملف CSV"}</b>
            <span className="field-hint">حتى 2000 صف · ترميز UTF-8 · الصف الأول أسماء الأعمدة</span>
            <input type="file" accept=".csv,text/csv" className="sr-only" onChange={(e) => pick(e.target.files?.[0] ?? null)} />
          </label>
          <p className="field-hint" style={{ lineHeight: 1.8 }}>
            الأعمدة: <span className="m">name, barcode, unit, selling_price, cost_price, pack_size, pack_price, current_stock, minimum_stock</span>. الوحدة{" "}
            <span className="m">piece</span> أو <span className="m">kg</span>؛ الاسم وسعر البيع والمخزون إلزامية. للكرتونة (اختياري، بالقطعة فقط): عدد قطعها{" "}
            <span className="m">pack_size</span> وسعرها كاملة <span className="m">pack_price</span>؛ المخزون يبقى بالقطعة.{" "}
            <a href={templateHref} download="hisbah-products.csv">
              تنزيل نموذج
            </a>
          </p>

          {run.isPending ? <p role="status">جارٍ فحص الملف…</p> : null}

          {run.error ? (
            <>
              <ErrorBanner error={run.error} />
              {rowErrors.length ? (
                <div className="scroll-box">
                  <table className="plain-table">
                    <thead>
                      <tr>
                        <th scope="col">الصف</th>
                        <th scope="col">العمود</th>
                        <th scope="col">المشكلة</th>
                      </tr>
                    </thead>
                    <tbody>
                      {rowErrors.map((e) => (
                        <tr key={`${e.row}-${e.column}`}>
                          <td className="m">{e.row}</td>
                          <td className="m">{e.column}</td>
                          <td>{e.message}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              ) : null}
            </>
          ) : null}

          {checked ? (
            <div role="status" className="banner tone-success">
              <Icon name="ok" size={20} />
              <span>
                الملف سليم: {checked.rows} صفاً جاهزاً ({checked.pieces} بالقطعة و{checked.kg} بالوزن).
              </span>
            </div>
          ) : null}

          <div className="dlg-actions">
            <button
              type="button"
              className="btn btn-p"
              disabled={!checked || run.isPending}
              onClick={() => run.mutate({ file, dryRun: false }, { onSuccess: setDone })}
            >
              {checked ? `استيراد ${checked.rows} صنفاً` : "استيراد"}
            </button>
            <button type="button" className="btn btn-g" onClick={onClose}>
              إلغاء
            </button>
          </div>
        </>
      )}
    </Dialog>
  );
}

/** D-27 · negative-stock review: count the shelf, then enter the real count. */
export function NegativeStock() {
  const negative = useNegativeStock();
  const items = negative.data ?? [];
  return (
    <>
      <PageHeader title="مراجعة المخزون السالب" sub="البيع لا يتوقف عندما ينفد المخزون المسجّل؛ يُسجَّل هنا لتراجعه. عُدّ الكمية على الرف، ثم أدخل العدد الفعلي." />
      {negative.isPending ? <div className="card sk" style={{ height: 160 }} /> : null}
      {negative.isSuccess && items.length === 0 ? <EmptyState icon="ok" title="لا أصناف بمخزون سالب" text="كل المخزون المسجّل صفر أو أكثر." /> : null}
      {negative.isError ? <ErrorState error={negative.error} onRetry={() => negative.refetch()} /> : null}
      {items.map(({ product, sales }) => (
        <section key={product.id} className="card panel">
          <div className="page-head">
            <div>
              <h2 style={{ fontSize: 17 }}>{product.name}</h2>
              <span className="cell-sub m">{product.barcode ?? "بلا باركود"}</span>
            </div>
            <div className="head-actions">
              <span className="field-hint">المسجّل الآن</span>
              <StatusBadge status="negative">
                <span className="m"> {product.current_stock}</span>
              </StatusBadge>
              <Link className="btn btn-p btn-sm" to={`/products/${product.id}?adjust=1`}>
                إدخال العدد الفعلي
              </Link>
            </div>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th scope="col">الفاتورة التي سبّبت النقص</th>
                  <th scope="col">البائع</th>
                  <th scope="col" className="n">
                    الكمية المبيعة
                  </th>
                  <th scope="col" className="n">
                    المخزون بعدها
                  </th>
                </tr>
              </thead>
              <tbody>
                {sales.map((s) => (
                  <tr key={`${s.invoice_id}-${s.created_at}`}>
                    <td>
                      <Link to={`/sales/${s.invoice_id}`} className="m">
                        #{s.invoice_id}
                      </Link>
                    </td>
                    <td>{s.created_by ?? "—"}</td>
                    <td className="n m">{s.quantity}</td>
                    <td className="n m">{s.balance_after}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      ))}
    </>
  );
}
