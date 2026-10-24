"use client";

import { Menu, RefreshCw } from "lucide-react";
import { usePathname } from "next/navigation";
import { useNavigation } from "@/components/navigation-state";
import { pageTitle } from "@/lib/access";

export function AdminTopbar({ environment }: { environment: "production" | "staging" | "local" }) {
  const pathname = usePathname();
  const { open, setOpen, refresh, refreshing } = useNavigation();
  const label = environment === "production" ? "Production" : environment === "staging" ? "Staging" : "Local";

  return (
    <header className="topbar">
      <div className="crumbs">
        <button
          type="button"
          className="btn btn-ghost btn-icon menu-button"
          aria-label={open ? "Close navigation" : "Open navigation"}
          aria-expanded={open}
          aria-controls="admin-navigation"
          onClick={() => setOpen(!open)}
        >
          <Menu size={18} />
        </button>
        <span className="faint">Operations</span>
        <span className="faint" aria-hidden="true">/</span>
        <strong>{pageTitle(pathname)}</strong>
      </div>
      <div className="topbar-actions">
        <span className={`env-chip${environment === "production" ? "" : " is-staging"}`} title="Connected Supabase project">
          <span className="dot" aria-hidden="true" />
          <span className="env-label">{label} data</span>
        </span>
        <button
          type="button"
          className="btn btn-sm"
          onClick={refresh}
          disabled={refreshing}
          aria-label="Refresh this page's data"
        >
          <RefreshCw size={14} className={refreshing ? "spin-icon" : undefined} />
          <span>Refresh</span>
        </button>
      </div>
    </header>
  );
}
