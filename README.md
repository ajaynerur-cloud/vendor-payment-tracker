# VendorPay Workspace
1. Run `supabase/schema.sql` in Supabase SQL Editor.
2. Put the Supabase Project URL and anon/publishable key in `config.js`. Never use the service-role key.
3. Upload all files, including `.github/workflows/deploy-pages.yml`, to the repository root.
4. In GitHub Settings > Pages, select GitHub Actions.
5. Create your account, then disable new signups in Supabase if this is for personal use only.

The UI provides a separate visual folder and dedicated view for every vendor, with vendor total, payment count, latest payment, full history, and vendor-specific payment entry.
