import { ScanFace, ShieldCheck, TriangleAlert } from "lucide-react";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, formatDateTime, relativeTime } from "@/components/ui";
import { requireArea } from "@/lib/auth";
import { getPhotoVerificationQueue, type PhotoVerificationRow } from "@/lib/operations";
import { reviewPhotoVerification } from "../actions";

export const metadata = { title: "Photo checks" };

const checks = [
  ["clearCapture", "All guided captures are clear enough to compare"],
  ["samePerson", "The same person appears in the neutral, smile and blink captures"],
  ["currentPhotoMatch", "That person reasonably matches the current main profile photo"],
] as const;

function Evidence({ title, url, alt }: { title: string; url?: string | null; alt: string }) {
  return (
    <figure className="evidence">
      <h4>{title}</h4>
      {url ? (
        <a href={url} target="_blank" rel="noreferrer" className="photo-frame" aria-label={`Open ${title} at full size`}>
          {/* eslint-disable-next-line @next/next/no-img-element -- private signed URL, never cached by the optimiser */}
          <img src={url} alt={alt} loading="lazy" decoding="async" />
        </a>
      ) : (
        <div className="photo-frame"><div className="photo-missing"><TriangleAlert size={20} /><span>Preview unavailable. Do not decide yet.</span></div></div>
      )}
    </figure>
  );
}

function Fields({ item, decision }: { item: PhotoVerificationRow; decision: "approve" | "reject" | "resubmit" }) {
  return (
    <>
      <input type="hidden" name="submissionId" value={item.submission_id} />
      <input type="hidden" name="decision" value={decision} />
      <input type="hidden" name="returnTo" value="/photo-verification" />
    </>
  );
}

export default async function PhotoVerificationPage() {
  const { allowed } = await requireArea("photoChecks");
  if (!allowed) return <NoAccess area="Photo checks" />;
  const queue = await getPhotoVerificationQueue();

  return (
    <div>
      <PageHeader
        eyebrow="Trust & safety"
        title="Photo checks"
        lede="Compare the temporary guided captures with the member's current main photo. This is a likeness check, not government ID verification."
        actions={<span className="pill gold plain">{queue.length} waiting</span>}
      />

      <div className="stack">
        <div className="notice">
          <ShieldCheck size={16} />
          <span>
            <strong>A person decides every check.</strong> Approve only when all three statements are true. Any decision starts deleting the captures right away, and nothing is kept past the 48-hour deadline.
          </span>
        </div>

        {queue.length === 0 ? (
          <section className="card">
            <EmptyState icon={ScanFace} title="No photo checks waiting">New submissions appear here oldest first, with their deletion deadline.</EmptyState>
          </section>
        ) : queue.map((item, index) => {
          const ready = Boolean(item.primary_photo_url && item.neutral_url && item.smile_url && item.blink_url);
          return (
            <article className="card" key={item.submission_id}>
              <header className="card-head">
                <div>
                  <p className="eyebrow">Check {index + 1} of {queue.length}</p>
                  <h2 className="display">{item.member_name || "Name unavailable"}</h2>
                </div>
                <dl className="kv">
                  <div><dt>Submitted</dt><dd>{relativeTime(item.submitted_at)}</dd></div>
                  <div><dt>Delete by</dt><dd>{formatDateTime(item.review_deadline)}</dd></div>
                  <div><dt>Guide</dt><dd>{item.guidance_mode === "manual_accessibility_v1" ? "Accessibility" : "Smile + blink"}</dd></div>
                </dl>
              </header>
              <div className="card-body stack">
                {item.preview_error ? (
                  <div className="notice danger"><TriangleAlert size={16} /><span><strong>Previews failed to load.</strong> Refresh once. Never approve without all four images.</span></div>
                ) : null}
                <div className="evidence-grid">
                  <Evidence title="Current main photo" url={item.primary_photo_url} alt={`Current main profile photo for ${item.member_name}`} />
                  <Evidence title="Looking at camera" url={item.neutral_url} alt={`Neutral capture for ${item.member_name}`} />
                  <Evidence title="Gentle smile" url={item.smile_url} alt={`Smile capture for ${item.member_name}`} />
                  <Evidence title="Natural blink" url={item.blink_url} alt={`Blink capture for ${item.member_name}`} />
                </div>

                <div className="grid-2">
                  <form action={reviewPhotoVerification} className="popover-form">
                    <Fields item={item} decision="approve" />
                    <fieldset disabled={!ready} className="stack">
                      <legend className="cell-main">Approve the photo badge</legend>
                      {checks.map(([name, label]) => (
                        <label key={name} className="check-row"><input type="checkbox" name={name} required /><span>{label}</span></label>
                      ))}
                      <SubmitButton className="btn btn-primary">Approve badge</SubmitButton>
                    </fieldset>
                  </form>

                  <div className="stack">
                    <form action={reviewPhotoVerification} className="popover-form">
                      <Fields item={item} decision="resubmit" />
                      <label className="field">Ask for a clearer submission
                        <select name="reason" className="select" required defaultValue="">
                          <option value="" disabled>Choose the exact issue</option>
                          <option>Face is too dark or unclear to compare</option>
                          <option>More than one person appears in a capture</option>
                          <option>Guided captures do not show the same person</option>
                          <option>Current profile photo is too unclear to compare</option>
                          <option>Current profile photo changed during review</option>
                        </select>
                      </label>
                      <SubmitButton className="btn">Request resubmission</SubmitButton>
                    </form>
                    <details className="disclosure">
                      <summary className="btn btn-ghost btn-sm">Reject this check…</summary>
                      <form action={reviewPhotoVerification} className="popover-form">
                        <Fields item={item} decision="reject" />
                        <label className="field">Confirmed reason
                          <select name="reason" className="select" required defaultValue="">
                            <option value="" disabled>Choose a confirmed reason</option>
                            <option>Captures appear intentionally manipulated</option>
                            <option>Captures belong to another person</option>
                            <option>Submission repeatedly violates verification rules</option>
                          </select>
                        </label>
                        <SubmitButton className="btn btn-danger-solid" confirm="Reject this photo check?">Confirm rejection</SubmitButton>
                      </form>
                    </details>
                  </div>
                </div>
              </div>
            </article>
          );
        })}
      </div>
    </div>
  );
}
