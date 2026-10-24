import { RotateCcw, WalletCards } from "lucide-react";
import { EmptyState, PageHeader, Stat, StatusPill, formatDate } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { getSubscribers, getSubscriptionSummary } from "@/lib/operations";

export const metadata = { title: "Subscriptions" };

function money(amount: number, currency: string) {
  if (!/^[A-Z]{3}$/.test(currency)) return `${Number(amount).toLocaleString("en-IN")} ${currency}`;
  return Number(amount).toLocaleString("en-IN", { style: "currency", currency, maximumFractionDigits: 0 });
}

function planName(productId: string | null) {
  if (!productId) return "Unknown plan";
  const id = productId.toLowerCase();
  if (id.includes("three_month") || id.includes("3_month") || id.includes("quarter")) return "Premium · 3 months";
  if (id.includes("annual") || id.includes("year")) return "Premium · 12 months";
  if (id.includes("month")) return "Premium · monthly";
  return productId;
}

export default async function SubscriptionsPage() {
  await requireAdmin();
  const [summary, subscribers] = await Promise.all([getSubscriptionSummary(), getSubscribers()]);
  const total = summary.active + summary.grace;

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Members"
        title="Subscriptions"
        lede="Counts cover every member. Revenue is gross purchases and renewals recorded from RevenueCat, kept per currency and before store fees or refunds."
      />
      <div className="stat-grid">
        <Stat label="Active subscribers" value={summary.active} icon={WalletCards} />
        <Stat label="In billing grace" value={summary.grace} hint="Payment retrying" tone={summary.grace > 0 ? "alert" : undefined} />
        <Stat label="Refund events" value={summary.refunds} icon={RotateCcw} />
        {summary.revenue.length === 0 ? (
          <Stat label="Gross revenue" value="—" hint="No purchases recorded yet" />
        ) : summary.revenue.map((row) => (
          <Stat key={row.currency} label={`Gross revenue · ${row.currency}`} value={money(row.gross, row.currency)} />
        ))}
      </div>

      <section className="card">
        <div className="card-head">
          <h2><WalletCards size={16} /> Current subscribers</h2>
          <span className="muted">{subscribers.length < total ? `First ${subscribers.length} of ${total.toLocaleString("en-IN")}, soonest renewal first` : "Soonest renewal first"}</span>
        </div>
        {subscribers.length === 0 ? (
          <EmptyState icon={WalletCards} title="No active subscribers">Members who buy Premium appear here with their renewal date.</EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Member</th><th>Plan</th><th>Status</th><th>Renews or ends</th><th className="right">Paid to date</th></tr></thead>
              <tbody>
                {subscribers.map((item) => (
                  <tr key={item.user_id}>
                    <td><span className="cell-main">{item.name || "Unnamed"}</span><span className="cell-sub">{item.country_code || "—"}</span></td>
                    <td>{planName(item.product_id)}</td>
                    <td><StatusPill status={item.subscription_status} /></td>
                    <td className="num">{formatDate(item.subscription_expires_at)}</td>
                    <td className="right num">{Number(item.total_paid ?? 0).toLocaleString("en-IN", { maximumFractionDigits: 2 })}</td>
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
