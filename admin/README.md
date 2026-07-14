# Silarah Admin

Staff-only operations panel for Silarah Matrimony. Browser sessions use the Supabase publishable/anon key, while staff invitations use the server-only service-role key through Server Actions.

## Local setup

1. Copy `.env.example` to `.env.local` and set the Supabase URL, publishable/anon key, service-role key, and admin site URL.
2. Run `npm install` and `npm run dev -- --port 3001`.
3. Open `http://localhost:3001/login`.

## First super admin

The first super admin must be bootstrapped once before the panel can manage staff. After that, use `/staff` to invite staff by email.

1. Create or update the staff member in Supabase Auth.
2. Grant that Auth user the first membership:

```sql
INSERT INTO public.admin_memberships (user_id, role)
VALUES ('<auth-user-uuid>', 'super_admin');
```

3. Sign in to the panel and enroll a TOTP authenticator when prompted.

Staff accounts do not need a row in `public.users` or a matrimony profile.

## Vercel deployment

Create a Vercel project with `admin/` as the root directory. Set `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_ADMIN_SITE_URL`, and `SUPABASE_SERVICE_ROLE_KEY` for Production, Preview, and Development. Never add a Supabase service-role key to a `NEXT_PUBLIC_*` variable.

Run `npm run lint`, `npm run build`, and `npm audit --omit=dev` before deployment.
