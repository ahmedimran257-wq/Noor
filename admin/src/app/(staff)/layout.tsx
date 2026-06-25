import Link from "next/link";
import { Activity, BadgeCheck, Bell, BookOpenCheck, FileClock, FileText, Flag, Heart, LayoutDashboard, LogOut, Megaphone, ShieldAlert, ShieldCheck, ShieldPlus, Users, WalletCards } from "lucide-react";
import { requireAdmin } from "@/lib/auth";
import { signOut } from "@/app/(auth)/login/actions";

export default async function StaffLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const admin = await requireAdmin();
  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <Link href="/dashboard" className="sidebar-brand"><ShieldCheck size={22} /><span>Mithaq Admin</span></Link>
        <nav aria-label="Admin navigation">
          <span className="nav-section">Command</span>
          <Link href="/dashboard" className="nav-item"><LayoutDashboard size={18} />Dashboard</Link>
          <Link href="/inbox" className="nav-item"><Bell size={18} />Inbox</Link>
          <Link href="/users" className="nav-item"><Users size={18} />Users</Link>
          <span className="nav-section">Trust & revenue</span>
          <Link href="/kyc" className="nav-item"><BadgeCheck size={18} />KYC & verification</Link>
          <Link href="/moderation" className="nav-item"><Flag size={18} />Moderation</Link>
          <Link href="/matches" className="nav-item"><Heart size={18} />Matches & interests</Link>
          <Link href="/subscriptions" className="nav-item"><WalletCards size={18} />Subscriptions</Link>
          <span className="nav-section">Growth</span>
          <Link href="/campaigns" className="nav-item"><Megaphone size={18} />Campaigns</Link>
          <Link href="/content" className="nav-item"><FileText size={18} />Content</Link>
          <Link href="/stories" className="nav-item"><BookOpenCheck size={18} />Stories</Link>
          <span className="nav-section">Governance</span>
          <Link href="/security" className="nav-item"><ShieldAlert size={18} />Security</Link>
          <Link href="/audit" className="nav-item"><FileClock size={18} />Audit log</Link>
          <Link href="/staff" className="nav-item"><ShieldPlus size={18} />Staff</Link>
          <Link href="/system" className="nav-item"><Activity size={18} />System</Link>
        </nav>
        <div className="staff-summary">
          <span>{admin.email}</span><strong>{admin.role.replace("_", " ")}</strong>
          <form action={signOut}><button type="submit" className="sign-out"><LogOut size={16} />Sign out</button></form>
        </div>
      </aside>
      <main className="admin-main">{children}</main>
    </div>
  );
}
