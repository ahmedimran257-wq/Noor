import Link from "next/link";

export const metadata = { title: "No staff access" };

export default function UnauthorizedPage() {
  return (
    <main className="auth">
      <section className="auth-card">
        <div className="brand">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </div>
        <h1>This account has no staff access</h1>
        <p className="lede">You have been signed out. Ask a Silarah super admin to invite this email, or sign in with your staff account.</p>
        <div className="auth-form">
          <Link href="/login" className="btn btn-primary">Back to sign in</Link>
        </div>
      </section>
    </main>
  );
}
