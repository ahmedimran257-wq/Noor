import { FileText } from "lucide-react";
import { setContentStatus, upsertContentPage } from "@/app/(staff)/actions";
import { getContentPages } from "@/lib/operations";

export default async function ContentPage() {
  const pages = await getContentPages();

  return (
    <section className="dashboard-page">
      <p className="eyebrow">Content</p>
      <h1>CMS pages</h1>
      <p className="muted">Manage app copy such as legal pages, safety notes, help articles, and launch announcements.</p>

      <form action={upsertContentPage} className="admin-form panel-form">
        <h2><FileText size={18} /> Draft or update page</h2>
        <div className="form-grid">
          <label>Slug<input name="slug" required pattern="[a-z0-9][a-z0-9-]{1,80}" placeholder="privacy-policy" /></label>
          <label>Locale<input name="locale" required defaultValue="en" pattern="[a-z]{2}(-[a-z]{2})?" /></label>
          <label className="wide">Title<input name="title" required minLength={3} maxLength={120} placeholder="Privacy Policy" /></label>
        </div>
        <label>Body<textarea name="body" required minLength={20} rows={8} placeholder="Write the page body here." /></label>
        <button type="submit" className="primary-button">Save draft</button>
      </form>

      <h2 className="section-title">Pages</h2>
      <div className="queue-list">
        {pages.map((page) => (
          <article key={page.page_id} className="queue-card">
            <div>
              <strong>{page.title}</strong>
              <p className="muted">{page.slug} · {page.locale} · {page.status}</p>
              <p>{page.body.slice(0, 180)}{page.body.length > 180 ? "..." : ""}</p>
            </div>
            <div className="action-row">
              <form action={setContentStatus}>
                <input type="hidden" name="pageId" value={page.page_id} />
                <input type="hidden" name="status" value="published" />
                <button type="submit">Publish</button>
              </form>
              <form action={setContentStatus}>
                <input type="hidden" name="pageId" value={page.page_id} />
                <input type="hidden" name="status" value="archived" />
                <button type="submit" className="danger">Archive</button>
              </form>
            </div>
          </article>
        ))}
        {pages.length === 0 && <p className="muted">No CMS pages yet.</p>}
      </div>
    </section>
  );
}
