import {
  Camera,
  Eye,
  Flag,
  ShieldAlert,
  ShieldCheck,
  Timer,
} from "lucide-react";
import Image from "next/image";
import { requireAdmin } from "@/lib/auth";
import type { PhotoRow } from "@/lib/operations";
import { getPhotos, getReports } from "@/lib/operations";
import { resolveReport, reviewPhoto } from "../actions";

function scoreLabel(photo: PhotoRow) {
  const score = Number(photo.nsfw_score ?? 0);
  if (photo.nsfw_score === null) return { label: "No score", tone: "neutral" };
  if (score >= 0.88) return { label: "Hard NSFW signal", tone: "danger" };
  if (score >= 0.55) return { label: "Borderline review", tone: "warning" };
  return { label: "Client-screened pending", tone: "good" };
}

export default async function ModerationPage() {
  await requireAdmin();
  const [reports, photos] = await Promise.all([getReports(), getPhotos()]);
  const hardSignals = photos.filter((photo) => Number(photo.nsfw_score ?? 0) >= 0.88).length;
  const reviewSignals = photos.filter((photo) => {
    const score = Number(photo.nsfw_score ?? 0);
    return score >= 0.55 && score < 0.88;
  }).length;
  const clientScreened = photos.filter((photo) => Number(photo.nsfw_score ?? 0) < 0.55).length;

  return (
    <section className="dashboard-page wide-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Safety operations</p>
          <h1>Moderation</h1>
          <p className="muted">
            Review real reports and private profile-photo uploads before they become visible in discovery.
          </p>
        </div>
        <div className="hero-badge">{reports.length + photos.length} pending</div>
      </div>

      <div className="moderation-signal-grid">
        <div className="moderation-signal danger">
          <ShieldAlert size={18} />
          <span>Hard NSFW signals</span>
          <strong>{hardSignals}</strong>
        </div>
        <div className="moderation-signal warning">
          <Timer size={18} />
          <span>Borderline review</span>
          <strong>{reviewSignals}</strong>
        </div>
        <div className="moderation-signal good">
          <ShieldCheck size={18} />
          <span>Client-screened pending</span>
          <strong>{clientScreened}</strong>
        </div>
      </div>

      <h2 className="section-title"><Flag size={18} /> Open reports</h2>
      <div className="queue-list">
        {reports.map((report) => (
          <article className="queue-card elevated-panel" key={report.report_id}>
            <div>
              <h2>{report.reported_name || "Reported user"}</h2>
              <p className="muted">
                {report.reason} · {report.report_count} open reports · {new Date(report.created_at).toLocaleString()}
              </p>
              {report.description ? <p>{report.description}</p> : null}
            </div>
            <div className="action-row">
              <form action={resolveReport}>
                <input type="hidden" name="reportId" value={report.report_id} />
                <input type="hidden" name="action" value="actioned" />
                <button>Actioned</button>
              </form>
              <form action={resolveReport}>
                <input type="hidden" name="reportId" value={report.report_id} />
                <input type="hidden" name="action" value="dismissed" />
                <button>Dismiss</button>
              </form>
            </div>
          </article>
        ))}
        {reports.length === 0 && <p className="muted">No open reports.</p>}
      </div>

      <h2 className="section-title"><Camera size={18} /> Photo review</h2>
      <div className="photo-review-grid">
        {photos.map((photo) => {
          const risk = scoreLabel(photo);
          return (
            <article className="photo-review-card elevated-panel" key={photo.photo_id}>
              <div className="photo-preview">
                {photo.preview_url ? (
                  <Image
                    src={photo.preview_url}
                    alt={`Pending profile photo for ${photo.name || "member"}`}
                    width={620}
                    height={780}
                    unoptimized
                  />
                ) : (
                  <div className="photo-preview-missing">
                    <Camera size={28} />
                    <span>Preview unavailable</span>
                    {photo.preview_error ? <small>{photo.preview_error}</small> : null}
                  </div>
                )}
              </div>
              <div className="photo-evidence">
                <div>
                  <span className={`status-pill ${risk.tone === "danger" ? "danger" : ""}`}>
                    {risk.label}
                  </span>
                  <h2>{photo.name || "Member photo"}</h2>
                  <p className="muted">
                    {photo.nsfw_category ?? "Unclassified"} · score {photo.nsfw_score?.toFixed(2) ?? "N/A"} · {new Date(photo.created_at).toLocaleString()}
                  </p>
                  <small className="muted">{photo.storage_path}</small>
                </div>

                <div className="photo-evidence-strip">
                  <div><span>Status</span><strong>{photo.moderation_status}</strong></div>
                  <div><span>User</span><strong>{photo.user_id.slice(0, 8)}...</strong></div>
                  <div><span>Source</span><strong>on-device scan</strong></div>
                </div>

                <div className="action-row photo-actions">
                  {photo.preview_url ? (
                    <a className="inline-action" href={photo.preview_url} target="_blank" rel="noreferrer">
                      <Eye size={14} /> Open
                    </a>
                  ) : null}
                  <form action={reviewPhoto}>
                    <input type="hidden" name="photoId" value={photo.photo_id} />
                    <input type="hidden" name="decision" value="approve" />
                    <input type="hidden" name="reason" value="Manual profile photo review approved." />
                    <button>Approve</button>
                  </form>
                  <form action={reviewPhoto} className="photo-reject-form">
                    <input type="hidden" name="photoId" value={photo.photo_id} />
                    <input type="hidden" name="decision" value="reject" />
                    <input name="reason" placeholder="Reason for rejection" />
                    <button className="danger">Reject</button>
                  </form>
                </div>
              </div>
            </article>
          );
        })}
        {photos.length === 0 && <p className="muted">No photos pending review.</p>}
      </div>
    </section>
  );
}
