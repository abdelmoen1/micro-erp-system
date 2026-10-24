import { QueryClient } from "@tanstack/react-query";
import { ApiError, NetworkError } from "./apiClient";

// TanStack Query setup (US-1201). Server data lives in the query cache only; screens do not copy it
// into their own state.
//
// Reads retry a transient failure (no response, 5xx) twice and never retry a final 4xx.
// Writes never retry here: financial writes retry inside apiIdempotent() with the same
// Idempotency-Key, and a non-financial write is repeated only by the user.

export function shouldRetryQuery(failureCount, error) {
  if (error instanceof ApiError && error.status < 500) return false;
  return failureCount < 2 && (error instanceof NetworkError || error instanceof ApiError);
}

export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        retry: shouldRetryQuery,
        staleTime: 30_000,
        refetchOnWindowFocus: false,
      },
      mutations: {
        retry: false,
      },
    },
  });
}

// One place for cache keys, so invalidation after a write hits every screen that shows the data.
export const queryKeys = {
  me: ["me"],
  dashboard: (period) => ["dashboard", period],
  sales: {
    all: ["sales"],
    list: (filters) => ["sales", "list", filters],
    detail: (id) => ["sales", "detail", id],
  },
  products: {
    all: ["products"],
    list: (filters) => ["products", "list", filters],
    detail: (id) => ["products", "detail", id],
    movements: (id) => ["products", "movements", id],
    negative: ["products", "negative"],
  },
  customers: {
    all: ["customers"],
    list: (filters) => ["customers", "list", filters],
    detail: (id) => ["customers", "detail", id],
    summary: (id) => ["customers", "summary", id],
    statement: (id, range) => ["customers", "statement", id, range],
  },
  debts: {
    all: ["debts"],
    list: (filters) => ["debts", "list", filters],
    balances: ["debts", "balances"],
  },
  payments: {
    all: ["payments"],
    list: (filters) => ["payments", "list", filters],
  },
  staff: { all: ["staff"] },
  admin: {
    all: ["admin"],
    overview: ["admin", "overview"],
    stores: (filters) => ["admin", "stores", filters],
    store: (id) => ["admin", "store", id],
    storeProducts: (id, filters) => ["admin", "store", id, "products", filters],
    products: (filters) => ["admin", "products", filters],
    catalog: (id) => ["admin", "catalog", id],
  },
};
