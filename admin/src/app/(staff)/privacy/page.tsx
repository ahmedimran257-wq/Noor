import { ChevronRight, Clock, UserRoundCheck } from "lucide-react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { SubmitButton } from "@/components/client-ui";
import { EmptyState, NoAccess, PageHeader, StatusPill, formatDate, formatDateTime, isPast } from "@/components/ui";
import { can } from "@/lib/access";
import { requireAdmin, requireArea } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export const metadata = { title: "Member rights" };

const pageSize = 30;

function viewHref(view: "open" | "resolved", page = 1, extra?: Record<string, string>) {
  const params = new URLSearchParams();
  if (view === "resolved") params.set("view", "resolved");
  if (page > 1) params.set("page", String(page));
  for (const [key, value] of Object.entries(extra ?? {})) params.set(key, value);
  const query = params.toString();
  return `/privacy${query ? `?${query}` : ""}`;
}

async function retention(form: FormData) {
  "use server";
  const admin = await requireAdmin();
  if (!can(admin.role, "holdPrivacy")) redirect("/privacy?error=role");
  const values = z.object({
    id: z.string().uuid(), reason: z.string().trim().min(10).max(500),
    until: z.union([z.literal(""), z.string().regex(/^\d{4}-\d{2}-\d{2}$/)]),
    view: z.enum(["open", "resolved"]).catch("open"),
  }).safeParse(Object.fromEntries(form));
  const view = values.success ? values.data.view : "open";
  if (!values.success) redirect(viewHref(view, 1, { error: "hold" }));
  const client = await createClient();
  const { error } = await client.rpc("set_privacy_request_hold", {
    p_id: values.data.id, p_reason: values.data.reason,
    p_until: values.data.until ? `${values.data.until}T00:00:00Z` : null,
  });
  if (error) redirect(viewHref(view, 1, { error: "hold" }));
  revalidatePath("/privacy");
  redirect(viewHref(view, 1, { retention: "1" }));
}

async function review(form: FormData) {
  "use server";
  const admin = await requireAdmin();
  if (!can(admin.role, "answerPrivacy")) redirect("/privacy?error=role");
  const values = z.object({
    id: z.string().uuid(), status: z.enum(["reviewing", "resolved"]),
    response: z.string().trim().min(10).max(2000), updated: z.string().datetime({ offset: true }),
  }).safeParse(Object.fromEntries(form));
  if (!values.success) redirect("/privacy?error=invalid");
  const client = await createClient();
  const { error } = await client.rpc("review_privacy_request", {
    p_id: values.data.id, p_status: values.data.status,
    p_response: values.data.response, p_expected_updated_at: values.data.updated,
  });
  if (error) redirect("/privacy?error=review");
  revalidatePath("/privacy");
  redirect(values.data.status === "resolved" ? "/privacy?saved=resolved" : "/privacy?saved=1");
}

const errors: Record<string, string> = {
  hold: "The retention decision was not saved. Check the date and reason, then retry.",
  invalid: "The response needs at least 10 characters. Nothing was saved.",
  review: "Unable to save. Another reviewer may have updated this request; refresh and check before retrying.",
  role: "Your staff role cannot make this change.",
};

