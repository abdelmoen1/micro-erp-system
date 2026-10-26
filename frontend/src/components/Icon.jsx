// Stroke icons drawn on a 24 × 24 grid, the same paths as the hi-fi boards (W-01 … W-05).
const PATHS = {
  alert: "M12 3 2 20h20L12 3zM12 10v4M12 17v.5",
  clock: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2",
  info: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v5M12 8v.5",
  ban: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM5.6 5.6l12.8 12.8",
  ok: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8 12l3 3 5-6",
  check: "M20 6 9 17l-5-5",
  copy: "M9 9h11v11H9zM5 15H4V4h11v1",
  dot: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z",
  eye: "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
  eyeOff: "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM3 3l18 18",
  home: "M4 10.5 12 4l8 6.5V20h-5v-5.5H9V20H4z",
  sales: "M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6M9 16h3",
  customers: "M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6M16 4.3a3.5 3.5 0 0 1 0 6.4M18 14.2c2 .8 3.5 2.8 3.5 5.8",
  products: "M12 3 20 7.5v9L12 21l-8-4.5v-9zM4 7.5 12 12l8-4.5M12 12v9",
  debts: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v10M9 9.5h4.5a1.5 1.5 0 0 1 0 3h-3a1.5 1.5 0 0 0 0 3H15",
  payments: "M3 7h18v10H3zM3 11h18M7 15h3",
  staff: "M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21c0-4 3.6-6.5 8-6.5s8 2.5 8 6.5",
  low: "M12 4 3 19h18L12 4zM12 10v4M12 16.5v.5",
  plus: "M12 5v14M5 12h14",
  menu: "M4 7h16M4 12h16M4 17h16",
  logout: "M9 4H5v16h4M14 8l4 4-4 4M18 12H9",
  spinner: "M12 3a9 9 0 1 0 9 9",
  mail: "M3 6h18v12H3zM3 7l9 6 9-6",
  lock: "M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4M12 15v2",
  arrow: "M19 12H5M11 6l-6 6 6 6",
  minus: "M5 12h14",
  search: "M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4",
  barcode: "M4 5v14M7 5v14M10 5v14M14 5v14M16 5v14M20 5v14",
  scale: "M5 20h14M12 4v16M6 8h12M6 8l-3 6h6zM18 8l-3 6h6z",
  upload: "M12 15V3M7 8l5-5 5 5M4 15v5h16v-5",
  edit: "M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4",
  pin: "M12 21s-7-6.2-7-11a7 7 0 0 1 14 0c0 4.8-7 11-7 11zM12 12a2 2 0 1 0 0-4 2 2 0 0 0 0 4z",
  shield: "M12 3 4.5 6v5.5c0 4.6 3.2 8.4 7.5 9.5 4.3-1.1 7.5-4.9 7.5-9.5V6zM9 12l2 2 4-4",
  shop: "M4 9.5 5.5 4h13L20 9.5M4 9.5h16M4 9.5a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0 2.7 2.7 0 0 0 5.3 0M5.5 12.5V20h13v-7.5M10 20v-4.5h4V20",
  calendar: "M4 6h16v14H4zM4 10h16M8 3v5M16 3v5",
  trash: "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v6M14 11v6",
  close: "M6 6l12 12M18 6 6 18",
  settings: "M4 6h9M17 6h3M15 4v4M4 12h3M11 12h9M9 10v4M4 18h11M19 18h1M17 16v4",
};

export default function Icon({ name, size = 20, color = "currentColor", strokeWidth = 2, className, title }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke={color}
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      role={title ? "img" : undefined}
      aria-label={title}
      aria-hidden={title ? undefined : "true"}
      focusable="false"
    >
      <path d={PATHS[name]} />
    </svg>
  );
}
