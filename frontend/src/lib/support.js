// Technical support complaints: the same labels on the store's settings and the admin's section.

export const TICKET_TYPES = [
  ["technical", "مشكلة تقنية"],
  ["account", "الحساب والاشتراك"],
  ["suggestion", "اقتراح"],
  ["other", "أخرى"],
];

export const ticketTypeLabel = (type) => TICKET_TYPES.find(([key]) => key === type)?.[1] ?? type;

/** Status → [label, StatusBadge key] (the badge key picks the tone and icon). */
export const TICKET_STATUS = {
  open: ["جديدة", "unpaid"],
  in_progress: ["قيد المعالجة", "partial"],
  closed: ["مغلقة", "paid"],
};
