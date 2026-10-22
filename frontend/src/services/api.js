import { apiSend, session } from "./apiClient";

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

/**
 * Google sign-in with the ID token from the Google button. A known account comes back with
 * { user, token }; a new one with { onboarding: { token, name, email } } and no session yet.
 */
export async function googleSignIn(credential) {
  const result = await apiSend("POST", "/auth/google", { credential });
  if (result.token) session.save(result.token, result.user);
  return result;
}

/** Onboarding after Google: creates the store with the account sealed in onboarding_token. */
export async function registerStoreWithGoogle(data) {
  const result = await apiSend("POST", "/register/google", data);
  session.save(result.token, result.user);
  return result;
}
