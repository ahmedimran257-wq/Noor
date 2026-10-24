"use client";

import { CircleAlert, RotateCw } from "lucide-react";
import { useRouter } from "next/navigation";
import { useTransition } from "react";

// Keeps the sidebar and topbar in place when one page's data fails, so the
// operator can retry or move on without losing their place.
export default function StaffError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <div className="card">
      <div className="empty">
        <span className="empty-icon" aria-hidden="true"><CircleAlert size={22} /></span>
        <h3>This page could not load</h3>
        <p>
          Nothing was changed. Check your connection and retry. If it keeps
          happening, the System health page shows which service is struggling.
        </p>
        {error.digest ? <p className="faint mono">Reference {error.digest}</p> : null}
        <button
          type="button"
          className={`btn btn-primary${pending ? " is-pending" : ""}`}
          onClick={() => startTransition(() => { router.refresh(); reset(); })}
        >
          <RotateCw size={15} /> Retry
        </button>
      </div>
    </div>
  );
}
