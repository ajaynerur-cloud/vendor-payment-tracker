# VendorPay v3
Run `supabase/schema.sql` on a fresh Supabase project, update `config.js`, and deploy to GitHub Pages.

The first registered user creates the workspace and becomes Owner. Admins invite users by exact email. Invited users create an account with that email and accept the pending invite. Roles: Viewer, Editor, Admin, Owner.

This schema is a replacement schema for a fresh project. Export existing payments before replacing an older schema.
