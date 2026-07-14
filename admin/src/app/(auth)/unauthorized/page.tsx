import Link from "next/link";

export default function UnauthorizedPage() {
  return <main className="auth-page"><section className="auth-panel"><p className="eyebrow">Access denied</p><h1>This account is not staff-enabled.</h1><p className="muted">Ask a Silarah super administrator to grant access.</p><Link href="/login" className="primary-button">Return to sign in</Link></section></main>;
}
