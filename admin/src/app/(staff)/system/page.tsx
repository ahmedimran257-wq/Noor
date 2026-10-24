import { Activity, Languages } from "lucide-react";
import { EmptyState, PageHeader, Stat, formatDateTime } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { getLocalizationOverview, getSystemHealth } from "@/lib/operations";

export const metadata = { title: "System health" };

type Metric = { key: string; label: string; hint?: string; bad?: (value: number) => boolean };

const groups: { title: string; metrics: Metric[] }[] = [
  {
    title: "Notifications",
    metrics: [
      { key: "dispatchHealthy", label: "Dispatcher", hint: "1 = healthy", bad: (v) => v !== 1 },
      { key: "dispatchConsecutiveFailures", label: "Dispatch failures in a row", bad: (v) => v > 0 },
      { key: "dueNotifications", label: "Due now" },
      { key: "staleNotifications", label: "Overdue", bad: (v) => v > 0 },
      { key: "futureNotifications", label: "Scheduled" },
      { key: "fcmTokenUsers", label: "Members with push enabled" },
    ],
  },
  {
    title: "Queues",
    metrics: [
      { key: "openReports", label: "Open reports" },
      { key: "pendingPhotos", label: "Photos to review" },
      { key: "queuedCampaigns", label: "Queued campaigns" },
      { key: "failedEmails24h", label: "Failed emails · 24 h", bad: (v) => v > 0 },
      { key: "rateLimitRejections1h", label: "Rate-limited requests · 1 h" },
      { key: "subscriptionEvents24h", label: "Billing events · 24 h" },
    ],
  },
  {
    title: "Platform",
    metrics: [
      { key: "databaseUsageMb", label: "Database size (MB)" },
      { key: "storageUsageMb", label: "Storage used (MB)" },
      { key: "publishedContentPages", label: "Published pages" },
      { key: "publishedSuccessStories", label: "Published stories" },
      { key: "activeStaff", label: "Active staff" },
    ],
  },
];

export default async function SystemPage() {
  await requireAdmin();
  const [health, locales] = await Promise.all([getSystemHealth(), getLocalizationOverview()]);
  const h = health ?? {};

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Governance"
        title="System health"
        lede="Operational counters from the 15-minute metrics snapshot. Anything that needs attention is highlighted."
      />
      {groups.map((group) => (
        <section key={group.title}>
          <div className="section-head"><h2>{group.title}</h2></div>
          <div className="stat-grid">
            {group.metrics.map((metric) => {
              const value = Number(h[metric.key] ?? 0);
              const bad = metric.bad?.(value) ?? false;
              return <Stat key={metric.key} label={metric.label} value={value} hint={metric.hint} tone={bad ? "alert" : undefined} icon={bad ? Activity : undefined} />;
            })}
          </div>
        </section>
      ))}

      <section className="card">
        <div className="card-head"><h2><Languages size={16} /> Content by language</h2></div>
        {locales.length === 0 ? (
          <EmptyState icon={Languages} title="No app content yet">Pages created under Content are counted here by language.</EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Language</th><th className="right">Pages</th><th className="right">Published</th><th>Last updated</th></tr></thead>
              <tbody>
                {locales.map((locale) => (
                  <tr key={locale.locale}>
                    <td className="mono">{locale.locale}</td>
                    <td className="right num">{Number(locale.page_count).toLocaleString("en-IN")}</td>
                    <td className="right num">{Number(locale.published_count).toLocaleString("en-IN")}</td>
                    <td>{formatDateTime(locale.last_updated)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
