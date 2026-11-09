import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiGet, apiSend } from "./apiClient";
import { qs } from "./backoffice";
import { queryKeys } from "./queryClient";

// Buying a plan (website only), account deletion, and the platform admin's review screens.
// The server decides prices, entitlements and activation; these hooks only read and request.

const keys = {
  plans: ["subscription", "plans"],
  orders: ["subscription", "orders"],
  deletion: ["me", "deletion"],
  adminOrders: (f) => ["admin", "subscription-orders", f],
  adminOrder: (id) => ["admin", "subscription-order", id],
  adminPlans: ["admin", "subscription-plans"],
  adminDeletions: (f) => ["admin", "deletion-requests", f],
};

export const usePlans = () => useQuery({ queryKey: keys.plans, queryFn: ({ signal }) => apiGet("/subscription/plans", { signal }) });

export const useMyOrders = () =>
  useQuery({ queryKey: keys.orders, queryFn: ({ signal }) => apiGet("/subscription/orders", { signal }).then((r) => r.data) });

/** POST /subscription/orders: `manual_whatsapp` returns the request and its WhatsApp link. */
export function useCreateOrder() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiSend("POST", "/subscription/orders", body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: keys.orders }),
  });
}

export const useMyDeletion = () => useQuery({ queryKey: keys.deletion, queryFn: ({ signal }) => apiGet("/me/deletion", { signal }).then((r) => r.data) });

export function useRequestDeletion() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiSend("POST", "/me/deletion", body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: keys.deletion }),
  });
}

export function useCancelDeletion() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: () => apiSend("DELETE", "/me/deletion").then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: keys.deletion }),
  });
}

/** Public /delete-account page: no session. */
export const requestPublicDeletion = (body) => apiSend("POST", "/account-deletion", body, { headers: { Authorization: "" } });
export const getDeletionStatus = (reference) => apiGet(`/account-deletion/${encodeURIComponent(reference)}`).then((r) => r.data);

// ---- platform admin ----

export const useAdminOrders = (filters) =>
  useQuery({ queryKey: keys.adminOrders(filters), queryFn: ({ signal }) => apiGet(`/admin/subscription-orders${qs(filters)}`, { signal }), placeholderData: (p) => p, refetchOnWindowFocus: true });

export const useAdminOrder = (id) =>
  useQuery({ queryKey: keys.adminOrder(id), queryFn: ({ signal }) => apiGet(`/admin/subscription-orders/${id}`, { signal }).then((r) => r.data), enabled: !!id });

function useOrderAction(path) {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }) => apiSend("POST", `/admin/subscription-orders/${id}/${path}`, body).then((r) => r.data),
    onSuccess: (order) => {
      client.setQueryData(keys.adminOrder(order.id), order);
      client.invalidateQueries({ queryKey: ["admin", "subscription-orders"] });
      client.invalidateQueries({ queryKey: queryKeys.admin.overview });
    },
  });
}
export const useOrderTransition = () => useOrderAction("status");
export const useOrderNote = () => useOrderAction("notes");
export const useConfirmPayment = () => useOrderAction("confirm-payment");

export const useAdminPlans = () => useQuery({ queryKey: keys.adminPlans, queryFn: ({ signal }) => apiGet("/admin/subscription-plans", { signal }) });

export function useUpdatePlan() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }) => apiSend("PATCH", `/admin/subscription-plans/${id}`, body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: keys.adminPlans }),
  });
}

export const useAdminDeletions = (filters) =>
  useQuery({ queryKey: keys.adminDeletions(filters), queryFn: ({ signal }) => apiGet(`/admin/deletion-requests${qs(filters)}`, { signal }).then((r) => r.data) });

export function useResolveDeletion() {
  const client = useQueryClient();
  return useMutation({
    mutationFn: ({ id, ...body }) => apiSend("PATCH", `/admin/deletion-requests/${id}`, body).then((r) => r.data),
    onSuccess: () => client.invalidateQueries({ queryKey: ["admin", "deletion-requests"] }),
  });
}

export const ORDER_STATUS = {
  pending_contact: ["بانتظار التواصل", "pending"],
  awaiting_payment: ["بانتظار الدفع", "pending"],
  payment_verification: ["التحقق من الدفع", "pending"],
  paid: ["مدفوع ومفعّل", "ok"],
  rejected: ["مرفوض", "error"],
  cancelled: ["ملغى", "voided"],
  failed: ["فشل الدفع", "error"],
};

export const LIFECYCLE = {
  trial: "تجربة مجانية",
  active: "مفعّل",
  expiring: "ينتهي قريباً",
  expired: "منتهٍ",
  suspended: "موقوف",
};

export const monthsLabel = (n) => (n === 1 ? "شهر واحد" : n === 2 ? "شهران" : n <= 10 ? `${n} أشهر` : `${n} شهراً`);