export default async function PrivacyPage({ searchParams }: {
  searchParams: Promise<{ error?: string; saved?: string; page?: string; view?: string; retention?: string }>;
}) {
  const { admin, allowed } = await requireArea("privacy");
  if (!allowed) return <NoAccess area="Member rights" />;
  const query = await searchParams;
  const view = query.view === "resolved" ? "resolved" : "open";
  const page = Math.min(10000, Math.max(1, Number.parseInt(query.page ?? "1", 10) || 1));
  const client = await createClient();
  let requests = client.from("privacy_requests")
    .select("id,kind,status,details,response,created_at,due_at,updated_at");
  requests = view === "resolved" ? requests.eq("status", "resolved") : requests.neq("status", "resolved");
  // One extra row tells us whether a next page exists without count(*).
  const { data: rows, error } = await requests
    .order("due_at").order("id").range((page - 1) * pageSize, page * pageSize);
  const data = (rows ?? []).slice(0, pageSize);
  const hasNext = (rows?.length ?? 0) > pageSize;
  const canHold = can(admin.role, "holdPrivacy");
  const holdResult = canHold && data.length
    ? await client.rpc("get_privacy_request_holds", { p_ids: data.map((item) => item.id) })
    : { data: [], error: null };
  const holds = new Map<string, { hold_until: string; reason: string }>(
    (holdResult.data ?? []).map((hold: { request_id: string; hold_until: string; reason: string }) => [hold.request_id, hold]),
  );
  const openCount = admin.counts.privacyOpen ?? 0;
  const overdue = admin.counts.privacyOverdue ?? 0;

  return (
    <div>
      <PageHeader
        eyebrow="Trust & safety"
        title="Member rights"
        lede="Access, correction, deletion and grievance requests. Acknowledge grievances within 24 hours; the response target is 7 days. Resolving records the outcome only. It does not delete data or contact a processor."
        actions={overdue > 0 ? <span className="pill danger">{overdue} overdue</span> : <span className="pill ok">On time</span>}
      />

      <nav className="tabs" aria-label="Request status">
        <Link href={viewHref("open")} prefetch={false} className={`tab${view === "open" ? " is-active" : ""}`} aria-current={view === "open" ? "page" : undefined}>
          Open {openCount > 0 ? <span className="nav-count">{openCount}</span> : null}
        </Link>
        <Link href={viewHref("resolved")} prefetch={false} className={`tab${view === "resolved" ? " is-active" : ""}`} aria-current={view === "resolved" ? "page" : undefined}>Resolved</Link>
      </nav>

      <div className="stack">
        {query.saved ? <p role="status" className="notice ok"><span>{query.saved === "resolved" ? "Request resolved. The member can read your response under Privacy requests." : "Response saved. The member can read it under Privacy requests."}</span></p> : null}
        {query.retention ? <p role="status" className="notice ok"><span>Retention decision recorded.</span></p> : null}
        {query.error ? <p role="alert" className="notice danger"><span>{errors[query.error] ?? errors.review}</span></p> : null}
        {holdResult.error ? <p role="alert" className="notice danger"><span>Hold status could not be loaded. Do not assume a case is held; retry before any retention decision.</span></p> : null}

        {error ? (
          <section className="card"><EmptyState icon={UserRoundCheck} title="Requests could not load">Check staff access and retry. Nothing was changed.</EmptyState></section>
        ) : data.length === 0 ? (
          <section className="card">
            <EmptyState icon={UserRoundCheck} title={view === "open" ? "No open requests" : "No resolved requests on this page"}>
              {view === "open" ? "New requests from members appear here, earliest deadline first." : "Resolved requests are kept for 12 months unless a legal hold applies."}
            </EmptyState>
          </section>
        ) : data.map((item) => {
          const late = item.status !== "resolved" && isPast(item.due_at);
          const hold = holds.get(item.id);
          return (
            <article className="card" key={item.id}>
              <header className="card-head">
                <div>
                  <p className="eyebrow">{item.kind.replaceAll("_", " ")}</p>
                  <div className="row"><StatusPill status={item.status} /><span className="faint mono">{item.id}</span></div>
                </div>
                <span className={`pill ${late ? "danger" : "plain"}`}><Clock size={12} /> Due {formatDate(item.due_at)}</span>
              </header>
              <div className="card-body stack">
                <p className="quote">{item.details}</p>
                <p className="faint">Received {formatDateTime(item.created_at)}</p>
                {item.status === "resolved" ? (
                  <div><span className="cell-sub">Response sent to member</span><p>{item.response}</p></div>
                ) : (
                  <form action={review} className="stack">
                    <input type="hidden" name="id" value={item.id} />
                    <input type="hidden" name="updated" value={item.updated_at} />
                    <label className="field">Response visible to the member
                      <textarea name="response" className="textarea" required minLength={10} maxLength={2000} rows={4} defaultValue={item.response ?? ""} />
                    </label>
                    <div className="form-actions">
                      <label className="sr-only" htmlFor={`status-${item.id}`}>Status</label>
                      <select id={`status-${item.id}`} name="status" className="select" defaultValue="reviewing">
                        <option value="reviewing">Keep under review</option>
                        <option value="resolved">Resolve after action</option>
                      </select>
                      <SubmitButton className="btn btn-primary">Save response</SubmitButton>
                    </div>
                  </form>
                )}
                {canHold && !holdResult.error ? (
                  <details className="disclosure">
                    <summary className="link">{hold ? `Legal hold until ${hold.hold_until.slice(0, 10)} (UTC)` : "Retention: 12 months after resolution"}</summary>
                    <form action={retention} className="popover-form">
                      <p className="muted">Only for a documented legal obligation or claim. Holds expire and need review. Leave the date empty to release a hold. Up to one year ahead per renewal.</p>
                      <input type="hidden" name="id" value={item.id} />
                      <input type="hidden" name="view" value={view} />
                      <label className="field">Hold until (UTC)<input type="date" name="until" className="input" defaultValue={hold?.hold_until.slice(0, 10) ?? ""} /></label>
                      <label className="field">Legal reference and reason (staff only)<textarea name="reason" className="textarea" required minLength={10} maxLength={500} rows={2} defaultValue={hold?.reason ?? ""} /></label>
                      <div className="form-actions"><SubmitButton className="btn">Record decision</SubmitButton></div>
                    </form>
                  </details>
                ) : null}
              </div>
            </article>
          );
        })}

        {(page > 1 || hasNext) ? (
          <nav className="card pager" aria-label="Request pages">
            {page > 1 ? <Link href={viewHref(view, page - 1)} prefetch={false} className="link">← Previous</Link> : <span>Page 1</span>}
            {hasNext ? <Link href={viewHref(view, page + 1)} prefetch={false} className="btn btn-sm">Next <ChevronRight size={14} /></Link> : <span>Page {page}</span>}
          </nav>
        ) : null}
      </div>
    </div>
  );
}
