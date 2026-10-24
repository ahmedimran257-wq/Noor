import { Megaphone, Send } from "lucide-react";
import { LocalDateTimeInput, SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDateTime } from "@/components/ui";
import { requireArea } from "@/lib/auth";
import { getCampaigns } from "@/lib/operations";
import { createCampaign, queueCampaign } from "../actions";

export const metadata = { title: "Campaigns" };

const audiences: Record<string, string> = {
  all: "All visible members",
  active_7d: "Active in the last 7 days",
  subscribers: "Premium subscribers",
  country: "One country",
};

export default async function CampaignsPage() {
  const { allowed } = await requireArea("campaigns");
  if (!allowed) return <NoAccess area="Campaigns" />;
  const campaigns = await getCampaigns();

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Publishing"
        title="Push campaigns"
        lede="Write a draft, check it, then queue it. Queuing creates one notification per eligible member, delivered by the notification dispatcher at the scheduled time."
      />

      <div className="split">
        <section className="card">
          <div className="card-head"><h2><Megaphone size={16} /> Recent campaigns</h2></div>
          {campaigns.length === 0 ? (
            <EmptyState icon={Megaphone} title="No campaigns yet">Your first draft will appear here. Nothing is sent until you queue it.</EmptyState>
          ) : (
            <div className="list">
              {campaigns.map((campaign) => (
                <article className="list-item" key={campaign.campaign_id}>
                  <div>
                    <h3>{campaign.title} <StatusPill status={campaign.status} /></h3>
                    <p>{campaign.body}</p>
                    <div className="meta">
                      <span>{audiences[campaign.audience] ?? campaign.audience}{campaign.country_code ? ` · ${campaign.country_code}` : ""}</span>
                      <span>for {formatDateTime(campaign.scheduled_at)}</span>
                      {campaign.queued_count > 0 ? <span>{campaign.queued_count.toLocaleString("en-IN")} queued</span> : null}
                      {campaign.deep_link ? <span className="mono">{campaign.deep_link}</span> : null}
                    </div>
                  </div>
                  <div className="aside">
                    {campaign.status === "draft" ? (
                      <form action={queueCampaign}>
                        <input type="hidden" name="campaignId" value={campaign.campaign_id} />
                        <input type="hidden" name="returnTo" value="/campaigns" />
                        <SubmitButton className="btn btn-primary btn-sm" confirm={`Queue "${campaign.title}" for ${audiences[campaign.audience] ?? campaign.audience}? This cannot be undone.`}>
                          <Send size={14} /> Queue
                        </SubmitButton>
                      </form>
                    ) : <span className="faint">{campaign.queued_at ? `Queued ${formatDateTime(campaign.queued_at)}` : "Done"}</span>}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head"><h2>New draft</h2></div>
          <form action={createCampaign} className="card-body stack">
            <input type="hidden" name="returnTo" value="/campaigns" />
            <label className="field">Title<input name="title" className="input" required minLength={3} maxLength={80} placeholder="A gentle reminder" /></label>
            <label className="field">Message<textarea name="body" className="textarea" required minLength={3} maxLength={220} rows={3} placeholder="Short, warm and respectful. 220 characters at most." /></label>
            <div className="form-grid">
              <label className="field">Audience
                <select name="audience" className="select" defaultValue="all">
                  {Object.entries(audiences).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
                </select>
              </label>
              <label className="field">Country code<input name="countryCode" className="input" maxLength={2} placeholder="IN" pattern="[A-Za-z]{2}" /><small>Only for one-country campaigns</small></label>
            </div>
            <LocalDateTimeInput name="scheduledAt" label="Send at" />
            <label className="field">Open in app<input name="deepLink" className="input" placeholder="silarah://subscription" pattern="silarah://.*" /><small>Optional. Leave blank to open the home screen.</small></label>
            <div className="form-actions"><SubmitButton className="btn btn-primary">Save draft</SubmitButton></div>
          </form>
        </section>
      </div>
    </div>
  );
}
