import { Activity, Languages } from "lucide-react";
import { getLocalizationOverview, getSystemHealth } from "@/lib/operations";

const healthLabels: Record<string, string> = {
  dueNotifications: "Due notifications",
  staleNotifications: "Stale notifications",
  futureNotifications: "Future notifications",
  fcmTokenUsers: "Users with FCM tokens",
  pendingKyc: "Pending KYC",
  pendingPhotos: "Pending photos",
  openReports: "Open reports",
  queuedCampaigns: "Queued campaigns",
  publishedContentPages: "Published CMS pages",
  publishedSuccessStories: "Published stories",
  subscriptionEvents24h: "Subscription events 24h",
  failedEmails24h: "Failed emails 24h",
  rateLimitRejections1h: "Blocked requests 1h",
  databaseUsageMb: "Database usage (MB)",
  storageUsageMb: "Storage usage (MB)",
  dispatchConsecutiveFailures: "Dispatch failures",
  dispatchHealthy: "Dispatch healthy (1/0)",
  activeStaff: "Active staff",
};

export default async function SystemPage() {
  const [health, locales] = await Promise.all([getSystemHealth(), getLocalizationOverview()]);

  return (
    <section className="dashboard-page">
      <p className="eyebrow">Operations</p>
      <h1>System health</h1>
      <p className="muted">Database-backed operational counters for queues, moderation load, push readiness, staff access, and localized CMS content.</p>

      <h2 className="section-title"><Activity size={18} /> Health counters</h2>
      <div className="metric-grid">
        {Object.entries(healthLabels).map(([key, label]) => (
          <div className="metric-card" key={key}>
            <span>{label}</span>
            <strong>{Number(health[key] ?? 0).toLocaleString()}</strong>
          </div>
        ))}
      </div>

      <h2 className="section-title"><Languages size={18} /> Localization coverage</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Locale</th><th>Pages</th><th>Published</th><th>Last updated</th></tr></thead>
          <tbody>
            {locales.map((locale) => (
              <tr key={locale.locale}>
                <td>{locale.locale}</td>
                <td>{Number(locale.page_count).toLocaleString()}</td>
                <td>{Number(locale.published_count).toLocaleString()}</td>
                <td>{locale.last_updated ? new Date(locale.last_updated).toLocaleString() : "Never"}</td>
              </tr>
            ))}
            {locales.length === 0 && <tr><td colSpan={4}>No CMS localization records yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
