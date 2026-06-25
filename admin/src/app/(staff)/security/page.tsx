import { KeyRound, ShieldAlert, ShieldCheck } from "lucide-react";
import { getSecurityMetrics } from "@/lib/operations";

const securityCards = [
  ["Failed logins 15m", "failedLogins15m", ShieldAlert],
  ["Failed logins 24h", "failedLogins24h", ShieldAlert],
  ["Successful logins 24h", "successfulLogins24h", KeyRound],
  ["Unread admin alerts", "unreadAdminNotifications", ShieldAlert],
  ["Audit events 24h", "auditEvents24h", ShieldCheck],
  ["Active super admins", "activeSuperAdmins", ShieldCheck],
] as const;

export default async function SecurityPage() {
  const metrics = (await getSecurityMetrics()) ?? {};

  return (
    <section className="dashboard-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Security center</p>
          <h1>Access posture</h1>
          <p className="muted">Real-time security indicators from admin login attempts, audit events, staff memberships, and internal alerts.</p>
        </div>
        <div className="hero-badge"><ShieldCheck size={18} /> MFA gated</div>
      </div>

      <div className="metric-grid">
        {securityCards.map(([label, key, Icon]) => (
          <article className="metric-card elevated-panel" key={key}>
            <Icon size={19} />
            <span>{label}</span>
            <strong>{Number(metrics[key] ?? 0).toLocaleString()}</strong>
          </article>
        ))}
      </div>

      <div className="foundation-card">
        <ShieldCheck size={24} />
        <p>Staff access is separated from public matrimony profiles, MFA is enforced before the dashboard, and privileged changes are written to the audit log.</p>
      </div>
    </section>
  );
}
