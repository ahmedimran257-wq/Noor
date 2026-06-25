import { Camera, Flag } from "lucide-react";
import { requireAdmin } from "@/lib/auth";
import { getPhotos, getReports } from "@/lib/operations";
import { resolveReport, reviewPhoto } from "../actions";

export default async function ModerationPage() {
  await requireAdmin();
  const [reports, photos] = await Promise.all([getReports(), getPhotos()]);

  return (
    <section className="dashboard-page wide-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Safety operations</p>
          <h1>Moderation</h1>
          <p className="muted">Prioritize reports and photo review with the highest-risk queues first.</p>
        </div>
        <div className="hero-badge">{reports.length + photos.length} pending</div>
      </div>

      <h2 className="section-title"><Flag size={18} /> Open reports</h2>
      <div className="queue-list">
        {reports.map((report) => (
          <article className="queue-card elevated-panel" key={report.report_id}>
            <div>
              <h2>{report.reported_name || "Reported user"}</h2>
              <p className="muted">{report.reason} · {report.report_count} open reports · {new Date(report.created_at).toLocaleString()}</p>
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
      <div className="queue-list">
        {photos.map((photo) => (
          <article className="queue-card elevated-panel" key={photo.photo_id}>
            <div>
              <h2>{photo.name || "Member photo"}</h2>
              <p className="muted">{photo.nsfw_category ?? "Unclassified"} · confidence {photo.nsfw_score?.toFixed(2) ?? "N/A"}</p>
              <small className="muted">{photo.storage_path}</small>
            </div>
            <div className="action-row">
              <form action={reviewPhoto}>
                <input type="hidden" name="photoId" value={photo.photo_id} />
                <input type="hidden" name="decision" value="approve" />
                <button>Approve</button>
              </form>
              <form action={reviewPhoto}>
                <input type="hidden" name="photoId" value={photo.photo_id} />
                <input type="hidden" name="decision" value="reject" />
                <button className="danger">Reject</button>
              </form>
            </div>
          </article>
        ))}
        {photos.length === 0 && <p className="muted">No photos pending review.</p>}
      </div>
    </section>
  );
}
