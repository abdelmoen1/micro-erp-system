import { useDeferredValue, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { AccessBadge } from "../components/platform";
import { Crumbs, DataTable, EmptyState, ErrorState, MoneyText, PageHeader, Pager, QtyText, StatusBadge } from "../components/ui";
import { dateOnly } from "../lib/format";
import { stockState } from "../lib/domain";
import { useAdminCatalog, useAdminProducts, useCatalogItem } from "../services/admin";

// Each row is one store's own product: its name, price, cost and stock. Rows are never added
// together across stores; a shared barcode only links them (the catalog page lists them side by side).

const storeCell = (p) => (
  <>
    <Link className="row-link" to={`/admin/stores/${p.store.id}`}>
      {p.store.name}
    </Link>
    <span className="cell-sub">{p.store.address || p.store.area || "لا عنوان"}</span>
  </>
);

const numbers = [
  { key: "price", label: "سعر البيع", numeric: true, render: (p) => <MoneyText value={p.selling_price} /> },
  { key: "cost", label: "سعر الشراء", numeric: true, render: (p) => (p.cost_price ? <MoneyText value={p.cost_price} /> : <span className="cell-sub">—</span>) },
  { key: "stock", label: "المخزون", numeric: true, render: (p) => <QtyText value={p.current_stock} unit={p.unit} /> },
  { key: "status", label: "الحالة", render: (p) => (p.status === "inactive" ? <StatusBadge status="inactive" label="معطّل" /> : <StatusBadge status={stockState(p)} />) },
];

/** Platform owner · product rows across stores, searchable by product and by store. */
export default function AdminProducts() {
  const [search, setSearch] = useState("");
  const [store, setStore] = useState("");
  const [pageNo, setPageNo] = useState(1);
  const productQuery = useDeferredValue(search.trim());
  const storeQuery = useDeferredValue(store.trim());
  const list = useAdminProducts({ search: productQuery, store: storeQuery, page: pageNo, per_page: 25 });

  const columns = [
    {
      key: "name",
      label: "المنتج",
      render: (p) => (
        <>
          <b style={{ fontWeight: 600 }}>{p.name}</b>
          <span className="cell-sub">
            {p.barcode ? <span className="m">{p.barcode}</span> : "بلا باركود"}
            {p.catalog_product ? (
              <>
                {" "}
                <Link to={`/admin/catalog/${p.catalog_product.id}`}>كل المتاجر</Link>
              </>
            ) : null}
          </span>
        </>
      ),
    },
    { key: "store", label: "المتجر والموقع", render: storeCell },
    ...numbers,
  ];

  return (
    <>
      <PageHeader title="المنتجات في المتاجر" sub={list.data?.meta ? `${list.data.meta.total} منتجاً في كل المتاجر` : " "} />
      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث بالمنتج</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="اسم المنتج أو الباركود"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
        <label className="search grow">
          <span className="sr-only">بحث بالمتجر</span>
          <Icon name="shop" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="اسم المتجر أو عنوانه"
            value={store}
            onChange={(e) => {
              setStore(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
      </div>
      <DataTable
        query={list}
        rows={list.data?.data ?? []}
        columns={columns}
        caption="المنتجات في كل المتاجر"
        minWidth={900}
        empty={
          productQuery || storeQuery ? (
            <EmptyState icon="search" title="لا منتجات تطابق هذا البحث" text="جرّب جزءاً من الاسم، أو الباركود كاملاً." />
          ) : (
            <EmptyState icon="products" title="لم تُضف المتاجر أي منتج بعد" />
          )
        }
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      <p className="data-note">كل صف منتج متجر واحد بسعره وتكلفته ومخزونه. لا تُجمع الأسعار ولا الكميات بين المتاجر.</p>
    </>
  );
}

const storesLabel = (n) => (n === 1 ? "متجر واحد" : n === 2 ? "متجران" : `${n} متاجر`);

/** "7.25 – 9.50", or one price when every store charges the same. */
function PriceRange({ min, max }) {
  if (min == null) return <span className="cell-sub">لا يُباع الآن</span>;
  if (min === max) return <MoneyText value={min} />;
  return (
    <span className="price-range">
      <MoneyText value={min} /> – <MoneyText value={max} />
    </span>
  );
}

/** Platform owner · the shared catalog: each barcode once, how many stores carry it and at what prices. */
export function AdminCatalog() {
  const [search, setSearch] = useState("");
  const [pageNo, setPageNo] = useState(1);
  const query = useDeferredValue(search.trim());
  const list = useAdminCatalog({ search: query, page: pageNo, per_page: 25 });

  return (
    <>
      <PageHeader title="الكتالوج المشترك" sub={list.data?.meta ? `${list.data.meta.total} باركوداً مسجّلاً، الأكثر انتشاراً أولاً` : " "} />
      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث في الكتالوج</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="اسم المنتج أو الباركود"
            value={search}
            onChange={(e) => {
              setSearch(e.target.value);
              setPageNo(1);
            }}
          />
        </label>
      </div>
      <DataTable
        query={list}
        rows={list.data?.data ?? []}
        caption="الكتالوج المشترك"
        minWidth={720}
        empty={
          query ? (
            <EmptyState icon="search" title={`لا باركود يطابق «${query}»`} text="جرّب جزءاً من الاسم، أو الباركود كاملاً." />
          ) : (
            <EmptyState icon="barcode" title="لم يُسجَّل أي باركود عالمي بعد" text="يظهر هنا كل باركود يضيفه متجر لأول مرة." />
          )
        }
        columns={[
          {
            key: "name",
            label: "المنتج",
            render: (c) => (
              <>
                <Link className="row-link" to={`/admin/catalog/${c.id}`}>
                  {c.name}
                </Link>
                <span className="cell-sub m">{c.barcode}</span>
              </>
            ),
          },
          {
            key: "stores",
            label: "المتاجر",
            numeric: true,
            render: (c) => (
              <>
                <span className="m">{c.stores_count}</span>
                {c.active_stores_count !== c.stores_count ? (
                  <span className="cell-sub">{c.active_stores_count === 0 ? "لا يبيعه أحد الآن" : `${c.active_stores_count} تبيعه الآن`}</span>
                ) : null}
              </>
            ),
          },
          { key: "price", label: "سعر البيع في المتاجر", numeric: true, render: (c) => <PriceRange min={c.price_min} max={c.price_max} /> },
        ]}
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      <p className="data-note">نطاق السعر من المتاجر التي تبيع المنتج الآن فقط. لكل متجر سعره ومخزونه؛ افتح المنتج لترى المتاجر جنباً إلى جنب.</p>
    </>
  );
}

/** Platform owner · one shared barcode and every store that carries it, side by side, cheapest first. */
export function AdminCatalogItem() {
  const { id } = useParams();
  const item = useCatalogItem(id);

  if (item.isError) return <ErrorState error={item.error} onRetry={() => item.refetch()} />;
  const c = item.data;
  const cmp = c?.comparison;
  const spread = cmp && cmp.price_min !== cmp.price_max;

  // The comparison marks the extremes in the price column itself, where the eye already is.
  const priceCell = (p) => (
    <span className="price-cell">
      <MoneyText value={p.selling_price} />
      {spread && p.status === "active" && p.selling_price === cmp.price_min ? <span className="price-tag is-low">الأقل</span> : null}
      {spread && p.status === "active" && p.selling_price === cmp.price_max ? <span className="price-tag is-high">الأعلى</span> : null}
    </span>
  );

  return (
    <>
      <Crumbs items={[["الكتالوج المشترك", "/admin/catalog"], [c?.name ?? "…"]]} />
      <PageHeader
        title={c?.name ?? " "}
        sub={c ? `الباركود ${c.barcode}، في ${storesLabel(c.stores_count)}، أول تسجيل ${dateOnly(c.created_at)}` : " "}
      />
      {cmp && cmp.active_stores_count > 1 ? (
        <p className="price-compare" role="note">
          {spread ? (
            <>
              يتراوح السعر بين <MoneyText value={cmp.price_min} /> و <MoneyText value={cmp.price_max} /> في {storesLabel(cmp.active_stores_count)} تبيعه الآن، بفارق{" "}
              <b>
                <MoneyText value={cmp.price_spread} />
              </b>
              .
            </>
          ) : (
            <>
              السعر نفسه <MoneyText value={cmp.price_min} /> في {storesLabel(cmp.active_stores_count)} تبيعه الآن.
            </>
          )}
        </p>
      ) : null}
      <DataTable
        query={item}
        rows={c?.offers ?? []}
        caption={`المتاجر التي تبيع ${c?.name ?? ""}`}
        minWidth={900}
        empty={<EmptyState icon="shop" title="لا متجر يبيع هذا المنتج الآن" />}
        columns={[
          { key: "store", label: "المتجر والموقع", render: storeCell },
          { key: "access", label: "الحساب", render: (p) => <AccessBadge status={p.store.status} /> },
          { key: "name", label: "الاسم في المتجر", render: (p) => p.name },
          { ...numbers[0], render: priceCell },
          ...numbers.slice(1),
        ]}
      />
      <p className="data-note">الاسم الموحّد للباركود من أول متجر سجّله؛ كل متجر يحتفظ باسمه وسعره ومخزونه، ولا تُجمع الكميات بين المتاجر.</p>
    </>
  );
}
