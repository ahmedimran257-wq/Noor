import { ArrowLeft, BadgeCheck, Camera, Flag, ShieldAlert, UserRoundSearch } from "lucide-react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDate, formatDateTime, relativeTime } from "@/components/ui";
import { can } from "@/lib/access";
import { requireArea } from "@/lib/auth";
import { getMemberReview, type MemberReview, type MemberReviewPhoto } from "@/lib/operations";
import { accountAction, resolveReport } from "../../actions";

export const metadata = { title: "Member review" };

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function words(value: string | null | undefined) {
  return value ? value.replaceAll("_", " ") : null;
}

function photoState(photo: MemberReviewPhoto) {
  if (photo.status === "rejected") return { label: "Rejected", tone: "danger" };
  if (Number(photo.nsfwScore ?? 0) > 0.85 && !photo.adminApproved) return { label: "Explicit-content flag", tone: "danger" };
  if (photo.adminApproved && photo.nsfwCleared) return { label: "Approved", tone: "ok" };
  return { label: "Pending review", tone: "warn" };
}

function Fact({ label, value }: { label: string; value: React.ReactNode }) {
  if (value === null || value === undefined || value === "") return null;
  return <div><dt>{label}</dt><dd>{value}</dd></div>;
}

function about(review: MemberReview) {
  const yesNo = (value: boolean | null) => (value === null ? null : value ? "Yes" : "No");
  return [
    ["Profession", words(review.profession)],
    ["Work", words(review.employmentStatus)],
    ["Education", words(review.educationLevel)],
    ["Field of study", words(review.fieldOfStudy)],
    ["Sect", words(review.sect)],
    ["Practice", words(review.deenLevel)],
    ["Prays five times", yesNo(review.praysFiveDaily)],
    ["Height", review.heightCm ? `${review.heightCm} cm` : null],
    ["Mother tongue", words(review.motherTongue)],
    ["Languages", review.languages?.length ? review.languages.join(", ") : null],
    ["Previously married", words(review.previouslyMarried)],
    ["Children", review.childrenCount === null ? null : String(review.childrenCount)],
    ["Marriage timeline", words(review.marriageTimeline)],
    ["Profile created by", words(review.profileCreatedBy)],
    ["Guardian", words(review.guardianMode)],
  ] as const;
}

