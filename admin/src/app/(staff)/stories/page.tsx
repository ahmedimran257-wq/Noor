import { BookOpenCheck } from "lucide-react";
import { addSuccessStory, reviewSuccessStory } from "@/app/(staff)/actions";
import { getSuccessStories } from "@/lib/operations";

export default async function StoriesPage() {
  const stories = await getSuccessStories();

  return (
    <section className="dashboard-page">
      <p className="eyebrow">Marriage stories</p>
      <h1>Success stories</h1>
      <p className="muted">Review, publish, and add verified marriage stories for future in-app trust content.</p>

      <form action={addSuccessStory} className="admin-form panel-form">
        <h2><BookOpenCheck size={18} /> Add story</h2>
        <div className="form-grid">
          <label>Couple name<input name="coupleName" required minLength={2} maxLength={120} placeholder="A & F" /></label>
          <label>Country code<input name="countryCode" maxLength={2} placeholder="MY" /></label>
          <label className="wide">Photo path<input name="photoPath" placeholder="success-stories/story.webp" /></label>
        </div>
        <label>Story<textarea name="story" required minLength={20} rows={6} placeholder="Share the story in a respectful, privacy-safe way." /></label>
        <button type="submit" className="primary-button">Add published story</button>
      </form>

      <h2 className="section-title">Story queue</h2>
      <div className="queue-list">
        {stories.map((story) => (
          <article key={story.story_id} className="queue-card">
            <div>
              <strong>{story.couple_name}</strong>
              <p className="muted">{story.country_code ?? "Global"} · {story.status} · {new Date(story.created_at).toLocaleDateString()}</p>
              <p>{story.story}</p>
              {story.photo_path && <small className="muted">{story.photo_path}</small>}
            </div>
            <div className="action-row">
              <form action={reviewSuccessStory}>
                <input type="hidden" name="storyId" value={story.story_id} />
                <input type="hidden" name="status" value="published" />
                <button type="submit">Publish</button>
              </form>
              <form action={reviewSuccessStory}>
                <input type="hidden" name="storyId" value={story.story_id} />
                <input type="hidden" name="status" value="rejected" />
                <button type="submit" className="danger">Reject</button>
              </form>
              <form action={reviewSuccessStory}>
                <input type="hidden" name="storyId" value={story.story_id} />
                <input type="hidden" name="status" value="archived" />
                <button type="submit">Archive</button>
              </form>
            </div>
          </article>
        ))}
        {stories.length === 0 && <p className="muted">No success stories yet.</p>}
      </div>
    </section>
  );
}
