import { Bell, ChevronRight, CircleCheck, Flag, ImageIcon, MessageSquareWarning, ScanFace, UserRoundCheck, Users, WalletCards } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import Link from "next/link";
import { LiveOperationsCockpit } from "@/components/live-operations-cockpit";
import { PageHeader, Stat } from "@/components/ui";
import { canAccess, formatCount, type Area } from "@/lib/access";
import { requireAdmin } from "@/lib/auth";
import { getDashboardOverview } from "@/lib/operations";

export const metadata = { title: "Overview" };

type Attention = { label: string; count: number; href: string; area: Area; icon: LucideIcon; urgent?: boolean };

function greeting() {
  const hour = Number(new Intl.DateTimeFormat("en-IN", { hour: "numeric", hourCycle: "h23", timeZone: "Asia/Kolkata" }).format(new Date()));
  if (hour < 12) return "Good morning";
  if (hour < 17) return "Good afternoon";
  return "Good evening";
}

export default async function DashboardPage() {
  const admin = await requireAdmin();
  const overview = await getDashboardOverview();
  const c = admin.counts;
  const metrics = overview.metrics ?? {};

  const candidates: Attention[] = [
    { label: "Photo checks waiting", count: c.photoChecks ?? 0, href: "/photo-verification", area: "photoChecks", icon: ScanFace, urgent: true },
    { label: "Open member reports", count: c.openReports ?? 0, href: "/moderation?tab=reports", area: "moderation", icon: Flag, urgent: true },
    { label: "Reported messages", count: c.messageReports ?? 0, href: "/moderation?tab=messages", area: "moderation", icon: MessageSquareWarning, urgent: true },
    { label: "Photos to review", count: c.pendingPhotos ?? 0, href: "/moderation?tab=photos", area: "moderation", icon: ImageIcon },
    { label: (c.privacyOverdue ?? 0) > 0 ? `Rights requests · ${c.privacyOverdue} overdue` : "Member rights requests", count: c.privacyOpen ?? 0, href: "/privacy", area: "privacy", icon: UserRoundCheck, urgent: (c.privacyOverdue ?? 0) > 0 },
    { label: "Unread alerts", count: c.unreadInbox ?? 0, href: "/inbox?view=unread", area: "inbox", icon: Bell },
  ];
  const attention = candidates.filter((item) => canAccess(admin.role, item.area));
  const waiting = attention.filter((item) => item.count > 0);

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow={new Intl.DateTimeFormat("en-IN", { weekday: "long", day: "numeric", month: "long", timeZone: "Asia/Kolkata" }).format(new Date())}
        title={`${greeting()}`}
        lede={waiting.length === 0
          ? "Every queue is clear. Nothing needs a decision right now."
          : `${waiting.length === 1 ? "One queue needs" : `${waiting.length} queues need`} your attention. Oldest items are shown first on each page.`}
      />

      <section aria-labelledby="attention-title">
        <div className="section-head">
          <h2 id="attention-title">Needs your attention</h2>
        </div>
        <div className="attention">
          {attention.map((item) => {
            const Icon = item.icon;
            const tone = item.count === 0 ? "" : item.urgent ? " is-urgent" : " is-waiting";
            return (
              <Link key={item.href + item.label} href={item.href} prefetch={false} className={`attention-item${tone}`}>
                <span className="attention-icon" aria-hidden="true">
                  {item.count === 0 ? <CircleCheck size={19} /> : <Icon size={19} />}
                </span>
                <span>
                  <strong>{formatCount(item.count)}</strong>
                  <span>{item.label}</span>
                </span>
                <ChevronRight size={16} className="chev" aria-hidden="true" />
              </Link>
            );
          })}
        </div>
      </section>

      <LiveOperationsCockpit initial={overview} />

      <section aria-labelledby="base-title">
        <div className="section-head">
          <h2 id="base-title">Member base</h2>
          <p>From the 15-minute metrics snapshot</p>
        </div>
        <div className="stat-grid">
          <Stat label="Total members" value={metrics.totalUsers} icon={Users} href="/users" />
          <Stat label="Active in 7 days" value={metrics.activeSevenDays} icon={Users} />
          <Stat label="Active subscriptions" value={metrics.activeSubscriptions} icon={WalletCards} href="/subscriptions" />
        </div>
      </section>
    </div>
  );
}
