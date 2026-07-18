# Silarah email OTP configuration

The Flutter app uses `signInWithOtp(email)` and `verifyOTP(email, token, OtpType.email)` as a six-digit verification-code flow.

1. In Supabase Dashboard, open Authentication, then Email Templates.
2. Set **Confirm signup** to `email_templates/silarah_welcome_verification_code.html`. This is the first-account welcome journey.
3. Set **Magic Link** to `email_templates/silarah_verification_code.html`. This is the returning-member sign-in journey.
4. Keep `{{ .Token }}` in both templates. Do not use `{{ .ConfirmationURL }}`, which creates a sign-in link instead of displaying the code required by the app.
5. Set the email OTP length to 6 and a 10-minute expiry period in Authentication settings.
6. Deploy `auth-before-user-created`, then configure it as the **Before User Created** HTTP Auth Hook. Apply migration `046_disposable_email_protection.sql` before enabling the hook.

The hook fails closed if the disposable-domain lookup is unavailable. Maintain the `public.disposable_email_domains` table as new temporary inbox providers appear.
