const API_URL = "http://127.0.0.1:8000/api";

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
  localStorage.setItem("user", json.stringify(result.user));
  return result;
}
