"use client";

import { Activity, BadgeCheck, Bell, Camera, Heart, MessageCircle, Radio, ShieldAlert, Sparkles, Users, WalletCards } from "lucide-react";
import { useEffect, useMemo, useState, useTransition } from "react";

type Bucket = Record<string, number>;
type LiveSnapshot = {
  generatedAt: number;
  traffic: Bucket;
  engagement: Bucket;
  progress: Bucket;
  queues: Bucket;
  pipeline: Bucket;
};

type OnlineUser = {
  user_id: string;
  profile_id: string | null;
  name: string;
  email: string | null;
  country_code: string | null;
  gender: string | null;
  last_seen_at: string;
  app_state: string;
  platform: string | null;
  visibility: string;
  verification_status: string;
  subscription_status: string;
};

type LivePayload =
  | LiveSnapshot
  | {
      snapshot: LiveSnapshot;
      onlineUsers: OnlineUser[];
    };

type LiveState =
  | { status: "loading"; data: LiveSnapshot | null; onlineUsers: OnlineUser[]; error: null }
  | { status: "ready"; data: LiveSnapshot; onlineUsers: OnlineUser[]; error: null }
  | { status: "error"; data: LiveSnapshot | null; onlineUsers: OnlineUser[]; error: string };

// A one-minute visible-only refresh is operationally current without running
// four aggregate database snapshots per minute for every open admin tab.
const refreshMs = 60000;

function number(value: number | undefined) {
  return Number(value ?? 0).toLocaleString();
}

function percent(value: number | undefined) {
  return Math.max(0, Math.min(100, Number(value ?? 0)));
}

