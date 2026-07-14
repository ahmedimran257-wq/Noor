import { QRCodeSVG } from "qrcode.react";
import { signOut } from "@/app/(auth)/login/actions";
import {
  enrollAuthenticatorForm,
  type PendingMfaFactor,
  replaceAuthenticatorForm,
  verifyAuthenticatorForm,
} from "@/app/(auth)/mfa/actions";

type MfaEnrollmentProps = {
  initialFactorId?: string;
  pendingFactor?: PendingMfaFactor;
  error?: string;
};

const errorMessages: Record<string, string> = {
  setup: "Authenticator setup could not be started. Please try again.",
  replace: "The authenticator could not be replaced. Check your password and try again.",
  verify: "The code was not accepted. Enter a fresh code and try again.",
};

export function MfaEnrollment({ initialFactorId, pendingFactor, error }: MfaEnrollmentProps) {
  const factorId = pendingFactor?.factorId ?? initialFactorId;
  const errorMessage = error ? errorMessages[error] : undefined;

  return (
    <section className="auth-panel" aria-labelledby="mfa-title">
      <div className="brand-mark">2FA</div>
      <p className="eyebrow">Security check</p>
      <h1 id="mfa-title">Verify your authenticator</h1>
      <p className="muted">
        Silarah staff accounts require a time-based one-time code.
      </p>

      {!factorId ? (
        <form action={enrollAuthenticatorForm} className="auth-form">
          <p className="muted">
            Set up an authenticator app to protect this staff account before entering the console.
          </p>
          <button type="submit" className="primary-button">Set up authenticator</button>
        </form>
      ) : (
        <form action={verifyAuthenticatorForm} className="auth-form">
          <input type="hidden" name="factorId" value={factorId} />
          {pendingFactor ? (
            <div className="qr-wrap">
              <QRCodeSVG value={pendingFactor.uri} size={180} includeMargin />
              <p className="muted">
                Scan this code with your authenticator app, then enter its current six-digit code below.
              </p>
            </div>
          ) : (
            <p className="muted">Enter the current code from your authenticator app.</p>
          )}
          <label htmlFor="totp">Six-digit code</label>
          <input
            id="totp"
            name="code"
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="[0-9]{6}"
            maxLength={6}
            autoFocus
            placeholder="000000"
            required
          />
          <button type="submit" className="primary-button">Verify and continue</button>
        </form>
      )}

      {factorId && !pendingFactor ? (
        <form action={replaceAuthenticatorForm} className="auth-form">
          <input type="hidden" name="factorId" value={factorId} />
          <p className="muted">Cannot access this authenticator? Confirm your password to replace it and receive a new QR code.</p>
          <label htmlFor="replacement-password">Current password</label>
          <input
            id="replacement-password"
            name="password"
            type="password"
            autoComplete="current-password"
            minLength={8}
            required
          />
          <button type="submit" className="primary-button">Replace authenticator</button>
        </form>
      ) : null}

      {errorMessage ? <p className="form-error" role="alert">{errorMessage}</p> : null}
      <form action={signOut}>
        <button type="submit" className="text-button">Use another staff account</button>
      </form>
    </section>
  );
}
