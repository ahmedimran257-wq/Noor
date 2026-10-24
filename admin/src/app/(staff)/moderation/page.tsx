import { Camera, CircleCheck, Eye, Flag, MessageSquareWarning, SearchCheck } from "lucide-react";
import Link from "next/link";
import { Suspense } from "react";
import { SearchField, SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDateTime } from "@/components/ui";
import { formatCount } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import {
  getDiscoveryEligibility,
  getMessageReports,
  getPhotos,
  getReports,
  type PhotoRow,
} from "@/lib/operations";
import { resolveMessageReport, resolveReport, reviewPhoto } from "../actions";

export const metadata = { title: "Moderation" };

const tabs = ["reports", "messages", "photos", "discovery"] as const;
type Tab = (typeof tabs)[number];

function riskOf(photo: PhotoRow) {
  if (photo.nsfw_score === null) return { label: "No scan score", tone: "plain" };
  if (Number(photo.nsfw_score) > 0.85) return { label: "Explicit-content flag", tone: "danger" };
  return { label: "Routine review", tone: "info" };
}

export default async function ModerationPage({ searchParams }: { searchParams: Promise<{ tab?: string; q?: string }> }) {
  const { admin, allowed } = await requireArea("moderation");
  if (!allowed) return <NoAccess area="Moderation" />;
  const params = await searchParams;
  const c = admin.counts;
  const counts: Record<Tab, number | undefined> = {
    reports: c.openReports ?? 0,
    messages: c.messageReports ?? 0,
    photos: c.pendingPhotos ?? 0,
    discovery: undefined,
  };
  const requested = tabs.find((tab) => tab === params.tab);
  const tab: Tab = requested ?? (tabs.find((key) => (counts[key] ?? 0) > 0) ?? "reports");
  const returnTo = `/moderation?tab=${tab}${params.q ? `&q=${encodeURIComponent(params.q)}` : ""}`;
  const labels: Record<Tab, string> = {
    reports: "Member reports",
    messages: "Reported messages",
    photos: "Photo review",
    discovery: "Discovery check",
  };

  return (
    <div>
      <PageHeader
        eyebrow="Trust & safety"
        title="Moderation"
        lede="Oldest items first. Opening a decision claims it for 15 minutes so two moderators never act on the same report."
      />

      <nav className="tabs" aria-label="Moderation queues">
        {tabs.map((key) => (
          <Link key={key} href={`/moderation?tab=${key}`} prefetch={false} className={`tab${key === tab ? " is-active" : ""}`} aria-current={key === tab ? "page" : undefined}>
            {labels[key]}
            {counts[key] ? <span className="nav-count">{formatCount(counts[key]!)}</span> : null}
          </Link>
        ))}
      </nav>

      {tab === "reports" ? <ReportsQueue returnTo={returnTo} /> : null}
      {tab === "messages" ? <MessagesQueue returnTo={returnTo} /> : null}
      {tab === "photos" ? <PhotosQueue returnTo={returnTo} /> : null}
      {tab === "discovery" ? <DiscoveryCheck query={(params.q ?? "").slice(0, 120)} /> : null}
    </div>
  );
}

function Hidden({ returnTo, fields }: { returnTo: string; fields: Record<string, string> }) {
  return (
    <>
      <input type="hidden" name="returnTo" value={returnTo} />
      {Object.entries(fields).map(([name, value]) => <input key={name} type="hidden" name={name} value={value} />)}
    </>
  );
}

