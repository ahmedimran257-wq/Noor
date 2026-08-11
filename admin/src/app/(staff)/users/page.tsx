import { Search } from "lucide-react";
import { requireAdmin } from "@/lib/auth";
import { getRevealedUserPii, getUsers } from "@/lib/operations";
import { accountAction, bulkAccountAction } from "../actions";

function buildPageHref(query: string, page: number) {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (page > 1) params.set("page", String(page));
  return `/users${params.size ? `?${params.toString()}` : ""}`;
}

function buildRevealHref(query: string, page: number, userId: string) {
  const params = new URLSearchParams();
  if (query) params.set("q", query);
  if (page > 1) params.set("page", String(page));
  params.set("reveal", userId);
  return `/users?${params.toString()}`;
}

function safePage(value?: string) {
  const parsed = Number(value ?? "1");
  return Number.isFinite(parsed) ? Math.max(1, Math.floor(parsed)) : 1;
}

export default async function UsersPage({ searchParams }: { searchParams: Promise<{ q?: string; page?: string; reveal?: string }> }) {
  const admin = await requireAdmin();
  const params = await searchParams;
  const query = params.q ?? "";
  const page = safePage(params.page);
  const userPage = await getUsers(query, page);
  const canModerate = admin.role === "super_admin" || admin.role === "moderator";
  const canReveal = canModerate;
  const revealed = params.reveal && canReveal
    ? await getRevealedUserPii(params.reveal, "Viewed from admin user directory")
    : null;

  return (
    <section className="dashboard-page wide-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">User management</p>
          <h1>Members</h1>
          <p className="muted">Search accounts, review trust state, and apply safety actions. PII is masked until an audited reveal is required.</p>
        </div>
        <div className="hero-badge">{userPage.total.toLocaleString()} matched</div>
      </div>

      <form className="search-form elevated-panel">
        <Search size={18} />
        <input name="q" defaultValue={query} placeholder="Search name, email, or user ID" />
        <button className="primary-button">Search</button>
      </form>

      {canModerate ? (
        <form id="bulk-user-action" action={bulkAccountAction} className="bulk-toolbar elevated-panel">
          <div>
            <strong>Bulk safety action</strong>
            <small>Select up to 50 visible rows. Bulk actions require an audited reason.</small>
          </div>
          <select name="action" defaultValue="suspend" aria-label="Bulk action">
            <option value="suspend">Suspend selected</option>
            <option value="restore">Restore selected</option>
            {admin.role === "super_admin" ? <option value="shadowban">Shadowban selected</option> : null}
            {admin.role === "super_admin" ? <option value="ban">Ban selected</option> : null}
          </select>
          <input name="reason" placeholder="Required reason" minLength={6} required />
          <button>Apply</button>
        </form>
      ) : null}

      {revealed ? (
        <div className="pii-reveal-panel elevated-panel">
          <div>
            <strong>PII reveal active</strong>
            <small>
              Showing unmasked details for {revealed.name || revealed.user_id}. This read was written to the audit log.
            </small>
          </div>
          <a href={buildPageHref(query, page)}>Hide revealed PII</a>
        </div>
      ) : null}

      <div className="table-wrap elevated-panel">
        <table>
          <thead>
            <tr>{canModerate ? <th>Select</th> : null}<th>Name</th><th>Country</th><th>Joined</th><th>Photo trust</th><th>Plan</th><th>Status</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {userPage.rows.map((user) => {
              const isRevealed = revealed?.user_id === user.user_id;
              const displayName = isRevealed ? revealed.name : user.name;
              const displayEmail = isRevealed ? revealed.email : user.email;
              const needsRestore = user.visibility === "suspended" || user.is_shadowbanned || user.is_banned;
              const canRestore = !user.is_banned || admin.role === "super_admin";
              const statusLabel = user.is_banned
                ? "Banned"
                : user.is_shadowbanned
                  ? "Shadowbanned"
                  : user.visibility;
              const photoTrust = user.has_verification_badge
                ? { label: "Photo verified", tone: "success" }
                : { label: "Not verified", tone: "neutral" };
              return (
              <tr key={user.user_id} className={isRevealed ? "revealed-row" : undefined}>
                {canModerate ? (
                  <td><input form="bulk-user-action" type="checkbox" name="userIds" value={user.user_id} aria-label={`Select ${displayName || user.user_id}`} /></td>
                ) : null}
                <td>
                  <strong>{displayName || "Unnamed"}</strong>
                  <small>{displayEmail ?? user.user_id}</small>
                  {isRevealed ? <span className="pii-reveal-badge">PII reveal audited</span> : null}
                </td>
                <td>{user.country_code || "N/A"}</td>
                <td>{new Date(user.joined_at).toLocaleDateString()}</td>
                <td>
                  <span
                    className={`status-pill ${photoTrust.tone}`}
                  >
                    {photoTrust.label}
                  </span>
                </td>
                <td>{user.subscription_status}</td>
                <td><span className={user.is_banned ? "status-pill danger" : user.is_shadowbanned ? "status-pill warning" : "status-pill"}>{statusLabel}</span></td>
                <td>
                  <div className="action-row">
                    {canReveal ? (
                      <a className="inline-action" href={buildRevealHref(query, userPage.page, user.user_id)}>
                        {isRevealed ? "PII revealed" : "Reveal PII"}
                      </a>
                    ) : null}
                    {canModerate && canRestore ? (
                      <form action={accountAction}>
                        <input type="hidden" name="userId" value={user.user_id} />
                        <input type="hidden" name="action" value={needsRestore ? "restore" : "suspend"} />
                        <button>{user.is_shadowbanned ? "Remove shadowban" : needsRestore ? "Restore" : "Suspend"}</button>
                      </form>
                    ) : null}
                    {admin.role === "super_admin" && !user.is_banned ? (
                      <>
                        {!user.is_shadowbanned ? (
                          <form action={accountAction}>
                            <input type="hidden" name="userId" value={user.user_id} />
                            <input type="hidden" name="action" value="shadowban" />
                            <button>Shadowban</button>
                          </form>
                        ) : null}
                        <form action={accountAction}>
                          <input type="hidden" name="userId" value={user.user_id} />
                          <input type="hidden" name="action" value="ban" />
                          <button className="danger">Ban</button>
                        </form>
                      </>
                    ) : null}
                  </div>
                </td>
              </tr>
            );})}
            {userPage.rows.length === 0 && <tr><td colSpan={canModerate ? 8 : 7}>No users found.</td></tr>}
          </tbody>
        </table>
      </div>

      <nav className="pagination-row" aria-label="User directory pagination">
        <a className={!userPage.hasPreviousPage ? "disabled-link" : ""} href={buildPageHref(query, userPage.page - 1)}>Previous</a>
        <span>Page {userPage.page} · Showing {userPage.rows.length} of {userPage.total.toLocaleString()}</span>
        <a className={!userPage.hasNextPage ? "disabled-link" : ""} href={buildPageHref(query, userPage.page + 1)}>Next</a>
      </nav>
    </section>
  );
}
