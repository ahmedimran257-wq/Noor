import { Bell, FileClock, KeyRound, ShieldAlert, ShieldCheck } from "lucide-react";
import { NoAccess, PageHeader, Stat } from "@/components/ui";
import { requireArea } from "@/lib/auth";
import { getSecurityMetrics } from "@/lib/operations";

export const metadata = { title: "Security" };

export default async function SecurityPage() {
  const { allowed } = await requireArea("security");
  if (!allowed) return <NoAccess area="Security" />;
  const m = (await getSecurityMetrics()) ?? {};
  const failedRecent = Number(m.failedLogins15m ?? 0);

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Governance"
        title="Security"
        lede="Sign-in attempts to this console and the safeguards around staff access."
      />
      {failedRecent >= 5 ? (
        <div className="notice danger"><ShieldAlert size={16} /><span><strong>{failedRecent} failed sign-ins in the last 15 minutes.</strong> Login rate limits are active. Check the audit trail if this continues.</span></div>
      ) : null}
      <div className="stat-grid">
        <Stat label="Failed sign-ins · 15 min" value={m.failedLogins15m} icon={ShieldAlert} tone={failedRecent >= 5 ? "alert" : undefined} />
        <Stat label="Failed sign-ins · 24 h" value={m.failedLogins24h} icon={ShieldAlert} />
        <Stat label="Successful sign-ins · 24 h" value={m.successfulLogins24h} icon={KeyRound} />
        <Stat label="Unread alerts" value={m.unreadAdminNotifications} icon={Bell} href="/inbox" />
        <Stat label="Audit entries · 24 h" value={m.auditEvents24h} icon={FileClock} href="/audit" />
        <Stat label="Active super admins" value={m.activeSuperAdmins} icon={ShieldCheck} href="/staff" />
      </div>
      <section className="card card-pad">
        <div className="stack">
          <h2 className="display">How access is protected</h2>
          <ul className="muted stack">
            <li>Staff accounts are separate from member profiles and need an authenticator code before any data loads.</li>
            <li>Sessions end 12 hours after sign-in, enforced by the database on every request.</li>
            <li>Every privileged change and sensitive read is written to the audit trail.</li>
            <li>Member names and emails stay masked until a reveal with a stated reason.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
