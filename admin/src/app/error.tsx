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
    <main className="auth">
      <section className="auth-card">
        <div className="empty-icon"><ShieldAlert size={22} /></div>
        <p className="eyebrow">Admin safety boundary</p>
        <h1>Something needs attention</h1>
        <p className="lede">
          The console stopped this operation before it could continue. Nothing
          was changed. Try again, or check System health if it repeats.
        </p>
        <p className="notice danger"><span>The operation could not be completed. Please try again.</span></p>
        {error.digest ? <small className="faint">Digest: {error.digest}</small> : null}
        <div className="auth-form">
          <button className="btn btn-primary" type="button" onClick={reset}>
            Retry
          </button>
        </div>
      </section>
    </main>
  );
}
