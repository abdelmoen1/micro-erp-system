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
