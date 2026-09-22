/* Keep your existing Supabase values here. Never use the service-role key. */
window.PAYMENT_APP_CONFIG = {
  SUPABASE_URL: "https://YOUR_PROJECT_REF.supabase.co",
  SUPABASE_ANON_KEY: "YOUR_SUPABASE_ANON_OR_PUBLISHABLE_KEY"
};
/* Compatibility with both old and new VendorPay builds. */
window.APP_CONFIG = window.PAYMENT_APP_CONFIG;
