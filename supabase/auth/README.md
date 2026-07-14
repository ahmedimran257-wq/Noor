# Silarah email OTP configuration

The Flutter app uses `signInWithOtp(email)` and `verifyOTP(email, token, OtpType.email)` as a six-digit verification-code flow.

1. In Supabase Dashboard, open Authentication, then Email Templates.
2. Replace the **Magic Link** template with `email_templates/silarah_verification_code.html`.
3. Keep `{{ .Token }}` in the template. Do not use `{{ .ConfirmationURL }}`, which creates a sign-in link instead of displaying the code required by the app.
4. Set the email OTP length to 6 and choose a short expiry period in Authentication settings.
5. Deploy `auth-before-user-created`, then configure it as the **Before User Created** HTTP Auth Hook. Apply migration `046_disposable_email_protection.sql` before enabling the hook.

The hook fails closed if the disposable-domain lookup is unavailable. Maintain the `public.disposable_email_domains` table as new temporary inbox providers appear.