export default async function MemberReviewPage({
  params,
  searchParams,
}: {
  params: Promise<{ userId: string }>;
  searchParams: Promise<{ report?: string }>;
}) {
  const { admin, allowed } = await requireArea("memberReview");
  if (!allowed) return <NoAccess area="Member review" />;
  const { userId } = await params;
  const { report } = await searchParams;
  if (!uuid.test(userId)) notFound();
  const reportId = report && uuid.test(report) ? report : null;

  const review = await getMemberReview(userId, reportId);
  if (!review) {
    return (
      <div className="card">
        <EmptyState icon={UserRoundSearch} title="No profile for this member" action={<Link href="/moderation" prefetch={false} className="btn">Back to moderation</Link>}>
          The account may have been deleted, or it never finished creating a profile.
        </EmptyState>
      </div>
    );
  }

  const activeReport = reportId ? review.reportsAgainst.find((item) => item.id === reportId) ?? null : null;
  const returnTo = `/users/${review.userId}${reportId ? `?report=${reportId}` : ""}`;
  const status = review.isBanned ? "banned" : review.isShadowbanned ? "shadowbanned" : review.visibility;
  const restricted = review.visibility === "suspended" || review.isShadowbanned || review.isBanned;
  const canBan = can(admin.role, "banAccounts");
  const place = [review.city, review.region, review.countryCode].filter(Boolean).join(", ");
  const facts = about(review);

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Member review"
        title={review.displayName || "Unnamed member"}
        lede={[review.age ? `${review.age} years` : null, words(review.gender), place || null, `joined ${formatDate(review.joinedAt)}`, `active ${relativeTime(review.lastActiveAt)}`].filter(Boolean).join(" · ")}
        actions={
          <Link href={reportId ? "/moderation?tab=reports" : "/users"} prefetch={false} className="btn btn-ghost">
            <ArrowLeft size={15} /> {reportId ? "Back to reports" : "Back to members"}
          </Link>
        }
      />

      {activeReport ? (
        <section className="card">
          <div className="card-head">
            <h2><Flag size={16} /> Report you are checking</h2>
            <StatusPill status={activeReport.status} />
          </div>
          <div className="card-body stack">
            <div className="row">
              <StatusPill status="pending" label={activeReport.reason.replaceAll("_", " ")} />
              <span className="muted">filed {formatDateTime(activeReport.created_at)}</span>
              {activeReport.reporterTrust !== null ? <span className="muted">reporter trust {activeReport.reporterTrust}</span> : null}
            </div>
            {activeReport.description ? <p className="quote">{activeReport.description}</p> : <p className="muted">The reporter gave no details. Judge from the photos and profile below.</p>}
            {activeReport.status === "pending" ? (
              <div className="action-row">
                <form action={resolveReport}>
                  <input type="hidden" name="reportId" value={activeReport.id} />
                  <input type="hidden" name="action" value="dismissed" />
                  <input type="hidden" name="returnTo" value="/moderation?tab=reports" />
                  <SubmitButton className="btn">Dismiss report</SubmitButton>
                </form>
                <form action={resolveReport}>
                  <input type="hidden" name="reportId" value={activeReport.id} />
                  <input type="hidden" name="action" value="actioned" />
                  <input type="hidden" name="returnTo" value="/moderation?tab=reports" />
                  <SubmitButton className="btn btn-danger" confirm="Suspend this member's profile? It is hidden until restored.">Suspend profile</SubmitButton>
                </form>
              </div>
            ) : <p className="muted">This report has already been decided.</p>}
          </div>
        </section>
      ) : null}

      <div className="row">
        <StatusPill status={status} />
        {review.hasVerificationBadge ? <span className="pill ok"><BadgeCheck size={12} /> Photo verified</span> : <span className="pill plain">Not photo verified</span>}
        <StatusPill status={review.subscriptionStatus || "none"} label={!review.subscriptionStatus || review.subscriptionStatus === "none" ? "Free" : undefined} />
        <span className="pill plain">{review.completenessScore ?? 0}% complete</span>
        {review.approvedAt ? <span className="pill plain">approved {formatDate(review.approvedAt)}</span> : <span className="pill warn">Not approved for Discover</span>}
        {review.deletedAt ? <span className="pill danger">Account deleted {formatDate(review.deletedAt)}</span> : null}
        {review.suspendedReason ? <span className="pill danger">Suspended: {review.suspendedReason}</span> : null}
      </div>

      <div className="split">
        <section className="card">
          <div className="card-head">
            <h2><Camera size={16} /> Photos</h2>
            <span className="muted">{review.photos.length} uploaded · main photo first</span>
          </div>
          <div className="card-body stack">
            {review.previewError ? <p className="notice danger"><span>{review.previewError}</span></p> : null}
            {review.photos.length === 0 ? (
              <EmptyState icon={Camera} title="No photos uploaded">A profile without photos cannot appear in Discover.</EmptyState>
            ) : (
              <div className="photo-grid review-photos">
                {review.photos.map((photo, index) => {
                  const state = photoState(photo);
                  return (
                    <figure className="evidence" key={photo.id}>
                      {photo.previewUrl ? (
                        <a href={photo.previewUrl} target="_blank" rel="noreferrer" className="photo-frame" aria-label="Open photo at full size">
                          {/* eslint-disable-next-line @next/next/no-img-element -- private signed URL, never cached by the optimiser */}
                          <img src={photo.previewUrl} alt={`Photo ${index + 1} of ${review.displayName}`} loading="lazy" decoding="async" />
                          <span className={`pill ${state.tone}`}>{state.label}</span>
                        </a>
                      ) : (
                        <div className="photo-frame"><div className="photo-missing"><Camera size={20} /><span>Preview unavailable</span></div></div>
                      )}
                      <figcaption className="cell-sub">
                        {index === 0 ? "Main photo · " : ""}uploaded {formatDate(photo.createdAt)}
                        {photo.nsfwScore !== null ? ` · scan ${Number(photo.nsfwScore).toFixed(2)}` : ""}
                        {photo.moderationReason ? ` · ${photo.moderationReason}` : ""}
                      </figcaption>
                    </figure>
                  );
                })}
              </div>
            )}
          </div>
        </section>

        <div className="stack">
          <section className="card">
            <div className="card-head"><h2>About</h2></div>
            <div className="card-body stack">
              {review.bio ? <p className="quote">{review.bio}</p> : <p className="muted">No bio written.</p>}
              <dl className="kv">
                {facts.map(([label, value]) => <Fact key={label} label={label} value={value} />)}
              </dl>
              {review.interests?.length ? <p className="muted">Interests: {review.interests.join(", ")}</p> : null}
              <p className="faint">Name shown as members see it. Use Reveal identity in the member directory if you need the full name or email; that read is audited separately.</p>
            </div>
          </section>

          <section className="card">
            <div className="card-head">
              <h2><ShieldAlert size={16} /> Safety history</h2>
            </div>
            <div className="card-body stack">
              <dl className="kv">
                <Fact label="Reports against" value={`${review.reportCounts.total} (${review.reportCounts.pending} open)`} />
                <Fact label="Message reports" value={`${review.reportCounts.messageReports} (${review.reportCounts.messageReportsPending} open)`} />
                <Fact label="Reports they filed" value={String(review.reportCounts.filedByMember)} />
              </dl>
              {review.reportsAgainst.length > 0 ? (
                <div className="list">
                  {review.reportsAgainst.map((item) => (
                    <div className="list-item" key={item.id}>
                      <div>
                        <h3>{item.reason.replaceAll("_", " ")} <StatusPill status={item.status} /></h3>
                        {item.description ? <p className="muted">{item.description}</p> : null}
                        <div className="meta"><span>{formatDateTime(item.created_at)}</span>{item.id === reportId ? <span className="pill gold plain">this report</span> : null}</div>
                      </div>
                    </div>
                  ))}
                </div>
              ) : null}
            </div>
          </section>

          {can(admin.role, "moderateAccounts") && (!review.isBanned || canBan) ? (
            <section className="card">
              <div className="card-head"><h2>Account actions</h2></div>
              <div className="card-body stack">
                <form action={accountAction} className="action-row">
                  <input type="hidden" name="userId" value={review.userId} />
                  <input type="hidden" name="returnTo" value={returnTo} />
                  <input type="hidden" name="action" value={restricted ? "restore" : "suspend"} />
                  <SubmitButton className="btn" confirm={restricted ? undefined : "Suspend this member? Their profile is hidden until restored."}>
                    {review.isShadowbanned ? "Remove shadowban" : restricted ? "Restore account" : "Suspend account"}
                  </SubmitButton>
                </form>
                {canBan && !review.isBanned ? (
                  <form action={accountAction} className="stack">
                    <input type="hidden" name="userId" value={review.userId} />
                    <input type="hidden" name="returnTo" value={returnTo} />
                    <label className="field">Reason for the audit log
                      <input name="reason" className="input" minLength={6} required placeholder="e.g. Photos belong to another person" />
                    </label>
                    <div className="action-row">
                      {!review.isShadowbanned ? <SubmitButton className="btn" name="action" value="shadowban">Shadowban</SubmitButton> : null}
                      <SubmitButton className="btn btn-danger" name="action" value="ban" confirm="Ban this member permanently?">Ban</SubmitButton>
                    </div>
                  </form>
                ) : null}
                <p className="faint">Masked email {review.email ?? "—"} · member ID <span className="mono">{review.userId}</span></p>
              </div>
            </section>
          ) : null}
        </div>
      </div>
    </div>
  );
}
