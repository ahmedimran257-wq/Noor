"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  Activity,
  BadgeCheck,
  Bell,
  BookOpenCheck,
  FileClock,
  FileText,
  Flag,
  Heart,
  LayoutDashboard,
  LogOut,
  Megaphone,
  Menu,
  ShieldAlert,
  ShieldCheck,
  ShieldPlus,
  Users,
  WalletCards,
  X,
} from "lucide-react";
import { useState } from "react";
import { signOut } from "@/app/(auth)/login/actions";

const groups = [
  {
    label: "Operate",
    items: [
      ["/dashboard", "Overview", LayoutDashboard],
      ["/inbox", "Admin inbox", Bell],
      ["/users", "Members", Users],
    ],
  },
  {
    label: "Trust",
    items: [
      ["/photo-verification", "Photo checks", BadgeCheck],
      ["/moderation", "Moderation", Flag],
      ["/matches", "Matches", Heart],
      ["/subscriptions", "Subscriptions", WalletCards],
    ],
  },
  {
    label: "Publish",
    items: [
      ["/campaigns", "Campaigns", Megaphone],
      ["/content", "Content", FileText],
      ["/stories", "Stories", BookOpenCheck],
    ],
  },
  {
    label: "Govern",
    items: [
      ["/security", "Security", ShieldAlert],
      ["/audit", "Audit trail", FileClock],
      ["/staff", "Staff access", ShieldPlus],
      ["/system", "System health", Activity],
    ],
  },
] as const;

export function AdminSidebar({ email, role }: { email: string; role: string }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        className="mobile-nav-trigger"
        aria-label={open ? "Close navigation" : "Open navigation"}
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        {open ? <X size={19} /> : <Menu size={19} />}
      </button>
      {open ? <button className="sidebar-scrim" aria-label="Close navigation" onClick={() => setOpen(false)} /> : null}
      <aside className={`sidebar ${open ? "is-open" : ""}`}>
        <Link href="/dashboard" className="sidebar-brand" aria-label="Silarah operations home" onClick={() => setOpen(false)}>
          <span className="brand-symbol"><ShieldCheck size={20} /></span>
          <span><strong>Silarah</strong><small>Operations</small></span>
        </Link>

        <nav aria-label="Admin navigation" className="sidebar-nav">
          {groups.map((group) => (
            <div className="nav-group" key={group.label}>
              <span className="nav-section">{group.label}</span>
              {group.items.map(([href, label, Icon]) => {
                const active = pathname === href || pathname.startsWith(`${href}/`);
                return (
                  <Link href={href} className={`nav-item ${active ? "active" : ""}`} aria-current={active ? "page" : undefined} key={href} onClick={() => setOpen(false)}>
                    <Icon size={17} strokeWidth={active ? 2.2 : 1.8} />
                    <span>{label}</span>
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        <div className="staff-summary">
          <div className="staff-avatar">{email.slice(0, 1).toUpperCase()}</div>
          <div className="staff-identity">
            <strong>{email}</strong>
            <span>{role.replace("_", " ")}</span>
          </div>
          <form action={signOut}>
            <button type="submit" className="sign-out" aria-label="Sign out" title="Sign out">
              <LogOut size={16} />
            </button>
          </form>
        </div>
      </aside>
    </>
  );
}
