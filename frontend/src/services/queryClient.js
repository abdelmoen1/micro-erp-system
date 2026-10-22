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
  },
  customers: {
    all: ["customers"],
    detail: (id) => ["customers", "detail", id],
  },
  debts: { all: ["debts"] },
};
