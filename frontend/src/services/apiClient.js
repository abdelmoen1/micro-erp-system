// Shared client for the Laravel API v1 (US-1201 T-1201-1). Every screen calls the API through here
// so the error envelope, the session token and Idempotency-Key handling stay in one place.
//
// Contracts: docs/api/error-codes.md (envelope and codes), docs/api/sales.http, and
// docs/sdlc/proposed/05-data-model-and-api-contracts.md §4.1 (idempotency).

// Base URL of the Laravel API (v1). Override with VITE_API_URL, e.g.
// VITE_API_URL=https://api.example.com/api/v1. The default goes through the
// Vite dev-server proxy (vite.config.js) to the local Laravel server.
export const API_URL = (import.meta.env.VITE_API_URL || "/api/v1").replace(/\/+$/, "");

const TOKEN_KEY = "token";
const USER_KEY = "user";

/** An error response in the v1 envelope: { message, code, errors, details?, correlation_id }. */
export class ApiError extends Error {
  constructor({ status, code, message, errors, details, correlationId, retryAfter }) {
    super(message || "حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.");
    this.name = "ApiError";
    this.status = status;
    this.code = code || `HTTP_${status}`;
    this.errors = errors || {};
    this.details = details || null;
    this.correlationId = correlationId || null;
    /** Seconds from the Retry-After header of a 429 (throttled login / register). */
    this.retryAfter = retryAfter ?? null;
  }

  /** First message for a field, e.g. fieldError("phone"). */
  fieldError(field) {
    const messages = this.errors[field];
    return Array.isArray(messages) && messages.length > 0 ? messages[0] : null;
  }

  /** A final answer: the server decided, so the same request must not be retried. */
  get isFinal() {
    return this.status >= 400 && this.status < 500 && ![408, 409, 428, 429].includes(this.status);
  }
}

/** No response reached us (offline, DNS, timeout). The outcome of a write is unknown. */
export class NetworkError extends Error {
  constructor(cause) {
    super("تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مرة أخرى.");
    this.name = "NetworkError";
    this.cause = cause;
  }
}

// ---------------------------------------------------------------- session

