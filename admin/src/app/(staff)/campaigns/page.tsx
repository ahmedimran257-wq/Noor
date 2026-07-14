import { Megaphone } from "lucide-react";
import { createCampaign, queueCampaign } from "@/app/(staff)/actions";
import { getCampaigns } from "@/lib/operations";

const nowLocalValue = () => new Date(Date.now() + 5 * 60 * 1000).toISOString().slice(0, 16);

export default async function CampaignsPage() {
  const campaigns = await getCampaigns();

  return (
    <section className="dashboard-page">
      <p className="eyebrow">Push campaigns</p>
      <h1>Campaigns</h1>
      <p className="muted">Create targeted push campaigns and queue them through the existing notification dispatcher.</p>

      <form action={createCampaign} className="admin-form panel-form">
        <h2><Megaphone size={18} /> New campaign</h2>
        <div className="form-grid">
          <label>Title<input name="title" required minLength={3} maxLength={80} placeholder="Silarah reminder" /></label>
          <label>Audience
            <select name="audience" defaultValue="all">
              <option value="all">All visible users</option>
              <option value="active_7d">Active in last 7 days</option>
              <option value="subscribers">Subscribers</option>
              <option value="country">Country only</option>
            </select>
          </label>
          <label>Country code<input name="countryCode" maxLength={2} placeholder="IN" /></label>
          <label>Schedule<input name="scheduledAt" type="datetime-local" defaultValue={nowLocalValue()} /></label>
        </div>
        <label>Body<textarea name="body" required minLength={3} maxLength={220} rows={3} placeholder="Write a respectful, short notification." /></label>
        <label>Deep link<input name="deepLink" placeholder="silarah://profile or silarah://subscription" /></label>
        <button type="submit" className="primary-button">Create draft</button>
      </form>

      <h2 className="section-title">Recent campaigns</h2>
      <div className="table-wrap">
        <table>
          <thead><tr><th>Campaign</th><th>Audience</th><th>Schedule</th><th>Status</th><th>Queued</th><th>Action</th></tr></thead>
          <tbody>
            {campaigns.map((campaign) => (
              <tr key={campaign.campaign_id}>
                <td><strong>{campaign.title}</strong><small>{campaign.body}</small></td>
                <td>{campaign.audience}{campaign.country_code ? ` · ${campaign.country_code}` : ""}</td>
                <td>{new Date(campaign.scheduled_at).toLocaleString()}</td>
                <td>{campaign.status}</td>
                <td>{campaign.queued_count}</td>
                <td>
                  {campaign.status === "draft" ? (
                    <form action={queueCampaign}>
                      <input type="hidden" name="campaignId" value={campaign.campaign_id} />
                      <button className="inline-action" type="submit">Queue</button>
                    </form>
                  ) : <span className="muted">{campaign.queued_at ? new Date(campaign.queued_at).toLocaleDateString() : "Done"}</span>}
                </td>
              </tr>
            ))}
            {campaigns.length === 0 && <tr><td colSpan={6}>No campaigns yet.</td></tr>}
          </tbody>
        </table>
      </div>
    </section>
  );
}
