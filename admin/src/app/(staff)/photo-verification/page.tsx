import Image from "next/image";
import { requireAdmin } from "@/lib/auth";
import {
  getPhotoVerificationQueue,
  type PhotoVerificationRow,
} from "@/lib/operations";
import { reviewPhotoVerification } from "../actions";

const checks = [
  ["clearCapture", "All guided captures are clear enough for a human comparison"],
  ["samePerson", "The same person appears across neutral, smile and blink captures"],
  ["currentPhotoMatch", "That person reasonably matches the current primary profile photo"],
] as const;

function Evidence({ title, url, alt }: { title:string; url?:string|null; alt:string }) {
  return <section className="photo-check-evidence">
    <div className="photo-check-evidence-heading"><h3>{title}</h3><span>Private preview · 5 min</span></div>
    {url ? <a href={url} target="_blank" rel="noreferrer" className="photo-check-evidence-frame" aria-label={`Open ${title} at full size`}>
      <Image src={url} alt={alt} width={900} height={900} unoptimized priority={false}/>
      <span>Open full size</span>
    </a> : <div className="photo-check-evidence-unavailable">Preview unavailable. Do not decide this submission.</div>}
  </section>;
}

function HiddenFields({ item, decision }: { item:PhotoVerificationRow; decision:"approve"|"reject"|"resubmit" }) {
  return <><input type="hidden" name="submissionId" value={item.submission_id}/><input type="hidden" name="decision" value={decision}/></>;
}

export default async function PhotoVerificationPage() {
  await requireAdmin();
  const queue = await getPhotoVerificationQueue();

  return <section className="dashboard-page photo-check-page">
    <div className="page-hero">
      <div><p className="eyebrow">Privacy-minimizing trust operations</p><h1>Photo verification</h1><p className="muted">Compare the temporary guided captures with the current primary profile photo. This is a photo check, not government identity verification.</p></div>
      <div className="photo-check-queue-count"><strong>{queue.length}</strong><span>awaiting review</span></div>
    </div>

    <aside className="photo-check-review-rule"><strong>No automated identity decision.</strong><span>Approve only after all three checks. Saving any decision starts immediate capture deletion; the retention worker guarantees deletion by the 48-hour deadline.</span></aside>

    {queue.length === 0 ? <div className="photo-check-empty"><span>Queue clear</span><h2>No photo checks are waiting</h2><p>New submissions appear here oldest first.</p></div> :
      <div className="photo-check-review-list">{queue.map((item, index) => <article className="photo-check-review-card" key={item.submission_id}>
        <header className="photo-check-review-header">
          <div><p className="eyebrow">Review {index + 1} of {queue.length}</p><h2>{item.member_name || "Name unavailable"}</h2><p className="muted">Submitted {new Date(item.submitted_at).toLocaleString()} · deletion deadline {new Date(item.review_deadline).toLocaleString()}</p></div>
          <dl className="photo-check-facts">
            <div><dt>Guide</dt><dd>{item.guidance_mode === "manual_accessibility_v1" ? "Accessibility fallback" : "Smile + blink"}</dd></div>
            <div><dt>Retention</dt><dd>Temporary · max 48 hours</dd></div>
          </dl>
        </header>

        {item.preview_error && <div className="photo-check-preview-error"><strong>Preview failed.</strong> {item.preview_error} Refresh once; never approve without all four images.</div>}
        <div className="photo-check-evidence-grid">
          <Evidence title="Current profile photo" url={item.primary_photo_url} alt={`Current primary profile photo for ${item.member_name}`}/>
          <Evidence title="Look at camera" url={item.neutral_url} alt={`Neutral verification capture for ${item.member_name}`}/>
          <Evidence title="Gentle smile" url={item.smile_url} alt={`Smile verification capture for ${item.member_name}`}/>
          <Evidence title="Natural blink" url={item.blink_url} alt={`Blink verification capture for ${item.member_name}`}/>
        </div>

        <form action={reviewPhotoVerification} className="photo-check-approval-form">
          <HiddenFields item={item} decision="approve"/>
          <fieldset disabled={!item.primary_photo_url || !item.neutral_url || !item.smile_url || !item.blink_url}>
            <legend>Approval checklist</legend>
            <div className="photo-check-checklist">{checks.map(([name, label]) => <label key={name}><input type="checkbox" name={name} required/><span>{label}</span></label>)}</div>
            <button className="photo-check-approve-button" type="submit">Approve photo badge</button>
          </fieldset>
        </form>

        <div className="photo-check-alternate-decisions">
          <form action={reviewPhotoVerification} className="photo-check-resubmit-form">
            <HiddenFields item={item} decision="resubmit"/>
            <label><span>Ask for a clearer submission</span><select name="reason" required defaultValue=""><option value="" disabled>Choose the exact issue</option><option>Face is too dark or unclear to compare</option><option>More than one person appears in a capture</option><option>Guided captures do not show the same person</option><option>Current profile photo is too unclear to compare</option><option>Current profile photo changed during review</option></select></label>
            <button type="submit">Request resubmission</button>
          </form>
          <details className="photo-check-reject-panel"><summary>Reject this photo check</summary><form action={reviewPhotoVerification}><HiddenFields item={item} decision="reject"/><label><span>Rejection reason</span><select name="reason" required defaultValue=""><option value="" disabled>Choose a confirmed reason</option><option>Captures appear intentionally manipulated</option><option>Captures belong to another person</option><option>Submission repeatedly violates verification rules</option></select></label><button type="submit" className="danger">Confirm rejection</button></form></details>
        </div>
      </article>)}</div>}
  </section>;
}
