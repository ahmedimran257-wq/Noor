import { BookHeart } from "lucide-react";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDate } from "@/components/ui";
import { requireArea } from "@/lib/auth";
import { getSuccessStories } from "@/lib/operations";
import { addSuccessStory, reviewSuccessStory } from "../actions";

export const metadata = { title: "Stories" };

function StatusButton({ storyId, status, label, className = "btn btn-sm", confirm }: { storyId: string; status: string; label: string; className?: string; confirm?: string }) {
  return (
    <form action={reviewSuccessStory}>
      <input type="hidden" name="storyId" value={storyId} />
      <input type="hidden" name="status" value={status} />
      <input type="hidden" name="returnTo" value="/stories" />
      <SubmitButton className={className} confirm={confirm}>{label}</SubmitButton>
    </form>
  );
}

export default async function StoriesPage() {
  const { allowed } = await requireArea("stories");
  if (!allowed) return <NoAccess area="Stories" />;
  const stories = await getSuccessStories();

  return (
    <div className="stack-lg">
      <PageHeader
        eyebrow="Publishing"
        title="Marriage stories"
        lede="Stories couples have agreed to share. Use first initials or names they approved, and never contact details."
      />

      <div className="split">
        <section className="card">
          <div className="card-head"><h2><BookHeart size={16} /> Stories</h2><span className="muted">{stories.length} total</span></div>
          {stories.length === 0 ? (
            <EmptyState icon={BookHeart} title="No stories yet">Stories you add here can be shown in the app to build trust.</EmptyState>
          ) : (
            <div className="list">
              {stories.map((story) => (
                <article className="list-item" key={story.story_id}>
                  <div>
                    <h3>{story.couple_name} <StatusPill status={story.status} /></h3>
                    <p>{story.story}</p>
                    <div className="meta">
                      <span>{story.country_code ?? "Global"}</span>
                      <span>added {formatDate(story.created_at)}</span>
                      {story.photo_path ? <span className="mono">{story.photo_path}</span> : null}
                    </div>
                  </div>
                  <div className="aside">
                    {story.status !== "published" ? <StatusButton storyId={story.story_id} status="published" label="Publish" className="btn btn-sm btn-primary" /> : null}
                    {story.status === "pending" ? <StatusButton storyId={story.story_id} status="rejected" label="Reject" className="btn btn-sm btn-danger" /> : null}
                    {story.status !== "archived" ? <StatusButton storyId={story.story_id} status="archived" label="Archive" confirm="Archive this story? It will no longer be shown." /> : null}
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        <section className="card">
          <div className="card-head"><h2>Add a story</h2></div>
          <form action={addSuccessStory} className="card-body stack">
            <input type="hidden" name="returnTo" value="/stories" />
            <p className="notice warn"><span>Stories added here are <strong>published immediately</strong>. Only add stories the couple has approved.</span></p>
            <div className="form-grid">
              <label className="field">Couple<input name="coupleName" className="input" required minLength={2} maxLength={120} placeholder="A & F" /></label>
              <label className="field">Country code<input name="countryCode" className="input" maxLength={2} pattern="[A-Za-z]{2}" placeholder="IN" /></label>
            </div>
            <label className="field">Story<textarea name="story" className="textarea" required minLength={20} rows={7} placeholder="How they met, in their words." /></label>
            <label className="field">Photo path<input name="photoPath" className="input" placeholder="success-stories/story.webp" /><small>Optional. A file already uploaded to storage.</small></label>
            <div className="form-actions"><SubmitButton className="btn btn-primary" confirm="Publish this story now?">Publish story</SubmitButton></div>
          </form>
        </section>
      </div>
    </div>
  );
}
