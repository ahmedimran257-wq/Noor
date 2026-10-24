"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { LogOut } from "lucide-react";
import { signOut } from "@/app/(auth)/login/actions";
import { navIcons } from "@/components/icons";
import { useNavigation } from "@/components/navigation-state";
import {
  canAccess,
  formatCount,
  navGroups,
  roleLabels,
  type AdminRole,
  type QueueCounts,
} from "@/lib/access";

export function AdminSidebar({
  email,
  role,
  counts,
}: {
  email: string;
  role: AdminRole;
  counts: QueueCounts;
}) {
  const pathname = usePathname();
  const { open, setOpen } = useNavigation();

  return (
    <>
      {open ? (
        <button type="button" className="scrim" aria-label="Close navigation" onClick={() => setOpen(false)} />
      ) : null}
      <aside id="admin-navigation" className={`sidebar${open ? " is-open" : ""}`}>
        <Link href="/dashboard" prefetch={false} className="brand" aria-label="Silarah operations home" onClick={() => setOpen(false)}>
          <span className="brand-mark" aria-hidden="true">S</span>
          <span>
            <strong>Silarah</strong>
            <small>Operations</small>
          </span>
        </Link>

        <nav aria-label="Admin navigation" className="nav">
          {navGroups.map((group) => {
            const items = group.items.filter((item) => canAccess(role, item.area));
            if (items.length === 0) return null;
            return (
              <div className="nav-group" key={group.label}>
                <span className="nav-label">{group.label}</span>
                {items.map((item) => {
                  const Icon = navIcons[item.icon];
                  const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
                  const count = item.count?.(counts) ?? 0;
                  const urgent = item.urgent?.(counts) ?? false;
                  return (
                    // Prefetching every link would render each page (and run
                    // its RPCs) on every load; loading.tsx makes clicks instant.
                    <Link
                      href={item.href}
                      prefetch={false}
                      className={`nav-link${active ? " is-active" : ""}`}
                      aria-current={active ? "page" : undefined}
                      key={item.href}
                      onClick={() => setOpen(false)}
                    >
                      <Icon size={17} strokeWidth={1.8} aria-hidden="true" />
                      <span>{item.label}</span>
                      {count > 0 ? (
                        <span className={`nav-count${urgent ? " is-urgent" : ""}`} aria-label={`${count} waiting`}>
                          {formatCount(count)}
                        </span>
                      ) : null}
                    </Link>
                  );
                })}
              </div>
            );
          })}
        </nav>

        <div className="staff-card">
          <span className="avatar" aria-hidden="true">{email.slice(0, 1).toUpperCase()}</span>
          <span className="who">
            <strong title={email}>{email}</strong>
            <small>{roleLabels[role]}</small>
          </span>
          <form action={signOut}>
            <button type="submit" className="btn btn-ghost btn-sm btn-icon" aria-label="Sign out" title="Sign out">
              <LogOut size={15} />
            </button>
          </form>
        </div>
      </aside>
    </>
  );
}
