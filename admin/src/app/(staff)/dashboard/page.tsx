import { Activity, BadgeCheck, Flag, MessageCircle, TrendingUp, Users } from "lucide-react";
import { LiveOperationsCockpit } from "@/components/live-operations-cockpit";
import { requireAdmin } from "@/lib/auth";
import { getDashboardMetrics, getLiveOperationsSnapshot } from "@/lib/operations";

export default async function DashboardPage() {
  const admin = await requireAdmin();
  const [metrics, live] = await Promise.all([getDashboardMetrics(), getLiveOperationsSnapshot()]);
  const cards = [
    ["Total profiles", metrics.totalUsers, Users], ["New today", metrics.signupsToday, Activity],
    ["Pending KYC", metrics.pendingKyc, BadgeCheck], ["Open reports", metrics.openReports, Flag],
    ["Active subscriptions", metrics.activeSubscriptions, BadgeCheck], ["Messages today", metrics.messagesToday, MessageCircle],
  ] as const;
  return (
    <section className="dashboard-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Operations dashboard</p>
          <h1>Assalamu alaikum, {admin.email.split("@")[0]}</h1>
          <p className="muted">Live Mithaq operations overview across trust, safety, growth, and subscriptions.</p>
        </div>
        <div className="hero-badge"><TrendingUp size={18} /> Live data</div>
      </div>
      <LiveOperationsCockpit initial={live} />
      <div className="metric-grid">
        {cards.map(([label, value, Icon]) => (
          <article key={label} className="metric-card elevated-panel">
            <Icon size={19} />
            <span>{label}</span>
            <strong>{Number(value ?? 0).toLocaleString()}</strong>
          </article>
        ))}
      </div>
    </section>
  );
}
