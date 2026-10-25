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
