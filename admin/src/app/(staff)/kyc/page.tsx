import { requireAdmin } from "@/lib/auth";
import { getKycQueue } from "@/lib/operations";
import { reviewKyc } from "../actions";

export default async function KycPage() {
  await requireAdmin(); const queue = await getKycQueue();
  return <section className="dashboard-page"><p className="eyebrow">Verification queue</p><h1>KYC & verification</h1><p className="muted">Oldest requests appear first. Raw documents remain restricted to super-admin workflows.</p><div className="queue-list">{queue.map((item) => <article className="queue-card" key={item.user_id}><div><h2>{item.name}</h2><p className="muted">{item.country_code} · {item.kyc_id_type ?? "ID not specified"} · submitted {new Date(item.created_at).toLocaleDateString()}</p></div><strong className={(item.face_similarity ?? 0) >= .8 ? "score good" : "score"}>Face score: {item.face_similarity?.toFixed(2) ?? "N/A"}</strong><div className="action-row"><form action={reviewKyc}><input type="hidden" name="userId" value={item.user_id}/><input type="hidden" name="decision" value="approve"/><button>Approve</button></form><form action={reviewKyc}><input type="hidden" name="userId" value={item.user_id}/><input type="hidden" name="decision" value="resubmit"/><button>Request resubmission</button></form><form action={reviewKyc}><input type="hidden" name="userId" value={item.user_id}/><input type="hidden" name="decision" value="reject"/><button className="danger">Reject</button></form></div></article>)}</div></section>;
}
