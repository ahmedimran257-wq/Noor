import { requireAdmin } from "@/lib/auth";
import { getMatches, getMatchMetrics } from "@/lib/operations";

export default async function MatchesPage() {
  await requireAdmin(); const [metrics, matches] = await Promise.all([getMatchMetrics(), getMatches()]);
  const cards = [["Active matches", metrics.activeMatches], ["Interests (30d)", metrics.interestsThirtyDays], ["Accepted (30d)", metrics.acceptedThirtyDays], ["Messages (30d)", metrics.messagesThirtyDays], ["Discovery pool", metrics.discoveryProfiles]];
  return <section className="dashboard-page"><p className="eyebrow">Core matching health</p><h1>Matches & interests</h1><div className="metric-grid">{cards.map(([label,value]) => <article className="metric-card" key={label}><span>{label}</span><strong>{Number(value ?? 0).toLocaleString()}</strong></article>)}</div><h2 className="section-title">Active matches</h2><div className="table-wrap"><table><thead><tr><th>Match</th><th>Created</th><th>Messages</th><th>Last message</th></tr></thead><tbody>{matches.map((match) => <tr key={match.match_id}><td>{match.user_a_name} · {match.user_b_name}</td><td>{new Date(match.created_at).toLocaleDateString()}</td><td>{match.message_count}</td><td>{match.last_message_at ? new Date(match.last_message_at).toLocaleDateString() : "No messages"}</td></tr>)}</tbody></table></div></section>;
}
