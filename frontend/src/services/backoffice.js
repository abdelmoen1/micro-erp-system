import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiIdempotent, apiSend, session } from "./apiClient";
import { queryKeys } from "./queryClient";

// S3 back-office data (W-06 … W-15). Reads return the API page as is ({ data, meta }); writes
// invalidate every list a change can touch. Financial writes go through apiIdempotent with a key
// the dialog created once, when it opened (05 §4.1).

/** "?a=1&b=x" from the set values only. */
export function qs(params = {}) {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== "") search.set(key, value);
  }
  const text = search.toString();
  return text ? `?${text}` : "";
}

const page = (path) => ({ signal }) => apiGet(path, { signal });
const data = (path) => ({ signal }) => apiGet(path, { signal }).then((r) => r.data);

/** After any money or stock write: everything derived from debts, payments, sales and stock. */
function useInvalidateLedger() {
  const client = useQueryClient();
  return () =>
    Promise.all(
      [queryKeys.customers.all, queryKeys.debts.all, queryKeys.payments.all, queryKeys.sales.all, queryKeys.products.all, ["dashboard"]].map(
        (queryKey) => client.invalidateQueries({ queryKey }),
      ),
    );
}

// ---------------------------------------------------------------- customers (W-06, W-07)
export const useCustomers = (filters) =>
  useQuery({ queryKey: queryKeys.customers.list(filters), queryFn: page(`/customers${qs(filters)}`), placeholderData: (p) => p });

export const useCustomer = (id) => useQuery({ queryKey: queryKeys.customers.detail(id), queryFn: data(`/customers/${id}`) });

export const useCustomerSummary = (id) => useQuery({ queryKey: queryKeys.customers.summary(id), queryFn: data(`/customers/${id}/summary`) });

export const useStatement = (id, range) =>
  useQuery({
    queryKey: queryKeys.customers.statement(id, range),
    queryFn: data(`/customers/${id}/statement${qs(range)}`),
    placeholderData: (p) => p,
  });

export function useSaveCustomer() {
  const client = useQueryClient();
  return useMutation({
    // POST answers { customer }, PATCH answers { data }.
    mutationFn: ({ id, ...body }) => (id ? apiSend("PATCH", `/customers/${id}`, body) : apiSend("POST", "/customers", body)).then((r) => r.data ?? r.customer),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.customers.all }),
  });
}

export function useCustomerStatus() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, active }) => apiSend("POST", `/customers/${id}/${active ? "reactivate" : "deactivate"}`).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.customers.all }),
  });
}

// ---------------------------------------------------------------- products (W-08, W-09, review, import)
export const useProducts = (filters) =>
  useQuery({ queryKey: queryKeys.products.list(filters), queryFn: page(`/products${qs(filters)}`), placeholderData: (p) => p });

export const useProduct = (id) => useQuery({ queryKey: queryKeys.products.detail(id), queryFn: data(`/products/${id}`), enabled: Boolean(id) });

/** Shared catalog, before adding: { product } already in my store, or the { catalog_product } another store saved. */
export const lookupCatalog = (barcode) => apiGet(`/products/catalog-lookup${qs({ barcode })}`).then((r) => r.data);

export const useMovements = (id) =>
  useQuery({ queryKey: queryKeys.products.movements(id), queryFn: data(`/products/${id}/movements`), enabled: Boolean(id) });

export const useNegativeStock = () => useQuery({ queryKey: queryKeys.products.negative, queryFn: data("/products/negative-stock") });

export function useSaveProduct() {
  const client = useQueryClient();
  return useMutation({
    // The product endpoints answer { product } (POST) or { data } / { product } (PATCH).
    mutationFn: ({ id, ...body }) => (id ? apiSend("PATCH", `/products/${id}`, body) : apiSend("POST", "/products", body)).then((r) => r.data ?? r.product),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.products.all }),
  });
}

/** Stop a product (hidden from sale and the list) or bring it back as it was (FR-16). */
export function useProductStatus() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, active }) => (active ? apiSend("PATCH", `/products/${id}`, { status: "active" }) : apiSend("POST", `/products/${id}/deactivate`)),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.products.all }),
  });
}

export function useAdjustStock() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ key, ...body }) => apiIdempotent("POST", "/stock-adjustments", body, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

/** US-0408: dryRun checks the file; the second call imports it. */
export function useImportProducts() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ file, dryRun }) => {
      const form = new FormData();
      form.append("file", file);
      form.append("dry_run", dryRun ? "1" : "0");
      return apiSend("POST", "/products/import", form).then((r) => r.data);
    },
    onSuccess: (_, { dryRun }) => (dryRun ? undefined : client.invalidateQueries({ queryKey: queryKeys.products.all })),
  });
}

