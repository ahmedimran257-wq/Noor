import { ArrowRight, BadgeCheck, Fingerprint, KeyRound, LockKeyhole, Radio, Server, ShieldCheck } from "lucide-react";
import { signIn } from "./actions";

type LoginPageProps = { searchParams: Promise<{ error?: string }> };

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const authConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );

  return (
    <main className="auth-page">
      <div className="auth-gridline" />
      <div className="auth-shell">
        <section className="auth-command" aria-label="Silarah operations security posture">
          <div className="auth-lockup">
            <div className="brand-mark enterprise"><ShieldCheck size={28} /></div>
            <div>
              <p className="eyebrow">Silarah Command</p>
              <h1>Operations access gateway</h1>
            </div>
          </div>

          <p className="auth-lead">
            Staff-only control for trust, photo checks, moderation, subscriptions, campaigns, and live platform health.
          </p>

          <div className="auth-system-panel">
            <div className="system-row">
              <Server size={17} />
              <span>Supabase Auth</span>
              <strong className={authConfigured ? "good" : "danger"}>{authConfigured ? "Configured" : "Needs env"}</strong>
            </div>
            <div className="system-row">
              <Fingerprint size={17} />
              <span>MFA challenge</span>
              <strong className="good">Required</strong>
            </div>
            <div className="system-row">
              <BadgeCheck size={17} />
              <span>Staff membership</span>
              <strong className="good">RLS gated</strong>
            </div>
            <div className="system-row">
              <Radio size={17} />
              <span>Live cockpit</span>
              <strong className="good">After sign-in</strong>
            </div>
          </div>

          <div className="auth-orbit" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
        </section>

        <section className="auth-panel enterprise-panel" aria-labelledby="login-title">
          <div className="auth-panel-head">
            <div className="mini-mark"><LockKeyhole size={20} /></div>
            <div>
              <p className="eyebrow">Secure staff sign in</p>
              <h2 id="login-title">Enter admin console</h2>
            </div>
          </div>

          <form action={signIn} className="auth-form enterprise-form">
            <label htmlFor="email">Work email</label>
            <div className="auth-input">
              <KeyRound size={18} />
              <input id="email" name="email" type="email" autoComplete="email" required />
            </div>
            <label htmlFor="password">Password</label>
            <div className="auth-input">
              <LockKeyhole size={18} />
              <input id="password" name="password" type="password" autoComplete="current-password" required />
            </div>
            {params.error ? <p className="form-error" role="alert">{params.error}</p> : null}
            <button type="submit" className="primary-button auth-submit">Continue <ArrowRight size={18} /></button>
          </form>

          <div className="auth-footnote">
            <span className="live-dot" />
            Authorized staff only. Every sensitive action is role-gated and audit logged.
          </div>
        </section>
      </div>
    </main>
  );
}
