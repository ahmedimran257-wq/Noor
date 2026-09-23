import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireAdmin } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

async function retention(form: FormData) {
  "use server";
  const admin = await requireAdmin();
  if (admin.role !== "super_admin") redirect("/unauthorized");
  const values = z.object({
    id: z.string().uuid(), reason: z.string().trim().min(10).max(500),
    until: z.union([z.literal(""), z.string().regex(/^\d{4}-\d{2}-\d{2}$/)]),
  }).safeParse(Object.fromEntries(form));
  if (!values.success) redirect("/privacy?error=hold");
  const client = await createClient();
  const { error } = await client.rpc("set_privacy_request_hold", {
    p_id: values.data.id, p_reason: values.data.reason,
    p_until: values.data.until ? `${values.data.until}T00:00:00Z` : null,
  });
  if (error) redirect("/privacy?error=hold");
  revalidatePath("/privacy");
  redirect("/privacy?retention=1&view=resolved");
}

async function review(form: FormData) {
  "use server";
  const admin = await requireAdmin();
  if (!["super_admin", "support"].includes(admin.role)) redirect("/unauthorized");
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
  redirect("/privacy?saved=1");
}

export default async function PrivacyPage({ searchParams }: {
  searchParams: Promise<{ error?: string; saved?: string; page?: string; view?: string; retention?: string }>;
}) {
  const admin = await requireAdmin();
  if (!["super_admin", "support"].includes(admin.role)) redirect("/unauthorized");
  const query = await searchParams;
  const resolved = query.view === "resolved";
  const page = Math.min(10000, Math.max(1, Number.parseInt(query.page ?? "1", 10) || 1));
  const client = await createClient();
  let requests = client.from("privacy_requests")
    .select("id,kind,status,details,response,created_at,due_at,updated_at", { count: "exact" });
  requests = resolved ? requests.eq("status", "resolved") : requests.neq("status", "resolved");
  const { data, error, count } = await requests
    .order("due_at").order("id").range((page - 1) * 30, page * 30 - 1);
  const holdResult = admin.role === "super_admin" && data?.length
    ? await client.rpc("get_privacy_request_holds", { p_ids: data.map(item => item.id) })
    : { data: [], error: null };
  const holds = new Map<string, { hold_until: string; reason: string }>(
    (holdResult.data ?? []).map((hold: { request_id: string; hold_until: string; reason: string }) => [hold.request_id, hold]),
  );
  return <section className="dashboard-page wide-page">
    <div className="page-hero"><div><p className="eyebrow">Trust / Privacy</p><h1>Member rights</h1>
      <p className="muted">Every request has a reference, response target and recorded outcome.</p></div>
      <span className="status-pill">{count ?? "—"} requests</span></div>
    <nav className="pagination-row" aria-label="Request status">
      <a href="/privacy" aria-current={!resolved ? "page" : undefined}>Open requests</a>
      <a href="/privacy?view=resolved" aria-current={resolved ? "page" : undefined}>Resolved</a>
    </nav>
    {query.saved && <p role="status" className="action-notice">Response saved. The member can read it in Privacy requests.</p>}
    {query.retention && <p role="status" className="action-notice">Retention hold updated and recorded.</p>}
    {holdResult.error && <p role="alert" className="action-notice danger">Hold status is unavailable. Do not assume a case is held; retry before making a retention decision.</p>}
    {query.error && <p role="alert" className="action-notice danger">Unable to save. Check the response, refresh, and retry; another reviewer may have updated this request.</p>}
    <div className="photo-check-review-rule">Review daily. Acknowledge grievances within 24 hours. The response target is 7 days; urgent safety complaints have separate, shorter deadlines. Resolving a card records an outcome—it does not perform deletion or contact a processor.</div>
    {error ? <p role="alert">Privacy requests are unavailable. Verify the database migration and staff access.</p> :
      <div className="queue-list">{data?.map(item => <article className="elevated-panel privacy-case" key={item.id}>
        <header><div><p className="eyebrow">{item.kind}</p><h2>{item.status}</h2></div>
          <span className={`status-pill ${item.status !== "resolved" && new Date(item.due_at) < new Date() ? "danger" : ""}`}>Due {new Date(item.due_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" })}</span></header>
        <p className="muted">Reference <code>{item.id}</code></p>
        <p className="privacy-case-details">{item.details}</p>
        {item.status === "resolved" ? <p>{item.response}</p> : <form action={review}>
          <input type="hidden" name="id" value={item.id} /><input type="hidden" name="updated" value={item.updated_at} />
          <label>Response visible to the member<textarea name="response" required minLength={10} maxLength={2000} rows={4} defaultValue={item.response} /></label>
          <div className="privacy-case-actions"><label>Status<select name="status" defaultValue="reviewing"><option value="reviewing">Under review</option><option value="resolved">Resolved after action</option></select></label>
          <button className="primary-button compact-button">Save response</button></div>
        </form>}
        {admin.role === "super_admin" && !holdResult.error && <details className="privacy-retention">
          <summary>{holds.has(item.id) ? `Legal hold until ${holds.get(item.id)!.hold_until.slice(0, 10)} UTC` : "Retention: 12 months after resolution"}</summary>
          <p className="muted">Use only for a documented legal obligation or claim. Holds expire and require review; unresolved requests are not automatically erased. Leave the date blank to release a hold. Dates use UTC; maximum one year ahead per renewal.</p>
          <form action={retention}>
            <input type="hidden" name="id" value={item.id} />
            <label>Hold until (UTC)<input type="date" name="until" defaultValue={holds.get(item.id)?.hold_until.slice(0, 10) ?? ""} /></label>
            <label>Legal reference and reason (staff only)<textarea name="reason" required minLength={10} maxLength={500} rows={2} defaultValue={holds.get(item.id)?.reason ?? ""} /></label>
            <button className="primary-button compact-button">Record hold decision</button>
          </form>
        </details>}
      </article>)}{data?.length === 0 && <div className="photo-check-empty"><span>Privacy desk</span><h2>No requests on this page</h2><p>New authenticated requests will appear here.</p></div>}</div>}
    <nav className="pagination-row" aria-label="Privacy request pages">
      {page > 1 && <a href={`/privacy?view=${resolved ? "resolved" : "open"}&page=${page - 1}`}>Previous</a>}
      <span>Page {page}</span>{page * 30 < (count ?? 0) && <a href={`/privacy?view=${resolved ? "resolved" : "open"}&page=${page + 1}`}>Next</a>}
    </nav>
  </section>;
}