export function LiveOperationsCockpit({
  initial,
  initialOnlineUsers,
}: {
  initial: LiveSnapshot;
  initialOnlineUsers: OnlineUser[];
}) {
  const [state, setState] = useState<LiveState>({
    status: "ready",
    data: initial,
    onlineUsers: initialOnlineUsers,
    error: null,
  });
  const [isPending, startTransition] = useTransition();
  const [pulse, setPulse] = useState(0);

  useEffect(() => {
    let cancelled = false;
    async function refresh() {
      try {
        const response = await fetch("/api/live", { cache: "no-store" });
        if (!response.ok) throw new Error(`Live feed unavailable (${response.status})`);
        const payload = await response.json() as LivePayload;
        const data = "snapshot" in payload ? payload.snapshot : payload;
        const onlineUsers = "snapshot" in payload ? payload.onlineUsers : [];
        if (!cancelled) {
          startTransition(() => {
            setState({ status: "ready", data, onlineUsers, error: null });
            setPulse((value) => value + 1);
          });
        }
      } catch (error) {
        if (!cancelled) {
          setState((current) => ({
            status: "error",
            data: current.data,
            onlineUsers: current.onlineUsers,
            error: error instanceof Error ? error.message : "Live feed unavailable",
          }));
        }
      }
    }

    const refreshVisible = () => {
      if (!document.hidden) void refresh();
    };
    const timer = window.setInterval(refreshVisible, refreshMs);
    const onVisibility = () => {
      if (!document.hidden) void refresh();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      cancelled = true;
      window.clearInterval(timer);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, []);

  const snapshot = state.data ?? initial;
  const onlineUsers = state.onlineUsers;
  const lastUpdated = useMemo(() => {
    if (!snapshot.generatedAt) return "Waiting for live feed";
    return new Date(snapshot.generatedAt * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" });
  }, [snapshot.generatedAt]);

  const trafficCards = [
    { label: "Online now", value: snapshot.traffic.onlineNow, icon: Radio, tone: "live" },
    { label: "Active today", value: snapshot.traffic.activeToday, icon: Users, tone: "gold" },
    { label: "Signups last hour", value: snapshot.traffic.signupsLastHour, icon: Sparkles, tone: "green" },
    { label: "Messages last hour", value: snapshot.engagement.messagesLastHour, icon: MessageCircle, tone: "blue" },
    { label: "Interests today", value: snapshot.engagement.interestsToday, icon: Heart, tone: "rose" },
    { label: "Matches today", value: snapshot.engagement.matchesToday, icon: BadgeCheck, tone: "gold" },
  ] as const;

  const queues = [
    { label: "Open reports", value: snapshot.queues.openReports, icon: ShieldAlert },
    { label: "Pending photos", value: snapshot.queues.pendingPhotos, icon: Camera },
    { label: "Due pushes", value: snapshot.queues.dueNotifications, icon: Bell },
    { label: "Pushes sent 1h", value: snapshot.queues.sentNotificationsLastHour, icon: Activity },
  ] as const;

  const pipeline = [
    { label: "Profile completion", value: snapshot.pipeline.completionRate },
    { label: "Verification", value: snapshot.pipeline.verificationRate },
    { label: "Subscribers", value: snapshot.pipeline.subscriberRate },
    { label: "Photo clearance", value: snapshot.pipeline.photoClearanceRate },
  ] as const;

  return (
    <section className="live-cockpit" aria-label="Live operations cockpit">
      <div className="cockpit-header">
        <div>
          <p className="eyebrow">Live traffic</p>
          <h2>Operations cockpit</h2>
          <p className="muted">Direct RPC snapshot from the production Supabase project, refreshed every {refreshMs / 1000}s.</p>
        </div>
        <div className={`live-chip ${state.status}`} key={pulse}>
          <span className="live-dot" />
          {state.status === "error" ? state.error : isPending ? "Refreshing" : `Updated ${lastUpdated}`}
        </div>
      </div>

      <div className="traffic-grid">
        {trafficCards.map(({ label, value, icon: Icon, tone }) => (
          <article className={`traffic-card ${tone}`} key={label}>
            <Icon size={18} />
            <span>{label}</span>
            <strong>{number(value)}</strong>
          </article>
        ))}
      </div>

      <div className="cockpit-panels">
        <div className="glass-panel">
          <div className="panel-title"><Activity size={18} /> Funnel progress</div>
          <div className="progress-stack">
            {pipeline.map((item) => (
              <div className="progress-row" key={item.label}>
                <div><span>{item.label}</span><strong>{percent(item.value)}%</strong></div>
                <div className="premium-progress" aria-label={`${item.label} ${percent(item.value)}%`}>
                  <span style={{ width: `${percent(item.value)}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel">
          <div className="panel-title"><ShieldAlert size={18} /> Safety queues</div>
          <div className="queue-meters">
            {queues.map(({ label, value, icon: Icon }) => (
              <div className="queue-meter" key={label}>
                <Icon size={16} />
                <span>{label}</span>
                <strong>{number(value)}</strong>
              </div>
            ))}
          </div>
        </div>

        <div className="glass-panel signal-panel">
          <div className="panel-title"><WalletCards size={18} /> Profile base</div>
          <div className="signal-orbit">
            <div>
              <span>Average completion</span>
              <strong>{percent(snapshot.progress.avgCompletion)}%</strong>
            </div>
          </div>
          <p className="muted">{number(snapshot.progress.completedProfiles)} completed of {number(snapshot.progress.totalProfiles)} total profiles. {number(snapshot.progress.activeSubscribers)} active subscribers.</p>
        </div>

        <div className="glass-panel online-panel">
          <div className="panel-title"><Radio size={18} /> Online users</div>
          {onlineUsers.length === 0 ? (
            <p className="muted">No authenticated app heartbeats in the last 15 minutes.</p>
          ) : (
            <div className="online-user-list">
              {onlineUsers.map((user) => (
                <div className="online-user-row" key={user.user_id}>
                  <span className="online-user-pulse" />
                  <div>
                    <strong>{user.name}</strong>
                    <small>{user.email ?? user.user_id}</small>
                  </div>
                  <div className="online-user-meta">
                    <span>{user.country_code ?? "??"}</span>
                    <span>{user.platform ?? "app"}</span>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
