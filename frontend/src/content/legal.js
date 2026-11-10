// Owner details for the public /privacy and /terms pages. Every null value is shown on the page as
// «[بانتظار صاحب الخدمة]» until it is filled. Do not publish to Google Play before all are filled
// (docs/release-readiness/LEGAL_INFORMATION_REQUIRED.md). Never invent these values.
export const LEGAL = {
  effectiveDate: null, // e.g. "2026-12-01"
  operatorName: null, // legal name of the person or company that runs Hisbah
  operatorAddress: null,
  contactEmail: null,
  contactWhatsApp: null,
  minimumAge: null, // proposed: 18
  serverRegion: null, // Render + Aiven regions
  retentionSubscriptionRecords: null, // how long Hisbah keeps its own subscription/payment records
  retentionTrialHash: null, // how long the one-trial-per-number hash is kept
  retentionDeletionRequests: null,
  retentionAdminLogs: null,
  retentionBackups: null, // e.g. "30 يوماً"
  retentionExpiredStores: null, // how long data of a store that never renews is kept
  manualPaymentMethods: null, // e.g. "تحويل بنكي، محفظة جوال"
  refundPolicy: null,
  governingLaw: null,
  complaintsProcess: null,
};
