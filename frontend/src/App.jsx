import { lazy, Suspense } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import ProtectedRoute from "./components/ProtectedRoute";
import Login from "./pages/Login";
import Join from "./pages/Join";

// The landing page and the signed-in area load on demand: the login page stays small.
const Landing = lazy(() => import("./pages/Landing"));
const AppShell = lazy(() => import("./pages/AppShell"));
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Customers = lazy(() => import("./pages/Customers"));
const CustomerDetail = lazy(() => import("./pages/CustomerDetail"));
const Products = lazy(() => import("./pages/Products"));
const NegativeStock = lazy(() => import("./pages/Products").then((m) => ({ default: m.NegativeStock })));
const ProductDetail = lazy(() => import("./pages/ProductDetail"));
const Sales = lazy(() => import("./pages/Sales"));
const SaleDetail = lazy(() => import("./pages/SaleDetail"));
const Debts = lazy(() => import("./pages/Collections").then((m) => ({ default: m.Debts })));
const Payments = lazy(() => import("./pages/Collections").then((m) => ({ default: m.Payments })));
const Staff = lazy(() => import("./pages/Staff"));
const AcceptInvite = lazy(() => import("./pages/AcceptInvite"));
// Platform owner area: its own shell; the API refuses every /admin call from a store account.
const AdminShell = lazy(() => import("./pages/AdminShell"));
const AdminStores = lazy(() => import("./pages/AdminStores"));
const AdminStore = lazy(() => import("./pages/AdminStore"));
const AdminProducts = lazy(() => import("./pages/AdminProducts"));
const AdminCatalogItem = lazy(() => import("./pages/AdminProducts").then((m) => ({ default: m.AdminCatalogItem })));

export default function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/join" element={<Join />} />
          <Route path="/invite" element={<AcceptInvite />} />
          {/* Old links (and the mobile app) still point at /register. */}
          <Route path="/register" element={<Navigate to="/join" replace />} />
          <Route element={<ProtectedRoute />}>
            <Route element={<AppShell />}>
              <Route path="/dashboard" element={<Dashboard />} />
              <Route path="/customers" element={<Customers />} />
              <Route path="/customers/:id" element={<CustomerDetail />} />
              <Route path="/products" element={<Products />} />
              <Route path="/products/negative-stock" element={<NegativeStock />} />
              <Route path="/products/new" element={<ProductDetail />} />
              <Route path="/products/:id" element={<ProductDetail />} />
              <Route path="/sales" element={<Sales />} />
              <Route path="/sales/:id" element={<SaleDetail />} />
              <Route path="/debts" element={<Debts />} />
              <Route path="/payments" element={<Payments />} />
              <Route path="/staff" element={<Staff />} />
            </Route>
            <Route element={<AdminShell />}>
              <Route path="/admin" element={<AdminStores />} />
              <Route path="/admin/stores/:id" element={<AdminStore />} />
              <Route path="/admin/products" element={<AdminProducts />} />
              <Route path="/admin/catalog/:id" element={<AdminCatalogItem />} />
            </Route>
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
