import { Bell, CheckCheck } from "lucide-react";
import { markAdminNotificationRead, markAllAdminNotificationsRead } from "@/app/(staff)/actions";
import { getAdminInbox } from "@/lib/operations";

export default async function InboxPage() {
  const notifications = await getAdminInbox();
  const unreadCount = notifications.filter((item) => !item.is_read).length;

  return (
    <section className="dashboard-page wide-page">
      <div className="page-hero">
        <div>
          <p className="eyebrow">Admin inbox</p>
          <h1>Operations alerts</h1>
          <p className="muted">System-generated admin notifications from moderation, trust scoring, analytics, and operational rules.</p>
        </div>
        <form action={markAllAdminNotificationsRead}>
          <button className="primary-button compact-button" disabled={unreadCount === 0}><CheckCheck size={16} /> Mark all read</button>
        </form>
      </div>

      <div className="queue-list">
        {notifications.map((item) => (
          <article className={`queue-card elevated-panel ${item.is_read ? "is-read" : "is-unread"}`} key={item.notification_id}>
            <div>
              <h2><Bell size={17} /> {item.type}</h2>
              <p>{item.message}</p>
              <p className="muted">{new Date(item.created_at).toLocaleString()}{item.related_user_id ? ` · user ${item.related_user_id}` : ""}</p>
            </div>
            {!item.is_read ? (
              <form action={markAdminNotificationRead}>
                <input type="hidden" name="notificationId" value={item.notification_id} />
                <button className="inline-action">Mark read</button>
              </form>
            ) : <span className="status-pill">Read</span>}
          </article>
        ))}
        {notifications.length === 0 && <p className="muted">No admin notifications yet.</p>}
      </div>
    </section>
  );
}
