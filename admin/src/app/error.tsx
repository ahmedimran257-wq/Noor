"use client";

import { ShieldAlert } from "lucide-react";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <main className="auth-page">
      <div className="auth-gridline" />
      <section className="auth-panel enterprise-panel">
        <div className="brand-mark">
          <ShieldAlert size={24} />
        </div>
        <p className="eyebrow">Admin safety boundary</p>
        <h1>Something needs attention</h1>
        <p className="muted">
          The admin panel stopped this operation before it could continue. Try
          again, or check the audit and system pages if it repeats.
        </p>
        <p className="form-error">{error.message || "Unexpected admin error."}</p>
        {error.digest ? <small className="muted">Digest: {error.digest}</small> : null}
        <button className="primary-button" type="button" onClick={reset}>
          Retry
        </button>
      </section>
    </main>
  );
}
