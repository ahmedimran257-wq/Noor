import { Suspense } from "react";
import { requireAdmin } from "@/lib/auth";
import { AdminSidebar } from "@/components/admin-sidebar";
import { AdminTopbar } from "@/components/admin-topbar";
import { FlashToast } from "@/components/client-ui";
import { NavigationProvider } from "@/components/navigation-state";

function environmentOf(url: string | undefined) {
  try {
    const ref = new URL(url ?? "").hostname.split(".")[0];
    if (ref === "jukpscfxzwttgtxvrbmj") return "production" as const;
    if (ref === "ykmgkrveucslglxvcyss") return "staging" as const;
  } catch {
    // Fall through to local.
  }
  return "local" as const;
}

export default async function StaffLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  // Shares one cached admin_console_context call with the page below.
  const admin = await requireAdmin();
  return (
    <NavigationProvider>
      <div className="shell">
        <AdminSidebar email={admin.email} role={admin.role} counts={admin.counts} />
        <div className="main">
          <AdminTopbar environment={environmentOf(process.env.NEXT_PUBLIC_SUPABASE_URL)} />
          <main className="content" id="main">{children}</main>
        </div>
      </div>
      <Suspense fallback={null}>
        <FlashToast />
      </Suspense>
    </NavigationProvider>
  );
}
