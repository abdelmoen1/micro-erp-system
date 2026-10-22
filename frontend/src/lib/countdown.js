import { useEffect, useState } from "react";

/** Seconds left of a 429 Retry-After (W-01 / W-02 throttling); 0 when the wait is over. */
export function useCountdown(seconds) {
  const [left, setLeft] = useState(0);
  useEffect(() => {
    if (!seconds) return undefined;
    setLeft(seconds);
    const timer = setInterval(() => setLeft((n) => (n <= 1 ? (clearInterval(timer), 0) : n - 1)), 1000);
    return () => clearInterval(timer);
  }, [seconds]);
  return left;
}

/** 42 → "0:42". */
export const clock = (seconds) => `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, "0")}`;
