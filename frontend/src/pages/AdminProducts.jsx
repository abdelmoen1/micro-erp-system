import { useDeferredValue, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { AccessBadge } from "../components/platform";
import { Crumbs, DataTable, EmptyState, ErrorState, MoneyText, PageHeader, Pager, QtyText, StatusBadge } from "../components/ui";
import { dateOnly } from "../lib/format";
import { stockState } from "../lib/domain";
import { useAdminProducts, useCatalogItem } from "../services/admin";

// Each row is one store's own product: its name, price, cost and stock. Rows are never added
// together across stores; a shared barcode only links them (the catalog page lists them side by side).

const storeCell = (p) => (
  <>
    <Link className="row-link" to={`/admin/stores/${p.store.id}`}>
      {p.store.name}
    </Link>
    <span className="cell-sub">{p.store.address || "لا عنوان"}</span>
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

/** Platform owner · one shared barcode and every store that carries it, side by side. */
export function AdminCatalogItem() {
  const { id } = useParams();
  const item = useCatalogItem(id);

  if (item.isError) return <ErrorState error={item.error} onRetry={() => item.refetch()} />;
  const c = item.data;

  return (
    <>
      <Crumbs items={[["المنتجات في المتاجر", "/admin/products"], [c?.name ?? "…"]]} />
      <PageHeader
        title={c?.name ?? " "}
        sub={c ? `الباركود ${c.barcode}، في ${c.stores_count} ${c.stores_count === 1 ? "متجر" : "متاجر"}، أول تسجيل ${dateOnly(c.created_at)}` : " "}
      />
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
          ...numbers,
        ]}
      />
      <p className="data-note">الاسم الموحّد للباركود من أول متجر سجّله؛ كل متجر يحتفظ باسمه وسعره ومخزونه.</p>
    </>
  );
}
