import { Heart, MessageCircle, Sparkles, Users } from "lucide-react";
import { EmptyState, PageHeader, Stat, formatDate, relativeTime } from "@/components/ui";
import { requireAdmin } from "@/lib/auth";
import { getMatchMetrics, getMatches } from "@/lib/operations";

export const metadata = { title: "Matches" };

export default async function MatchesPage() {
  await requireAdmin();
  const [metrics, matches] = await Promise.all([getMatchMetrics(), getMatches()]);
  const m = metrics ?? {};
  const acceptance = m.interestsThirtyDays ? Math.round((Number(m.acceptedThirtyDays ?? 0) / Number(m.interestsThirtyDays)) * 100) : null;

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Members"
        title="Matches & interests"
        lede="How well introductions are turning into conversations. Names are masked; open a member from the directory if you need more."
      />
      <div className="stat-grid">
        <Stat label="Active matches" value={m.activeMatches} icon={Heart} />
        <Stat label="Interests · 30 days" value={m.interestsThirtyDays} icon={Sparkles} />
        <Stat label="Accepted · 30 days" value={m.acceptedThirtyDays} hint={acceptance === null ? undefined : `${acceptance}% acceptance`} icon={Sparkles} />
        <Stat label="Messages · 30 days" value={m.messagesThirtyDays} icon={MessageCircle} />
        <Stat label="In Discover now" value={m.discoveryProfiles} icon={Users} />
      </div>

      <section className="card">
        <div className="card-head">
          <h2><Heart size={16} /> Newest active matches</h2>
          <span className="muted">Up to 100</span>
        </div>
        {matches.length === 0 ? (
          <EmptyState icon={Heart} title="No active matches yet">When two members accept each other, the match appears here.</EmptyState>
        ) : (
          <div className="table-wrap">
            <table className="table">
              <thead><tr><th>Couple</th><th>Matched</th><th className="right">Messages</th><th>Last message</th></tr></thead>
              <tbody>
                {matches.map((match) => (
                  <tr key={match.match_id}>
                    <td><span className="cell-main">{match.user_a_name} &amp; {match.user_b_name}</span></td>
                    <td className="num">{formatDate(match.created_at)}</td>
                    <td className="right num">{Number(match.message_count).toLocaleString("en-IN")}</td>
                    <td className="muted">{match.last_message_at ? relativeTime(match.last_message_at) : "No messages yet"}</td>
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
