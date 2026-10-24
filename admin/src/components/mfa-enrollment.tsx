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
  replace: "The authenticator could not be replaced. Verify your current authenticator first, then try again.",
  verify: "The code was not accepted. Enter a fresh code and try again.",
};

export function MfaEnrollment({ initialFactorId, pendingFactor, error }: MfaEnrollmentProps) {
  const factorId = pendingFactor?.factorId ?? initialFactorId;
  const errorMessage = error ? errorMessages[error] : undefined;

  return (
    <section className="auth-card" aria-labelledby="mfa-title">
      <div className="brand">
        <span className="brand-mark" aria-hidden="true">S</span>
        <span><strong>Silarah</strong><small>Security check</small></span>
      </div>
      <h1 id="mfa-title">{factorId ? "Enter your code" : "Protect this account"}</h1>
      <p className="lede">
        Silarah staff accounts need a six-digit code from an authenticator app.
      </p>

      {!factorId ? (
        <form action={enrollAuthenticatorForm} className="auth-form">
          <p className="muted">
            Set up an authenticator app such as Google Authenticator or 1Password before entering the console.
          </p>
          <button type="submit" className="btn btn-primary">Set up authenticator</button>
        </form>
      ) : (
        <form action={verifyAuthenticatorForm} className="auth-form">
          <input type="hidden" name="factorId" value={factorId} />
          {pendingFactor ? (
            <div className="qr">
              <QRCodeSVG value={pendingFactor.uri} size={176} includeMargin />
              <p className="muted">
                Scan this code with your authenticator app, then enter its current six-digit code below.
              </p>
            </div>
          ) : null}
          <label className="field" htmlFor="totp">Six-digit code
            <input
              id="totp"
              name="code"
              className="input otp"
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6}"
              maxLength={6}
              autoFocus
              placeholder="000000"
              required
            />
          </label>
          {errorMessage ? <p className="notice danger" role="alert"><span>{errorMessage}</span></p> : null}
          <button type="submit" className="btn btn-primary">Verify and continue</button>
        </form>
      )}

      {!factorId && errorMessage ? <p className="notice danger" role="alert"><span>{errorMessage}</span></p> : null}

      <div className="auth-foot">
        <div className="stack">
          {factorId && !pendingFactor ? (
            <details className="disclosure">
              <summary className="text-button">Replace my authenticator</summary>
              <form action={replaceAuthenticatorForm} className="popover-form">
                <input type="hidden" name="factorId" value={factorId} />
                <p className="muted">Replacement requires a session verified with your current authenticator. If you cannot access it, contact another super administrator for account recovery.</p>
                <button type="submit" className="btn btn-sm">Start replacement</button>
              </form>
            </details>
          ) : null}
          <form action={signOut}>
            <button type="submit" className="text-button">Use another staff account</button>
          </form>
        </div>
      </div>
    </section>
  );
}
