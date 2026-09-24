// POST /start-attempt  { exam_id }
// Creates the attempt (all eligibility checked inside SQL, in one transaction)
// and returns the question payload with answer keys stripped.
import { serve, json, requireUser, admin, sqlError, ApiError, clientIp } from "../_shared/http.ts";

Deno.serve(serve(async (req) => {
  if (req.method !== "POST") throw new ApiError("method_not_allowed", 405);
  const me = await requireUser(req);
  const { exam_id, untimed } = await req.json().catch(() => ({}));
  if (!exam_id) throw new ApiError("exam_id_required", 400);

  if (me.role !== 'student') throw new ApiError('student_account_required',403);
  const db = admin();
  const {error:limit} = await db.rpc('portal_rate_limit',{p_user:me.id,p_action:'start'});
  if(limit) throw new ApiError('rate_limit_exceeded',429);

  const { data: att, error } = await db.rpc("portal_start_attempt", { p_exam: exam_id, p_user: me.id, p_untimed: untimed === true });
  if (error) throw sqlError(error);

  await db.from("attempts").update({ ip: clientIp(req), user_agent: req.headers.get("user-agent") })
    .eq("id", att.id);

  const { data: payload, error: pe } = await db.rpc("attempt_payload", {
    p_attempt: att.id, p_user: me.id,
  });
  if (pe) throw sqlError(pe);

  // Stable per-attempt ordering; original choice IDs remain authoritative for grading.
  if (payload.exam.shuffle) {
    const seed=String(payload.attempt.shuffle_seed);
    const rank=async (s:string)=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(seed+s)))).map(b=>b.toString(16).padStart(2,'0')).join('');
    const qs=await Promise.all(payload.questions.map(async(q:any)=>({...q,_rank:await rank(q.id),choices:await Promise.all(q.choices.map(async(c:any)=>({...c,_rank:await rank(q.id+c.key)})))})));
    qs.sort((a,b)=>a._rank.localeCompare(b._rank));
    payload.questions=qs.map(q=>{ delete q._rank;q.choices.sort((a:any,b:any)=>a._rank.localeCompare(b._rank));q.choices.forEach((c:any)=>delete c._rank);return q;});
  }
  return json(payload, 201);
}));
