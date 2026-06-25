import { ShieldPlus } from "lucide-react";
import { inviteStaffMember, updateStaffMember } from "@/app/(staff)/actions";
import { getStaffMembers } from "@/lib/operations";

export default async function StaffPage() {
  const staff = await getStaffMembers();

  return (
    <section className="dashboard-page">
      <p className="eyebrow">Super admin</p>
      <h1>Staff access</h1>
      <p className="muted">Invite staff into Supabase Auth and grant the matching admin role. MFA remains required by default.</p>

      <form action={inviteStaffMember} className="admin-form panel-form elevated-panel">
        <h2><ShieldPlus size={18} /> Invite staff member</h2>
        <div className="form-grid">
          <label>Email<input name="email" type="email" required placeholder="admin@mithaq.app" /></label>
          <label>Role
            <select name="role" defaultValue="support">
              <option value="support">Support</option>
              <option value="moderator">Moderator</option>
              <option value="super_admin">Super admin</option>
            </select>
          </label>
        </div>
        <button type="submit" className="primary-button">Send invite and grant access</button>
      </form>

      <h2 className="section-title">Members</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Staff</th><th>Role</th><th>Status</th><th>MFA</th><th>Last sign in</th><th>Update</th></tr></thead>
          <tbody>
            {staff.map((member) => (
              <tr key={member.user_id}>
                <td><strong>{member.email}</strong><small>{member.user_id}</small></td>
                <td colSpan={5}>
                  <form action={updateStaffMember} className="row-form">
                    <input type="hidden" name="userId" value={member.user_id} />
                    <select name="role" defaultValue={member.role}>
                      <option value="support">Support</option>
                      <option value="moderator">Moderator</option>
                      <option value="super_admin">Super admin</option>
                    </select>
                    <select name="status" defaultValue={member.status}>
                      <option value="active">Active</option>
                      <option value="revoked">Revoked</option>
                    </select>
                    <label className="check-label"><input type="checkbox" name="mfaRequired" defaultChecked={member.mfa_required} /> MFA required</label>
                    <span className="muted">{member.last_sign_in_at ? new Date(member.last_sign_in_at).toLocaleString() : "Never"}</span>
                    <button className="inline-action" type="submit">Save</button>
                  </form>
                </td>
              </tr>
            ))}
            {staff.length === 0 && <tr><td colSpan={6}>No visible staff memberships.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
