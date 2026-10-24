import { useQuery } from "@tanstack/react-query";
import { apiGet, apiSend, session } from "./apiClient";
import { queryKeys } from "./queryClient";

// W-05 data: GET /dashboard?period=…, GET /products/low-stock and the product count (empty store).

export const useDashboard = (period) =>
  useQuery({
    queryKey: queryKeys.dashboard(period),
    queryFn: ({ signal }) => apiGet(`/dashboard?period=${period}`, { signal }).then((r) => r.data),
    placeholderData: (previous) => previous,
  });

export const useLowStock = () =>
  useQuery({
    queryKey: [...queryKeys.products.all, "low-stock"],
    queryFn: ({ signal }) => apiGet("/products/low-stock", { signal }).then((r) => r.data ?? []),
  });

export const useProductCount = () =>
  useQuery({
    queryKey: [...queryKeys.products.all, "count"],
    queryFn: ({ signal }) => apiGet("/products?status=all", { signal }).then((r) => r.meta?.total ?? r.data?.length ?? 0),
  });

/** POST /logout, then forget the session whatever the answer (the token may already be gone). */
export async function logout() {
  try {
    await apiSend("POST", "/logout");
  } catch {
    // Logged out locally anyway.
  } finally {
    session.clear();
  }
}
