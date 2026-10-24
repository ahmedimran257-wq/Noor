import Link from "next/link";

export default function NotFound() {
  return (
    <main className="auth">
      <section className="auth-card">
        <p className="eyebrow">Not found</p>
        <h1>This page does not exist</h1>
        <p className="lede">The link may be old. Everything in the console is reachable from the sidebar.</p>
        <div className="auth-form">
          <Link href="/dashboard" className="btn btn-primary">Go to overview</Link>
        </div>
      </section>
    </main>
  );
}