// ---------------------------------------------------------------- sales (W-10, W-11, W-12)
export const useSales = (filters) =>
  useQuery({ queryKey: queryKeys.sales.list(filters), queryFn: page(`/sales${qs(filters)}`), placeholderData: (p) => p });

export const useSale = (id) => useQuery({ queryKey: queryKeys.sales.detail(id), queryFn: data(`/sales/${id}`) });

export function useVoidSale() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ id, reason, key }) => apiIdempotent("POST", `/sales/${id}/void`, { reason }, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

export function useReturnSale() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ id, items, reason, key }) => apiIdempotent("POST", `/sales/${id}/returns`, { items, reason }, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

// ---------------------------------------------------------------- debts and payments (W-13, W-14)
export const useDebts = (filters) =>
  useQuery({ queryKey: queryKeys.debts.list(filters), queryFn: page(`/debts${qs(filters)}`), placeholderData: (p) => p });

export const useBalances = (enabled = true) => useQuery({ queryKey: queryKeys.debts.balances, queryFn: data("/debts/balances"), enabled });

export const usePayments = (filters) =>
  useQuery({ queryKey: queryKeys.payments.list(filters), queryFn: page(`/payments${qs(filters)}`), placeholderData: (p) => p });

/** Pay a customer: the whole balance, or `amount` to the oldest due debts first. */
export function usePayCustomer() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ customerId, amount, method, key }) =>
      apiIdempotent("POST", `/customers/${customerId}/debts/pay-all`, { method, ...(amount ? { amount } : {}) }, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

export function useReversePayment() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ operation, reason, key }) =>
      operation.payment_group_id
        ? apiIdempotent("POST", `/payment-groups/${operation.payment_group_id}/reverse`, { reason }, { idempotencyKey: key })
        : apiIdempotent("POST", `/payments/${operation.id}/reverse`, { reason }, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

export function useOpeningDebt() {
  const invalidate = useInvalidateLedger();
  return useMutation({
    mutationFn: ({ key, ...body }) => apiIdempotent("POST", "/debts", body, { idempotencyKey: key }),
    onSuccess: invalidate,
  });
}

// ---------------------------------------------------------------- offline sync review (SCR-W-18)
export const useSyncConflicts = (filters, enabled = true) =>
  useQuery({ queryKey: queryKeys.sync.list(filters), queryFn: page(`/sync/conflicts${qs(filters)}`), placeholderData: (p) => p, enabled });

/** Acknowledge, apply, refund or void an offline item; "apply" records payments, so it is idempotent. */
export function useResolveSyncConflict() {
  const invalidate = useInvalidateLedger();
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, resolution, note, key }) =>
      apiIdempotent("POST", `/sync/conflicts/${id}/resolve`, { resolution, ...(note ? { note } : {}) }, { idempotencyKey: key }),
    onSuccess: () => Promise.all([invalidate(), client.invalidateQueries({ queryKey: queryKeys.sync.all })]),
  });
}

// ---------------------------------------------------------------- staff (W-15)
export const useStaff = () => useQuery({ queryKey: queryKeys.staff.all, queryFn: data("/users") });

export function useStaffAction() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ action, id, role }) =>
      action === "role" ? apiSend("PATCH", `/users/${id}/role`, { role }) : apiSend("POST", `/users/${id}/deactivate`),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.staff.all }),
  });
}

export const useInvite = () => useMutation({ mutationFn: (body) => apiSend("POST", "/invitations", body).then((r) => r.invitation) });

// ---------------------------------------------------------------- settings (store details, password)
export const useMyStore = () => useQuery({ queryKey: queryKeys.myStore, queryFn: ({ signal }) => apiGet("/my-store", { signal }).then((r) => r.store) });

/** PATCH /my-store (owner only). The sidebar and receipts read the store from the saved session user. */
export function useSaveStore() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiSend("PATCH", "/my-store", body).then((r) => r.store),
    onSuccess: (store) => {
      client.setQueryData(queryKeys.myStore, store);
      const user = session.user();
      if (user) session.save(session.token(), { ...user, store: { ...user.store, ...store } });
    },
  });
}

/** Technical support: this store's complaints (an employee's own), with the admin's reply. */
export const useSupportTickets = () => useQuery({ queryKey: queryKeys.support, queryFn: data("/support-tickets"), refetchOnWindowFocus: true });

/** POST /support-tickets { type, subject, details }. */
export function useSendTicket() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiSend("POST", "/support-tickets", body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.support }),
  });
}

/** PATCH /me/password: this browser stays signed in, every other device is signed out. */
export const useChangePassword = () => useMutation({ mutationFn: (body) => apiSend("PATCH", "/me/password", body) });
