"use client";

import { RefreshCw } from "lucide-react";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useMemo, useState, useTransition } from "react";

const titles: Record<string, string> = {
  dashboard: "Overview",
  inbox: "Admin inbox",
  users: "Members",
  "photo-verification": "Photo checks",
  moderation: "Moderation",
  matches: "Matches",
  subscriptions: "Subscriptions",
  campaigns: "Campaigns",
  content: "Content",
  stories: "Success stories",
  security: "Security",
  audit: "Audit trail",
  staff: "Staff access",
  system: "System health",
};

export function AdminTopbar({ projectRef }: { projectRef: string }) {
  const pathname = usePathname();
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [time, setTime] = useState(() => new Date());

  useEffect(() => {
    const timer = window.setInterval(() => setTime(new Date()), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  const title = useMemo(() => {
    const segment = pathname.split("/").filter(Boolean)[0] ?? "dashboard";
    return titles[segment] ?? "Operations";
  }, [pathname]);

  return (
    <header className="admin-topbar">
      <div className="topbar-title">
        <span>Console</span>
        <strong>{title}</strong>
      </div>
      <div className="topbar-actions">
        <div className="project-state" title={`Supabase project ${projectRef}`}>
          <span className="project-state-dot" />
          <span>Live Supabase</span>
          <code>{projectRef.slice(0, 4)}…{projectRef.slice(-4)}</code>
        </div>
        <time dateTime={time.toISOString()}>{time.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</time>
        <button
          type="button"
          className="icon-button"
          onClick={() => startTransition(() => router.refresh())}
          aria-label="Refresh live data"
          title="Refresh live data"
        >
          <RefreshCw size={16} className={pending ? "spin" : ""} />
        </button>
      </div>
    </header>
  );
}
