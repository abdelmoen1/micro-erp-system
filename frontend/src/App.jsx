import { lazy, Suspense } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import ProtectedRoute from "./components/ProtectedRoute";
import Login from "./pages/Login";
import Join from "./pages/Join";
import Forgot from "./pages/Forgot";

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
const Purchases = lazy(() => import("./pages/Purchases").then((m) => ({ default: m.Purchases })));
const PurchaseDetail = lazy(() => import("./pages/Purchases").then((m) => ({ default: m.PurchaseDetail })));
const Suppliers = lazy(() => import("./pages/Suppliers").then((m) => ({ default: m.Suppliers })));
const SupplierDetail = lazy(() => import("./pages/Suppliers").then((m) => ({ default: m.SupplierDetail })));
const Returns = lazy(() => import("./pages/Returns"));
const Debts = lazy(() => import("./pages/Collections").then((m) => ({ default: m.Debts })));
const Payments = lazy(() => import("./pages/Collections").then((m) => ({ default: m.Payments })));
const Staff = lazy(() => import("./pages/Staff"));
const SyncReview = lazy(() => import("./pages/SyncReview"));
const Settings = lazy(() => import("./pages/Settings"));
const AcceptInvite = lazy(() => import("./pages/AcceptInvite"));
const SubscriptionExpired = lazy(() => import("./pages/SubscriptionExpired"));
// Platform owner area: its own shell; the API refuses every /admin call from a store account.
const AdminLogin = lazy(() => import("./pages/AdminLogin"));
const AdminShell = lazy(() => import("./pages/AdminShell"));
const AdminStores = lazy(() => import("./pages/AdminStores"));
const AdminStore = lazy(() => import("./pages/AdminStore"));
const AdminProducts = lazy(() => import("./pages/AdminProducts"));
const AdminSuppliers = lazy(() => import("./pages/AdminSuppliers"));
const AdminSupplier = lazy(() => import("./pages/AdminSuppliers").then((m) => ({ default: m.AdminSupplier })));
const AdminCatalogItem = lazy(() => import("./pages/AdminProducts").then((m) => ({ default: m.AdminCatalogItem })));
const AdminSupport = lazy(() => import("./pages/AdminSupport"));
const AdminSubscriptions = lazy(() => import("./pages/AdminSubscriptions"));
const AdminDeletions = lazy(() => import("./pages/AdminDeletions"));
// Public: account deletion without the app (Google Play account-deletion requirement).
const DeleteAccount = lazy(() => import("./pages/DeleteAccount"));
const AdminCatalog = lazy(() => import("./pages/AdminProducts").then((m) => ({ default: m.AdminCatalog })));

export default function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={null}>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/join" element={<Join />} />
          <Route path="/forgot" element={<Forgot />} />
          <Route path="/invite" element={<AcceptInvite />} />
          <Route path="/delete-account" element={<DeleteAccount />} />
          {/* Old links (and the mobile app) still point at /register. */}
          <Route path="/register" element={<Navigate to="/join" replace />} />
          <Route element={<ProtectedRoute />}>
            <Route path="/subscription-expired" element={<SubscriptionExpired />} />
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
              <Route path="/purchases" element={<Purchases />} />
              <Route path="/purchases/:id" element={<PurchaseDetail />} />
              <Route path="/suppliers" element={<Suppliers />} />
              <Route path="/suppliers/:id" element={<SupplierDetail />} />
              <Route path="/returns" element={<Returns />} />
              <Route path="/debts" element={<Debts />} />
              <Route path="/payments" element={<Payments />} />
              <Route path="/staff" element={<Staff />} />
              <Route path="/sync" element={<SyncReview />} />
              <Route path="/settings" element={<Settings />} />
            </Route>
          </Route>
          {/* AdminShell sends a visitor without a session to /admin/login. */}
          <Route path="/admin/login" element={<AdminLogin />} />
          <Route element={<AdminShell />}>
            <Route path="/admin" element={<AdminStores />} />
            <Route path="/admin/stores/:id" element={<AdminStore />} />
            <Route path="/admin/products" element={<AdminProducts />} />
            <Route path="/admin/suppliers" element={<AdminSuppliers />} />
            <Route path="/admin/suppliers/:id" element={<AdminSupplier />} />
            <Route path="/admin/catalog" element={<AdminCatalog />} />
            <Route path="/admin/catalog/:id" element={<AdminCatalogItem />} />
            <Route path="/admin/support" element={<AdminSupport />} />
            <Route path="/admin/subscriptions" element={<AdminSubscriptions />} />
            <Route path="/admin/deletions" element={<AdminDeletions />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
