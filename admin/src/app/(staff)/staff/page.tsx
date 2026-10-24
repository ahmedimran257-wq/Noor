import { ShieldPlus } from "lucide-react";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, relativeTime } from "@/components/ui";
import { roleLabels, type AdminRole } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getStaffMembers } from "@/lib/operations";
import { inviteStaffMember, updateStaffMember } from "../actions";

export const metadata = { title: "Staff access" };

const roles: AdminRole[] = ["support", "moderator", "super_admin"];
const roleHelp: Record<AdminRole, string> = {
  support: "Member rights, content, stories and campaigns",
  moderator: "Photo checks, reports, member actions and reveals",
  super_admin: "Everything, including bans, staff and security",
};

export default async function StaffPage() {
  const { admin, allowed } = await requireArea("staff");
  if (!allowed) return <NoAccess area="Staff access" />;
  const staff = await getStaffMembers();

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Governance"
        title="Staff access"
        lede="Invite people by email and give them the smallest role that covers their work. Every staff account must use an authenticator app."
      />

      <div className="split">
        <section className="card">
          <div className="card-head"><h2>Team</h2><span className="muted">{staff.length} {staff.length === 1 ? "account" : "accounts"}</span></div>
          {staff.length === 0 ? (
            <EmptyState icon={ShieldPlus} title="No staff memberships">Invite your first teammate with the form.</EmptyState>
          ) : (
            <div className="list">
              {staff.map((member) => {
                const self = member.user_id === admin.id;
                return (
                  <form action={updateStaffMember} className="list-item" key={member.user_id}>
                    <input type="hidden" name="userId" value={member.user_id} />
                    <input type="hidden" name="returnTo" value="/staff" />
                    <div>
                      <h3>{member.email} {self ? <span className="pill gold plain">You</span> : null} <StatusPill status={member.status} /></h3>
                      <div className="meta">
                        <span>last sign-in {relativeTime(member.last_sign_in_at)}</span>
                        <span className="mono">{member.user_id.slice(0, 8)}</span>
                      </div>
                    </div>
                    <div className="aside">
                      <label className="sr-only" htmlFor={`role-${member.user_id}`}>Role</label>
                      <select id={`role-${member.user_id}`} name="role" defaultValue={member.role} className="select btn-sm" disabled={self}>
                        {roles.map((role) => <option key={role} value={role}>{roleLabels[role]}</option>)}
                      </select>
                      <label className="sr-only" htmlFor={`status-${member.user_id}`}>Status</label>
                      <select id={`status-${member.user_id}`} name="status" defaultValue={member.status} className="select btn-sm" disabled={self}>
                        <option value="active">Active</option>
                        <option value="revoked">Revoked</option>
                      </select>
                      {self ? (
                        <>
                          <input type="hidden" name="role" value={member.role} />
                          <input type="hidden" name="status" value={member.status} />
                        </>
                      ) : null}
                      <label className="check-row"><input type="checkbox" name="mfaRequired" defaultChecked={member.mfa_required} /> MFA</label>
                      <SubmitButton className="btn btn-sm">Save</SubmitButton>
                    </div>
                  </form>
                );
              })}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head"><h2><ShieldPlus size={16} /> Invite</h2></div>
          <form action={inviteStaffMember} className="card-body stack">
            <input type="hidden" name="returnTo" value="/staff" />
            <label className="field">Work email<input name="email" type="email" className="input" required placeholder="name@silarah.com" autoComplete="off" /></label>
            <fieldset className="stack">
              <legend className="field">Role</legend>
              {roles.map((role) => (
                <label key={role} className="check-row">
                  <input type="radio" name="role" value={role} defaultChecked={role === "support"} />
                  <span><strong>{roleLabels[role]}</strong><br /><span className="muted">{roleHelp[role]}</span></span>
                </label>
              ))}
            </fieldset>
            <div className="form-actions"><SubmitButton className="btn btn-primary">Send invite</SubmitButton></div>
          </form>
        </section>
      </div>
    </div>
  );
}
