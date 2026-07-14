import { requireAdmin } from "@/lib/auth";
import { ActionNotice } from "@/components/action-notice";
import { AdminAutoRefresh } from "@/components/admin-auto-refresh";
import { AdminSidebar } from "@/components/admin-sidebar";
import { AdminTopbar } from "@/components/admin-topbar";

export default async function StaffLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  const admin = await requireAdmin();
  const projectRef = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL!).hostname.split(".")[0];
  return (
    <div className="admin-shell">
      <AdminSidebar email={admin.email} role={admin.role} />
      <main className="admin-main">
        <AdminTopbar projectRef={projectRef} />
        <AdminAutoRefresh />
        <div className="admin-content">
          <ActionNotice />
          {children}
        </div>
      </main>
    </div>
  );
}
