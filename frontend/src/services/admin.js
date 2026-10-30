import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiSend } from "./apiClient";
import { qs } from "./backoffice";
import { queryKeys } from "./queryClient";

// Platform owner data (/admin/*). The server decides who is an admin (users.is_platform_admin);
// these hooks only read and write. Account access and subscription are separate writes.

const page = (path) => ({ signal }) => apiGet(path, { signal });
const data = (path) => ({ signal }) => apiGet(path, { signal }).then((r) => r.data);

// Stores register from the web and the phone at any time: the admin's views refresh when the tab
// is focused again, instead of keeping a 30-second-old list.
const live = { refetchOnWindowFocus: true, staleTime: 5_000 };

export const useAdminOverview = () => useQuery({ queryKey: queryKeys.admin.overview, queryFn: data("/admin/overview"), ...live });

export const useAdminStores = (filters) =>
  useQuery({ queryKey: queryKeys.admin.stores(filters), queryFn: page(`/admin/stores${qs(filters)}`), placeholderData: (p) => p, ...live });

export const useAdminStore = (id) => useQuery({ queryKey: queryKeys.admin.store(id), queryFn: data(`/admin/stores/${id}`), ...live });

export const useAdminStoreProducts = (id, filters) =>
  useQuery({
    queryKey: queryKeys.admin.storeProducts(id, filters),
    queryFn: page(`/admin/stores/${id}/products${qs(filters)}`),
    placeholderData: (p) => p,
  });

export const useAdminProducts = (filters) =>
  useQuery({ queryKey: queryKeys.admin.products(filters), queryFn: page(`/admin/products${qs(filters)}`), placeholderData: (p) => p });

export const useCatalogItem = (id) => useQuery({ queryKey: queryKeys.admin.catalog(id), queryFn: data(`/admin/catalog-products/${id}`) });

/** The shared catalog: one row per barcode with its store count and price range. */
export const useAdminCatalog = (filters) =>
  useQuery({ queryKey: queryKeys.admin.catalogList(filters), queryFn: page(`/admin/catalog-products${qs(filters)}`), placeholderData: (p) => p });

/** Every store's complaints, newest first; meta.open_count counts the new ones. */
export const useAdminTickets = (filters) =>
  useQuery({ queryKey: queryKeys.admin.tickets(filters), queryFn: page(`/admin/support-tickets${qs(filters)}`), placeholderData: (p) => p, ...live });

/** How many complaints wait for a reply (the sidebar's count). */
export const useOpenTicketCount = (enabled) =>
  useQuery({
    queryKey: queryKeys.admin.tickets({ status: "open", per_page: 1 }),
    queryFn: page("/admin/support-tickets?status=open&per_page=1"),
    select: (r) => r.meta?.open_count ?? 0,
    enabled,
    ...live,
  });

/** { id, status, reply } */
export function useAnswerTicket() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }) => apiSend("PATCH", `/admin/support-tickets/${id}`, body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: ["admin", "tickets"] }),
  });
}

/** { phone, purpose }: a code to read to someone whose SMS did not arrive. */
export function useIssueOtp() {
  return useMutation({ mutationFn: (body) => apiSend("POST", "/admin/otp-codes", body).then((r) => r.data) });
}

/** After either write: the store page, the lists and the overview counts. */
function useStoreWrite(path) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }) => apiSend("POST", `/admin/stores/${id}/${path}`, body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.admin.all }),
  });
}

/** { id, status: "active" | "suspended", reason? } */
export const useSetStoreStatus = () => useStoreWrite("status");

/** { id, status: "active" | "inactive", expires_at?: "YYYY-MM-DD", note? } */
export const useSetSubscription = () => useStoreWrite("subscription");

/**
 * { id, confirm_name }: permanent, the store and everything in it. Lists are only marked stale (they
 * refetch when shown), so the open store page does not refetch a store that no longer exists.
 */
export function useDeleteStore() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, confirm_name }) => apiSend("DELETE", `/admin/stores/${id}`, { confirm_name }).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: queryKeys.admin.all, refetchType: "none" }),
  });
}
