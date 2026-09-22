# Vendor Payment Tracker PWA

A browser-based, installable payment tracker with vendor-wise views, totals, search, date/mode filters, CSV export, authentication and cross-device sync through Supabase.

## 1. Supabase setup
1. Create a Supabase project.
2. Open **SQL Editor**, paste `supabase/schema.sql`, and run it once.
3. In **Authentication > Providers**, keep Email enabled. Choose whether email confirmation is required.
4. Open **Project Settings > API** and copy the Project URL and **anon/publishable** key.
5. Put those values in `config.js`. Never put a service-role key in browser code.

## 2. Local test
From this folder run:

```bash
python -m http.server 8080
```

Open `http://localhost:8080`, create an account, sign in, and add a payment.

## 3. Free hosting option A: Cloudflare Pages direct upload
1. Sign in to Cloudflare.
2. Open **Workers & Pages > Create application > Pages > Direct Upload**.
3. Upload this extracted project folder or its ZIP.
4. Cloudflare supplies a `pages.dev` address.

When updating `config.js`, upload a new deployment.

## 4. Free hosting option B: GitHub Pages
1. Create a GitHub repository and upload every file, including `.github/workflows/deploy-pages.yml`.
2. Use the `main` branch.
3. Open **Settings > Pages** and select **GitHub Actions**.
4. Push a commit or run the workflow from **Actions**.

## Security
- Row Level Security restricts every record to its authenticated owner.
- The Supabase anon/publishable key is intended for browser use with RLS.
- Do not use the service-role key in this app.
- Use strong passwords and keep email confirmation enabled for public deployments.

## PWA notes
The application shell is cached for launch reliability. Payment writes require a connection to Supabase. After deployment, use the browser's **Install app** or **Add to Home Screen** command.
