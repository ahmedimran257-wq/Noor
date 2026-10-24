"use client";

import { BadgeCheck, Heart, MessageCircle, Radio, Sparkles, Users } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import type { DashboardOverview } from "@/lib/operations";

// private.refresh_admin_metric_snapshots runs every 15 minutes. Fetching more
// often only re-reads the same row, so the next fetch is scheduled for just
// after the next snapshot, and only while the tab is visible.
const snapshotEveryMs = 15 * 60 * 1000;
const snapshotGraceMs = 45 * 1000;

function n(value: number | undefined) {
  return Number(value ?? 0).toLocaleString("en-IN");
}

function pct(value: number | undefined) {
  return Math.max(0, Math.min(100, Math.round(Number(value ?? 0))));
}

const timeFormat = new Intl.DateTimeFormat("en-IN", { hour: "2-digit", minute: "2-digit", timeZone: "Asia/Kolkata" });

export function LiveOperationsCockpit({ initial }: { initial: DashboardOverview }) {
  const [data, setData] = useState(initial);
  const [status, setStatus] = useState<"ready" | "refreshing" | "error">("ready");
  const inFlight = useRef(false);

  const generatedAtMs = (data.live?.generatedAt ?? 0) * 1000;

  const refresh = useCallback(async () => {
    if (inFlight.current) return;
    inFlight.current = true;
    setStatus("refreshing");
    try {
      const response = await fetch("/api/live", { cache: "no-store" });
      if (!response.ok) throw new Error(String(response.status));
      const next = await response.json() as DashboardOverview;
      setData(next);
      setStatus("ready");
    } catch {
      setStatus("error");
    } finally {
      inFlight.current = false;
    }
  }, []);

  useEffect(() => {
    let timer: number | undefined;
    const schedule = () => {
      window.clearTimeout(timer);
      if (document.hidden) return;
      const due = (generatedAtMs || Date.now()) + snapshotEveryMs + snapshotGraceMs;
      timer = window.setTimeout(() => void refresh(), Math.max(due - Date.now(), 30_000));
    };
    const onVisibility = () => {
      if (document.hidden) {
        window.clearTimeout(timer);
        return;
      }
      if (Date.now() >= generatedAtMs + snapshotEveryMs + snapshotGraceMs) void refresh();
      else schedule();
    };
    schedule();
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [generatedAtMs, refresh]);

  const live = data.live;
  const traffic = live?.traffic ?? {};
  const engagement = live?.engagement ?? {};
  const pipeline = live?.pipeline ?? {};
  const progress = live?.progress ?? {};
  const updated = generatedAtMs ? `${timeFormat.format(new Date(generatedAtMs))} IST` : "not yet generated";

  const today = [
    { label: "Online now", value: traffic.onlineNow, icon: Radio },
    { label: "Active today", value: traffic.activeToday, icon: Users },
    { label: "New members today", value: traffic.signupsToday, icon: Sparkles },
    { label: "Messages today", value: engagement.messagesToday, icon: MessageCircle },
    { label: "Interests today", value: engagement.interestsToday, icon: Heart },
    { label: "Matches today", value: engagement.matchesToday, icon: BadgeCheck },
  ];

  const funnel = [
    { label: "Profiles completed", value: pipeline.completionRate },
    { label: "Photo verified", value: pipeline.verificationRate },
    { label: "Photos cleared", value: pipeline.photoClearanceRate },
    { label: "Subscribers", value: pipeline.subscriberRate },
  ];

  return (
    <div className="stack-lg">
      <section aria-labelledby="today-title">
        <div className="section-head">
          <h2 id="today-title">Today</h2>
          <p className="row" aria-live="polite">
            {status === "error" ? (
              <span className="pill warn plain">Live figures could not refresh</span>
            ) : (
              <span>Snapshot {updated}</span>
            )}
            <button type="button" className="btn btn-ghost btn-sm" onClick={() => void refresh()} disabled={status === "refreshing"}>
              {status === "refreshing" ? "Updating…" : "Update"}
            </button>
          </p>
        </div>
        <div className="stat-grid">
          {today.map(({ label, value, icon: Icon }) => (
            <div className="stat" key={label}>
              <span className="stat-label"><Icon size={15} aria-hidden="true" />{label}</span>
              <span className="stat-value">{n(value)}</span>
            </div>
          ))}
        </div>
      </section>

      <div className="split">
        <section className="card" aria-labelledby="funnel-title">
          <div className="card-head">
            <h2 id="funnel-title">Member journey</h2>
            <span className="muted">{n(progress.totalProfiles)} profiles · avg. {pct(progress.avgCompletion)}% complete</span>
          </div>
          <div className="card-body meter-list">
            {funnel.map((item) => (
              <div className="meter-row" key={item.label}>
                <div><span>{item.label}</span><strong>{pct(item.value)}%</strong></div>
                <progress className="meter" max={100} value={pct(item.value)} aria-label={`${item.label} ${pct(item.value)}%`} />
              </div>
            ))}
          </div>
        </section>

        <section className="card" aria-labelledby="online-title">
          <div className="card-head">
            <h2 id="online-title"><Radio size={16} /> Online members</h2>
            <span className="muted">last 12 min</span>
          </div>
          {data.onlineUsers.length === 0 ? (
            <div className="empty">
              <h3>No one is online</h3>
              <p>Members appear here while the app is open on their phone.</p>
            </div>
          ) : (
            <div className="people">
              {data.onlineUsers.map((user) => (
                <div className="person" key={user.user_id}>
                  <span className="avatar" aria-hidden="true">{user.name.slice(0, 1)}</span>
                  <span className="who">
                    <strong>{user.name}</strong>
                    <small>{[user.country_code, user.platform, user.app_state].filter(Boolean).join(" · ")}</small>
                  </span>
                  <span className="live-dot" aria-label="Online" />
                </div>
              ))}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