export const session = {
  token: () => readStorage(TOKEN_KEY),
  user() {
    const raw = readStorage(USER_KEY);
    try {
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },
  save(token, user) {
    writeStorage(TOKEN_KEY, token);
    writeStorage(USER_KEY, JSON.stringify(user ?? null));
  },
  clear() {
    removeStorage(TOKEN_KEY);
    removeStorage(USER_KEY);
  },
};

let unauthorizedHandler = () => {
  // W-01 «انتهت الجلسة»: the login screen explains why the user is back there.
  if (typeof window === "undefined") return;
  // The platform owner signs in on their own page.
  const admin = window.location.pathname.startsWith("/admin");
  const target = admin ? "/admin/login" : "/login";
  if (window.location.pathname !== target) {
    window.location.assign(`${target}?expired=1`);
  }
};

/** US-1201 AC2: what happens after any 401 (default: go to /login). The session is cleared first. */
export function onUnauthorized(handler) {
  unauthorizedHandler = handler;
}

/** Path of the renewal screen a store lands on when its trial or subscription has ended. */
export const SUBSCRIPTION_EXPIRED_PATH = "/subscription-expired";

// 403 SUBSCRIPTION_EXPIRED on a store page: the session stays; the renewal screen explains it.
// The server refuses every business call regardless of what the screens show.
let subscriptionExpiredHandler = () => {
  if (typeof window === "undefined") return;
  const path = window.location.pathname;
  if (path !== SUBSCRIPTION_EXPIRED_PATH && !path.startsWith("/admin")) window.location.assign(SUBSCRIPTION_EXPIRED_PATH);
};

export function onSubscriptionExpired(handler) {
  subscriptionExpiredHandler = handler;
}

// ---------------------------------------------------------------- requests

/**
 * Sends one request and returns the parsed JSON body (or null for an empty body).
 * Throws ApiError for an error status and NetworkError when no response arrived.
 */
export async function apiRequest(method, path, { body, idempotencyKey, signal, headers } = {}) {
  const token = session.token();
  // A FormData body (file upload, US-0408) goes as multipart; the browser sets its boundary.
  const multipart = typeof FormData !== "undefined" && body instanceof FormData;
  const init = {
    method,
    signal,
    headers: {
      Accept: "application/json",
      "Accept-Language": "ar",
      ...(body !== undefined && !multipart ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {}),
      ...headers,
    },
    body: body === undefined ? undefined : multipart ? body : JSON.stringify(body),
  };

  let response;
  try {
    response = await fetch(`${API_URL}${path}`, init);
  } catch (cause) {
    if (cause?.name === "AbortError") throw cause;
    throw new NetworkError(cause);
  }

  const payload = await parseJson(response);

  if (!response.ok) {
    const error = new ApiError({
      status: response.status,
      code: payload?.code,
      message: payload?.message,
      errors: payload?.errors,
      details: payload?.details,
      correlationId: payload?.correlation_id ?? response.headers.get("X-Correlation-ID"),
      retryAfter: retryAfterSeconds(response, payload),
    });

    // A protected call that comes back 401 means the session is over (token expired or revoked).
    if (response.status === 401 && token) {
      session.clear();
      unauthorizedHandler(error);
    }
    if (response.status === 403 && error.code === "SUBSCRIPTION_EXPIRED") {
      subscriptionExpiredHandler(error);
    }

    throw error;
  }

  return payload;
}

export const apiGet = (path, options) => apiRequest("GET", path, options);

/** A non-financial write (no Idempotency-Key), e.g. login, register, PATCH notes. */
export const apiSend = (method, path, body, options) => apiRequest(method, path, { ...options, body });

// ---------------------------------------------------------------- idempotent writes

/** A fresh key for a NEW logical operation (05 §4.1: generated when the user confirms). */
export function newIdempotencyKey() {
  if (globalThis.crypto?.randomUUID) {
    return globalThis.crypto.randomUUID();
  }

  // RFC 4122 v4 from getRandomValues, for older browsers.
  const bytes = globalThis.crypto.getRandomValues(new Uint8Array(16));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
}

/**
 * A financial write (POST /sales, /payments, void, …) that the server deduplicates by key.
 *
 * The caller creates the key once per logical operation and passes it on every attempt, so a
 * retry after a timeout or a 5xx can never record the sale twice. Transient failures (no response,
 * 5xx, 409 IDEMPOTENCY_KEY_REUSED aside) are retried here with the SAME key; a final 4xx is thrown
 * at once. When the user changes the request (e.g. confirms a credit-limit override), the caller
 * must use a new key.
 */
export async function apiIdempotent(method, path, body, { idempotencyKey, retries = 2, retryDelayMs = 800, signal } = {}) {
  if (!idempotencyKey) {
    throw new Error("apiIdempotent requires an idempotencyKey; create it once with newIdempotencyKey().");
  }

  for (let attempt = 0; ; attempt++) {
    try {
      return await apiRequest(method, path, { body, idempotencyKey, signal });
    } catch (error) {
      const transient = error instanceof NetworkError || (error instanceof ApiError && error.status >= 500);
      if (!transient || attempt >= retries) throw error;
      await delay(retryDelayMs * (attempt + 1), signal);
    }
  }
}

// ---------------------------------------------------------------- helpers

function retryAfterSeconds(response, payload) {
  const header = Number.parseInt(response.headers.get("Retry-After") ?? "", 10);
  if (Number.isFinite(header)) return header;
  const body = Number.parseInt(payload?.errors?.retry_after?.[0] ?? "", 10);
  return Number.isFinite(body) ? body : null;
}

async function parseJson(response) {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function delay(ms, signal) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    signal?.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(signal.reason);
    });
  });
}

function readStorage(key) {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeStorage(key, value) {
  try {
    localStorage.setItem(key, value);
  } catch {
    // Private mode or blocked storage: the session lasts for this page only.
  }
}

function removeStorage(key) {
  try {
    localStorage.removeItem(key);
  } catch {
    // Nothing stored.
  }
}
