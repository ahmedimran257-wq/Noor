"use client";

import { usePathname, useRouter, useSearchParams } from "next/navigation";

export function ActionNotice() {
  const params = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();
  const error = params.get("admin_error");
  const success = params.get("admin_success");
  const message = error ?? success;
  if (!message) return null;

  const clear = () => {
    const next = new URLSearchParams(params.toString());
    next.delete("admin_error");
    next.delete("admin_success");
    router.replace(`${pathname}${next.size ? `?${next.toString()}` : ""}`, {
      scroll: false,
    });
  };

  return (
    <div className={`action-notice ${error ? "danger" : "success"}`} role="status">
      <span>{message}</span>
      <button type="button" onClick={clear}>Dismiss</button>
    </div>
  );
}
