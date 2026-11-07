import { useDeferredValue, useState } from "react";
import { Link, useParams } from "react-router-dom";
import Icon from "../components/Icon";
import { Crumbs, DataTable, EmptyState, ErrorState, MoneyText, PageHeader, Pager, QtyText } from "../components/ui";
import { centsOf, dateOnly, isPositiveAmount } from "../lib/format";
import { useAdminSupplier, useAdminSuppliers } from "../services/admin";

// Each supplier belongs to one store. Wholesale prices come from that store's purchase invoices;
// nothing is merged across stores.

const storeCell = (s) => (
  <>
    <Link className="row-link" to={`/admin/stores/${s.store.id}`}>
      {s.store.name}
    </Link>
    <span className="cell-sub">{s.store.area || "لا منطقة"}</span>
  </>
);

const phoneCell = (phone) => (phone ? <span className="cell-sub m" dir="ltr">{phone}</span> : <span className="cell-sub">بلا رقم</span>);

/** Platform owner · every store's suppliers, searchable by supplier, by a product it delivers and by store. */
export default function AdminSuppliers() {
  const [search, setSearch] = useState("");
  const [store, setStore] = useState("");
  const [pageNo, setPageNo] = useState(1);
  const supplierQuery = useDeferredValue(search.trim());
  const storeQuery = useDeferredValue(store.trim());
  const list = useAdminSuppliers({ search: supplierQuery, store: storeQuery, page: pageNo, per_page: 25 });

  return (
    <>
      <PageHeader
        title="الموردون"
        sub={list.data?.meta ? `${list.data.meta.total} مورداً في كل المتاجر، مع الأصناف وآخر سعر جملة` : " "}
      />
      <div className="toolbar">
        <label className="search grow">
          <span className="sr-only">بحث بالمورد أو المنتج</span>
          <Icon name="search" size={18} />
          <input
            className="fld"
            type="search"
            placeholder="اسم المورد أو رقمه أو منتج يورّده"
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
        caption="الموردون في كل المتاجر"
        minWidth={900}
        empty={
          supplierQuery || storeQuery ? (
            <EmptyState icon="search" title="لا مورد يطابق هذا البحث" text="جرّب جزءاً من اسم المورد أو المنتج." />
          ) : (
            <EmptyState icon="truck" title="لم تسجّل المتاجر أي مورد بعد" text="يظهر المورد هنا بعد أول «تسجيل بضاعة» في المتجر." />
          )
        }
        columns={[
          {
            key: "name",
            label: "المورد",
            render: (s) => (
              <>
                <Link className="row-link" to={`/admin/suppliers/${s.id}`}>
                  {s.name}
                </Link>
                {phoneCell(s.phone)}
              </>
            ),
          },
          { key: "store", label: "المتجر", render: storeCell },
          { key: "products", label: "الأصناف", numeric: true, render: (s) => <span className="m">{s.products_count}</span> },
          { key: "last", label: "آخر توريد", render: (s) => dateOnly(s.last_purchase_at) },
          { key: "purchased", label: "مجموع المشتريات", numeric: true, render: (s) => <MoneyText value={s.purchased} /> },
          {
            key: "balance",
            label: "باقي للمورد",
            numeric: true,
            render: (s) => (
              <MoneyText value={s.balance} style={{ fontWeight: 700, color: isPositiveAmount(s.balance) ? "var(--debt-fg)" : "var(--ink-muted)" }} />
            ),
          },
        ]}
      />
      <Pager meta={list.data?.meta} onPage={setPageNo} />
      <p className="data-note">كل مورد تابع لمتجر واحد. افتح المورد لترى الأصناف التي يورّدها وآخر سعر جملة لكل صنف.</p>
    </>
  );
}

/** "₪ 93.00 / كرتونة 6" or "₪ 4.80 / كغ": the wholesale price as it was written on the invoice. */
function Wholesale({ p }) {
  return (
    <span className="price-cell">
      <MoneyText value={p.buy_price} />
      <span className="cell-sub">{p.unit === "kg" ? "/ كغ" : p.pack_size > 1 ? `/ كرتونة ${p.pack_size}` : "/ قطعة"}</span>
    </span>
  );
}

/** The price before the latest one, when it changed: up in orange, down in green. */
function PriceChange({ p }) {
  if (!p.previous_buy_price) return null;
  const up = centsOf(p.buy_price) > centsOf(p.previous_buy_price);
  return (
    <span className={up ? "price-tag is-high" : "price-tag is-low"}>
      {up ? "ارتفع" : "نزل"}، كان <MoneyText value={p.previous_buy_price} />
    </span>
  );
}

/** Platform owner · one supplier: what it delivers, its latest wholesale price, and the store's selling price. */
export function AdminSupplier() {
  const { id } = useParams();
  const supplier = useAdminSupplier(id);

  if (supplier.isError) return <ErrorState error={supplier.error} onRetry={() => supplier.refetch()} />;
  const s = supplier.data;

  return (
    <>
      <Crumbs items={[["الموردون", "/admin/suppliers"], [s?.name ?? "…"]]} />
      <PageHeader
        title={s?.name ?? " "}
        sub={s ? `مورد ${s.store.name}${s.phone ? `، رقمه ${s.phone}` : ""}، آخر توريد ${dateOnly(s.last_purchase_at)}` : " "}
      >
        {s ? (
          <Link className="btn btn-s btn-sm" to={`/admin/stores/${s.store.id}`}>
            صفحة المتجر
          </Link>
        ) : null}
      </PageHeader>
      {s ? (
        <p className="price-compare" role="note">
          اشترى المتجر منه بـ <MoneyText value={s.purchased} />، وباقي له <b><MoneyText value={s.balance} /></b>.
        </p>
      ) : null}
      <DataTable
        query={supplier}
        rows={s?.products ?? []}
        caption={`الأصناف التي يورّدها ${s?.name ?? ""}`}
        minWidth={960}
        empty={<EmptyState icon="products" title="لا أصناف من هذا المورد بعد" />}
        columns={[
          {
            key: "name",
            label: "المنتج",
            render: (p) => (
              <>
                <b style={{ fontWeight: 600 }}>{p.name}</b>
                <span className="cell-sub">{p.barcode ? <span className="m">{p.barcode}</span> : "بلا باركود"}</span>
              </>
            ),
          },
          { key: "wholesale", label: "سعر الجملة", render: (p) => <Wholesale p={p} /> },
          { key: "piece", label: "للقطعة", numeric: true, render: (p) => (p.piece_price ? <MoneyText value={p.piece_price} /> : <span className="cell-sub">—</span>) },
          { key: "sell", label: "سعر البيع بالمتجر", numeric: true, render: (p) => <MoneyText value={p.selling_price} /> },
          { key: "qty", label: "الكمية المورّدة", numeric: true, render: (p) => <QtyText value={p.quantity} unit={p.unit} /> },
          {
            key: "last",
            label: "آخر سعر بتاريخ",
            render: (p) => (
              <>
                {dateOnly(p.last_at)} <PriceChange p={p} />
              </>
            ),
          },
        ]}
      />
      <p className="data-note">سعر الجملة هو آخر سعر في فاتورة شراء، بالكرتونة أو بالكيلو كما كُتب، وسعر القطعة محسوب منه.</p>
    </>
  );
}