async function ReportsQueue({ returnTo }: { returnTo: string }) {
  const reports = await getReports();
  return (
    <section className="card">
      {reports.length === 0 ? (
        <EmptyState icon={Flag} title="No open reports">Reports members file about a profile appear here, oldest first.</EmptyState>
      ) : (
        <div className="list">
          {reports.map((report) => (
            <article className="list-item" key={report.report_id}>
              <div>
                <h3>{report.reported_name || "Reported member"} <StatusPill status="pending" label={report.reason.replaceAll("_", " ")} /></h3>
                {report.description ? <p className="quote">{report.description}</p> : <p className="muted">No details were given.</p>}
                <div className="meta">
                  <span>{formatDateTime(report.created_at)}</span>
                  <span>{report.report_count} open {report.report_count === 1 ? "report" : "reports"} on this member</span>
                  <span className="mono">{report.reported_user_id.slice(0, 8)}</span>
                </div>
              </div>
              <div className="aside">
                <form action={resolveReport}>
                  <Hidden returnTo={returnTo} fields={{ reportId: report.report_id, action: "dismissed" }} />
                  <SubmitButton className="btn btn-sm">Dismiss</SubmitButton>
                </form>
                <form action={resolveReport}>
                  <Hidden returnTo={returnTo} fields={{ reportId: report.report_id, action: "actioned" }} />
                  <SubmitButton className="btn btn-sm btn-danger" confirm="Suspend this member's profile?">Suspend profile</SubmitButton>
                </form>
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

async function MessagesQueue({ returnTo }: { returnTo: string }) {
  const reports = await getMessageReports();
  return (
    <section className="card">
      {reports.length === 0 ? (
        <EmptyState icon={MessageSquareWarning} title="No reported messages">When a member reports a chat message, it appears here with the message text.</EmptyState>
      ) : (
        <div className="list">
          {reports.map((report) => (
            <article className="list-item" key={report.report_id}>
              <div>
                <h3>{report.reported_name || "Reported sender"} <StatusPill status="pending" label={report.reason.replaceAll("_", " ")} /></h3>
                <blockquote className="quote">{report.message_content}</blockquote>
                {report.description ? <p>{report.description}</p> : null}
                <div className="meta">
                  <span>{formatDateTime(report.created_at)}</span>
                  <span className="mono">message {report.message_id.slice(0, 8)}</span>
                </div>
              </div>
              <div className="aside">
                <form action={resolveMessageReport}>
                  <Hidden returnTo={returnTo} fields={{ reportId: report.report_id, action: "dismissed" }} />
                  <SubmitButton className="btn btn-sm">Dismiss</SubmitButton>
                </form>
                <form action={resolveMessageReport}>
                  <Hidden returnTo={returnTo} fields={{ reportId: report.report_id, action: "actioned" }} />
                  <SubmitButton className="btn btn-sm btn-danger" confirm="Restrict this sender's messaging for 7 days?">Restrict 7 days</SubmitButton>
                </form>
              </div>
            </article>
          ))}
        </div>
      )}
    </section>
  );
}

async function PhotosQueue({ returnTo }: { returnTo: string }) {
  const photos = await getPhotos();
  if (photos.length === 0) {
    return (
      <section className="card">
        <EmptyState icon={Camera} title="No photos waiting">Every uploaded profile photo has been reviewed.</EmptyState>
      </section>
    );
  }
  const flagged = photos.filter((photo) => Number(photo.nsfw_score ?? 0) > 0.85).length;
  return (
    <div className="stack">
      <div className="notice info">
        <Eye size={16} />
        <span>
          <strong>{photos.length} oldest photos shown.</strong> {flagged > 0 ? `${flagged} carry an explicit-content flag and stay hidden from members until approved. ` : ""}
          Previews are private links that expire after five minutes; refresh if one stops loading.
        </span>
      </div>
      <div className="photo-grid">
        {photos.map((photo) => {
          const risk = riskOf(photo);
          return (
            <article className="card photo-card" key={photo.photo_id}>
              <div className="photo-frame">
                {photo.preview_url ? (
                  // eslint-disable-next-line @next/next/no-img-element -- short-lived signed URL; the optimiser would cache private images
                  <img src={photo.preview_url} alt={`Profile photo awaiting review for ${photo.name || "member"}`} loading="lazy" decoding="async" />
                ) : (
                  <div className="photo-missing"><Camera size={22} /><span>{photo.preview_error ?? "Preview unavailable"}</span></div>
                )}
                <span className={`pill ${risk.tone}`}>{risk.label}</span>
              </div>
              <div className="card-body">
                <div>
                  <span className="cell-main">{photo.name || "Member photo"}</span>
                  <span className="cell-sub">
                    {photo.nsfw_category ?? "Unclassified"} · score {photo.nsfw_score === null ? "—" : Number(photo.nsfw_score).toFixed(2)} · {formatDateTime(photo.created_at)}
                  </span>
                </div>
                <form action={reviewPhoto}>
                  <Hidden returnTo={returnTo} fields={{ photoId: photo.photo_id, decision: "approve" }} />
                  <SubmitButton className="btn btn-primary btn-sm">Approve</SubmitButton>
                </form>
                <details className="disclosure">
                  <summary className="btn btn-sm btn-danger">Reject…</summary>
                  <form action={reviewPhoto} className="popover-form">
                    <Hidden returnTo={returnTo} fields={{ photoId: photo.photo_id, decision: "reject" }} />
                    <label className="field">Reason shown to the member
                      <select name="reason" className="select" required defaultValue="">
                        <option value="" disabled>Choose a reason</option>
                        <option>Face is not clearly visible</option>
                        <option>Photo shows more than one person</option>
                        <option>Photo is not appropriate for a matrimony profile</option>
                        <option>Photo appears to be of someone else</option>
                        <option>Photo contains contact details or text</option>
                      </select>
                    </label>
                    <SubmitButton className="btn btn-sm btn-danger-solid">Confirm rejection</SubmitButton>
                  </form>
                </details>
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}

async function DiscoveryCheck({ query }: { query: string }) {
  const profiles = await getDiscoveryEligibility(query);
  return (
    <div className="stack">
      <div className="toolbar">
        <Suspense fallback={null}>
          <SearchField label="Find a profile" placeholder="Name, profile ID or member ID" resetParams={[]} />
        </Suspense>
        <span className="muted">Why a profile is or is not shown in Discover. 25 newest when no search is given.</span>
      </div>
      <section className="card">
        {profiles.length === 0 ? (
          <EmptyState icon={SearchCheck} title="No profiles found">Check the spelling, or paste a full profile or member ID.</EmptyState>
        ) : (
          <div className="list">
            {profiles.map((profile) => (
              <article className="list-item" key={profile.profile_id}>
                <div>
                  <h3>{profile.member_name || "Unnamed member"}</h3>
                  <div className="meta">
                    <span>{profile.gender}</span>
                    <span>{profile.approved_photo_count} approved {profile.approved_photo_count === 1 ? "photo" : "photos"}</span>
                    <span>joined {formatDateTime(profile.created_at)}</span>
                  </div>
                  {profile.exclusion_reasons.length > 0 ? (
                    <p className="muted">Hidden because: {profile.exclusion_reasons.map((reason) => reason.replaceAll("_", " ")).join(", ")}</p>
                  ) : (
                    <p className="row muted"><CircleCheck size={14} /> Shown in Discover</p>
                  )}
                  {profile.diagnostic_notes.length > 0 ? <p className="faint">{profile.diagnostic_notes.map((note) => note.replaceAll("_", " ")).join(", ")}</p> : null}
                </div>
                <div className="aside"><StatusPill status={profile.eligible ? "visible" : "hidden"} label={profile.eligible ? "Eligible" : "Hidden"} /></div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
