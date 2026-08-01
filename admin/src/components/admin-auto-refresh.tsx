"use client";

import { useEffect } from "react";
import { usePathname, useRouter } from "next/navigation";

// Keep server-rendered admin pages aligned with the five-minute metric snapshot
// cadence. Visibility and editor guards below prevent background refreshes.
const refreshMs = 300000;

function hasActiveEditor() {
  const element = document.activeElement;
  if (!element) return false;
  const tag = element.tagName.toLowerCase();
  return (
    tag === "input" ||
    tag === "textarea" ||
    tag === "select" ||
    element.getAttribute("contenteditable") === "true"
  );
}

export function AdminAutoRefresh() {
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    // The dashboard owns its visible-only live feed. Other server-rendered pages
    // refresh less aggressively to avoid duplicate RPC traffic.
    if (pathname === "/dashboard") return;
    let cancelled = false;
    let lastRefreshAt = Date.now();

    const refresh = () => {
      if (cancelled || document.hidden || hasActiveEditor()) return;
      if (Date.now() - lastRefreshAt < refreshMs) return;
      lastRefreshAt = Date.now();
      router.refresh();
    };

    const timer = window.setInterval(refresh, refreshMs);
    const onVisibility = () => {
      if (!document.hidden) refresh();
    };
    const onFocus = () => refresh();

    document.addEventListener("visibilitychange", onVisibility);
    window.addEventListener("focus", onFocus);

    return () => {
      cancelled = true;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisibility);
      window.removeEventListener("focus", onFocus);
    };
  }, [pathname, router]);

  return null;
}
