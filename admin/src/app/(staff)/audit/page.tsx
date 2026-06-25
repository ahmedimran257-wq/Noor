import { FileClock } from "lucide-react";
import { getAuditFeed } from "@/lib/operations";

function compactJson(value: Record<string, unknown> | null) {
  if (!value) return "No details";
  return JSON.stringify(value);
}

export default async function AuditPage() {
  const events = await getAuditFeed();

  return (
    <section className="dashboard-page wide-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Governance</p>
          <h1>Audit log</h1>
          <p className="muted">Immutable staff activity trail for moderation, staff, content, campaign, and security-sensitive actions.</p>
        </div>
        <div className="hero-badge"><FileClock size={18} /> {events.length} latest</div>
      </div>

      <div className="table-wrap elevated-panel">
        <table>
          <thead><tr><th>Time</th><th>Actor</th><th>Role</th><th>Action</th><th>Target</th><th>Details</th></tr></thead>
          <tbody>
            {events.map((event) => (
              <tr key={event.audit_id}>
                <td>{new Date(event.created_at).toLocaleString()}</td>
                <td><strong>{event.admin_email ?? "System"}</strong><small>{event.admin_id}</small></td>
                <td>{event.actor_role ?? "unknown"}</td>
                <td><span className="status-pill">{event.action_type}</span></td>
                <td>{event.target_user_id ?? "N/A"}</td>
                <td><code className="json-chip">{compactJson(event.details)}</code></td>
              </tr>
            ))}
            {events.length === 0 && <tr><td colSpan={6}>No audit events yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
