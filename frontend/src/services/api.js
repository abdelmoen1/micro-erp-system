// Base URL of the Laravel API (v1). Override with VITE_API_URL, e.g.
// VITE_API_URL=https://api.example.com/api/v1. The default goes through the
// Vite dev-server proxy (vite.config.js) to the local Laravel server.
const API_URL = (import.meta.env.VITE_API_URL || "/api/v1").replace(/\/+$/, "");

export async function loginUser(data) {
  const response = await fetch(`${API_URL}/login`, {
    method: "POST",

    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },

    body: JSON.stringify(data),
  });

  const result = await response.json();

  if (!response.ok) {
    throw result;
  }
  localStorage.setItem("token", result.token);
  localStorage.setItem("user", JSON.stringify(result.user));
  return result;
}
