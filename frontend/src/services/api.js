import { apiGet, apiSend, session } from "./apiClient";

// Authentication calls (US-0202 login, US-0201 registration). Both return
// { message, user, token } and start a session.

export async function loginUser(data) {
  const result = await apiSend("POST", "/login", data);
  session.save(result.token, result.user);
  return result;
}

/** DEF-13: POST /register creates the store and its owner, then signs the owner in. */
export async function registerStore(data) {
  const result = await apiSend("POST", "/register", data);
  session.save(result.token, result.user);
  return result;
}

// ---------------------------------------------------------------- sign-in by mobile number

/** GET /auth/options: whether SMS codes are on. Unknown (offline, older server) = off. */
export async function authOptions() {
  try {
    const result = await apiGet("/auth/options");
    return { otp: Boolean(result.data?.otp) };
  } catch {
    return { otp: false };
  }
}

/** POST /auth/otp: a 6-digit code by SMS (register, reset, change_phone). Resolves to the seconds before a new one. */
export async function sendOtp(phone, purpose) {
  const result = await apiSend("POST", "/auth/otp", { phone, purpose });
  return result.data?.resend_in ?? 60;
}

/** POST /auth/password/reset: a forgotten password, by the code sent to the number. */
export const resetPassword = (body) => apiSend("POST", "/auth/password/reset", body);

/** PATCH /me/phone: the number this account signs in with; the stored user follows. */
export async function changePhone(body) {
  const result = await apiSend("PATCH", "/me/phone", body);
  session.save(session.token(), result.user);
  return result;
}
