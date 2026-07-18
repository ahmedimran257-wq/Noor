import Image from "next/image";
import { requireAdmin } from "@/lib/auth";
import { getKycQueue, type KycRow } from "@/lib/operations";
import { reviewKyc } from "../actions";

const checks = [
  ["documentReadable", "Document is genuine-looking, readable and complete"],
  ["nameMatch", "Document name matches the profile name"],
  ["dobMatch", "Document date of birth matches the profile and is 18+"],
  ["faceMatch", "Current selfie reasonably matches the document portrait"],
  ["documentUnexpired", "Document is not expired or visibly altered"],
] as const;

function Evidence({ title, url, alt }: { title:string; url?:string|null; alt:string }) {
  return <section className="kyc-evidence">
    <div className="kyc-evidence-heading"><h3>{title}</h3><span>Private preview · 5 min</span></div>
    {url ? <a href={url} target="_blank" rel="noreferrer" className="kyc-evidence-frame" aria-label={`Open ${title} at full size`}>
      <Image src={url} alt={alt} width={900} height={640} unoptimized priority={false}/>
      <span>Open full size</span>
    </a> : <div className="kyc-evidence-unavailable">Preview unavailable. Do not decide this submission.</div>}
  </section>;
}

function HiddenFields({ item, decision }: { item:KycRow; decision:"approve"|"reject"|"resubmit" }) {
  return <><input type="hidden" name="submissionId" value={item.submission_id}/><input type="hidden" name="decision" value={decision}/></>;
}

export default async function KycPage() {
  await requireAdmin();
  const queue = await getKycQueue();

  return <section className="dashboard-page kyc-page">
    <div className="page-hero">
      <div><p className="eyebrow">Private identity operations</p><h1>Identity review</h1><p className="muted">One submission at a time. Compare the original evidence, complete every check, then record one clear decision.</p></div>
      <div className="kyc-queue-count"><strong>{queue.length}</strong><span>awaiting review</span></div>
    </div>

    <aside className="kyc-review-rule"><strong>Device scores never decide.</strong><span>They can help spot capture problems, but approval requires your direct review of both private images and all five checks.</span></aside>

    {queue.length === 0 ? <div className="kyc-empty"><span>Queue clear</span><h2>No identity reviews are waiting</h2><p>New submissions will appear here oldest first.</p></div> :
      <div className="kyc-review-list">{queue.map((item, index) => <article className="kyc-review-card" key={item.submission_id}>
        <header className="kyc-review-header">
          <div><p className="eyebrow">Review {index + 1} of {queue.length}</p><h2>{item.name || "Name unavailable"}</h2><p className="muted">Submitted {new Date(item.submitted_at).toLocaleString()} · attempt {item.attempt_number}</p></div>
          <dl className="kyc-facts">
            <div><dt>Profile DOB</dt><dd>{item.date_of_birth} ({item.age})</dd></div>
            <div><dt>Country</dt><dd>{item.country_code}</dd></div>
            <div><dt>Document</dt><dd>{item.kyc_id_type.replaceAll("_", " ")}</dd></div>
          </dl>
        </header>

        {item.preview_error && <div className="kyc-preview-error"><strong>Evidence preview failed.</strong> {item.preview_error}. Refresh once; never approve without both originals.</div>}
        <div className="kyc-evidence-grid">
          <Evidence title="Live selfie" url={item.selfie_url} alt={`Private selfie submitted by ${item.name}`}/>
          <Evidence title="Identity document" url={item.id_url} alt={`Private identity document submitted by ${item.name}`}/>
        </div>

        <details className="kyc-device-hints">
          <summary>Device hints — not a decision</summary>
          <div><span>OCR date</span><strong>{item.client_ocr_dob ?? "Not read"}</strong><span>Face similarity</span><strong>{item.client_face_similarity == null ? "Not available" : `${Math.round(item.client_face_similarity * 100)}%`}</strong></div>
        </details>

        <form action={reviewKyc} className="kyc-approval-form">
          <HiddenFields item={item} decision="approve"/>
          <fieldset disabled={!item.selfie_url || !item.id_url}>
            <legend>Approval checklist</legend>
            <div className="kyc-checklist">{checks.map(([name, label]) => <label key={name}><input type="checkbox" name={name} required/><span>{label}</span></label>)}</div>
            <button className="kyc-approve-button" type="submit">Approve ID review</button>
          </fieldset>
        </form>

        <div className="kyc-alternate-decisions">
          <form action={reviewKyc} className="kyc-resubmit-form">
            <HiddenFields item={item} decision="resubmit"/>
            <label><span>Ask for a clearer submission</span><select name="reason" required defaultValue=""><option value="" disabled>Choose the exact issue</option><option>Document is unreadable or partly outside the frame</option><option>Selfie is too dark or unclear to compare</option><option>Profile name does not match the document</option><option>Profile date of birth does not match the document</option><option>Document is expired or appears altered</option></select></label>
            <button type="submit">Request resubmission</button>
          </form>
          <details className="kyc-reject-panel"><summary>Reject this identity check</summary><form action={reviewKyc}><HiddenFields item={item} decision="reject"/><label><span>Rejection reason</span><select name="reason" required defaultValue=""><option value="" disabled>Choose a confirmed reason</option><option>Applicant is under 18</option><option>Document belongs to another person</option><option>Document appears forged or manipulated</option><option>Identity evidence is intentionally deceptive</option></select></label><button type="submit" className="danger">Confirm rejection</button></form></details>
        </div>
      </article>)}</div>}
  </section>;
}
