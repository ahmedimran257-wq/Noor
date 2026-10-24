import { FileText, PencilLine } from "lucide-react";
import Link from "next/link";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDateTime } from "@/components/ui";
import { requireArea } from "@/lib/auth";
import { getContentPages } from "@/lib/operations";
import { setContentStatus, upsertContentPage } from "../actions";

export const metadata = { title: "Content" };

export default async function ContentPage({ searchParams }: { searchParams: Promise<{ edit?: string }> }) {
  const { allowed } = await requireArea("content");
  if (!allowed) return <NoAccess area="Content" />;
  const params = await searchParams;
  const pages = await getContentPages();
  // Editing reuses the list already loaded: no extra read.
  const editing = pages.find((page) => page.page_id === params.edit) ?? null;
  const returnTo = editing ? `/content?edit=${editing.page_id}` : "/content";

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Publishing"
        title="App content"
        lede="Help articles, safety notes and announcements shown in the app. New pages start as drafts. Saving a published page updates it for members straight away."
      />

      <div className="split">
        <section className="card">
          <div className="card-head"><h2><FileText size={16} /> Pages</h2><span className="muted">{pages.length} total</span></div>
          {pages.length === 0 ? (
            <EmptyState icon={FileText} title="No pages yet">Write your first page with the form. It stays a draft until you publish it.</EmptyState>
          ) : (
            <div className="list">
              {pages.map((page) => (
                <article className="list-item" key={page.page_id}>
                  <div>
                    <h3>{page.title} <StatusPill status={page.status} /></h3>
                    <p className="muted">{page.body.slice(0, 160)}{page.body.length > 160 ? "…" : ""}</p>
                    <div className="meta">
                      <span className="mono">{page.slug}</span>
                      <span>{page.locale}</span>
                      <span>updated {formatDateTime(page.updated_at)}</span>
                    </div>
                  </div>
                  <div className="aside">
                    <Link href={`/content?edit=${page.page_id}`} prefetch={false} scroll={false} className="btn btn-sm btn-ghost"><PencilLine size={14} /> Edit</Link>
                    {page.status !== "published" ? (
                      <form action={setContentStatus}>
                        <input type="hidden" name="pageId" value={page.page_id} />
                        <input type="hidden" name="status" value="published" />
                        <input type="hidden" name="returnTo" value={returnTo} />
                        <SubmitButton className="btn btn-sm btn-primary">Publish</SubmitButton>
                      </form>
                    ) : null}
                    {page.status !== "archived" ? (
                      <form action={setContentStatus}>
                        <input type="hidden" name="pageId" value={page.page_id} />
                        <input type="hidden" name="status" value="archived" />
                        <input type="hidden" name="returnTo" value={returnTo} />
                        <SubmitButton className="btn btn-sm" confirm="Archive this page? Members will no longer see it.">Archive</SubmitButton>
                      </form>
                    ) : null}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head">
            <h2>{editing ? "Edit page" : "New page"}</h2>
            {editing ? <Link href="/content" prefetch={false} className="link">New page instead</Link> : null}
          </div>
          {/* key resets the uncontrolled fields when switching pages. */}
          <form action={upsertContentPage} className="card-body stack" key={editing?.page_id ?? "new"}>
            <input type="hidden" name="returnTo" value={returnTo} />
            {editing?.status === "published" ? <p className="notice warn"><span><strong>{editing.title}</strong> is live. Saving updates it for members immediately.</span></p> : null}
            <div className="form-grid">
              <label className="field">Slug<input name="slug" className="input" required pattern="[a-z0-9][a-z0-9\-]{1,80}" placeholder="safety-tips" defaultValue={editing?.slug} readOnly={Boolean(editing)} /></label>
              <label className="field">Language<input name="locale" className="input" required defaultValue={editing?.locale ?? "en"} pattern="[a-z]{2}(-[a-z]{2})?" readOnly={Boolean(editing)} /></label>
            </div>
            <label className="field">Title<input name="title" className="input" required minLength={3} maxLength={120} placeholder="Staying safe on Silarah" defaultValue={editing?.title} /></label>
            <label className="field">Body<textarea name="body" className="textarea" required minLength={20} rows={12} defaultValue={editing?.body} /></label>
            <div className="form-actions"><SubmitButton className="btn btn-primary">{editing ? "Save changes" : "Save draft"}</SubmitButton></div>
          </form>
        </section>
      </div>
    </div>
  );
}
