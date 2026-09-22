# VendorPay v4 - Safe Existing Database Upgrade

This package keeps the existing `payments` table and existing payment rows. It adds workspace, membership, invitation and role-management objects.

## Required order
1. Back up/export existing payments as an extra safety measure.
2. In the existing Supabase project, run `supabase/upgrade_existing_database.sql` once.
3. Keep the existing Supabase Project URL and anon/publishable key in `config.js`.
4. Replace the GitHub repository files with this package and deploy.
5. Clear the old PWA site data or unregister the old service worker once.

## Existing data migration
The upgrade creates one personal workspace for each existing `payments.user_id`, assigns that user as owner, adds a nullable `workspace_id` column, and links existing rows to the owner's workspace. It does not drop or recreate `payments`.

## Additional users
Owner/Admin creates an invitation using the exact email. The invited person registers with that email, signs in, and accepts the invitation. Viewer can view/export; Editor can maintain payments; Admin can maintain payments and users.

Never put a Supabase service-role key in `config.js`.
