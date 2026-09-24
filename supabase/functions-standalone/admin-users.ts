// =====================================================================
//  SAT & EST Exam Portal — shared Edge Function helpers
//  Abdelrahman Ghoneem | 01116004434
// =====================================================================
import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Set ALLOWED_ORIGIN to your deployed site to lock this down.
const ORIGIN = Deno.env.get("ALLOWED_ORIGIN") ?? "https://ghoneem-exam-portal.xxx64220.chatgpt.site";

export const cors = {
  "Access-Control-Allow-Origin": ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, idempotency-key",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  "Vary": "Origin",
};

export function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, ...extra, "Content-Type": "application/json" },
  });
}

export function preflight(req: Request) {
  return req.method === "OPTIONS" ? new Response("ok", { headers: cors }) : null;
}

/** Service-role client. Bypasses RLS — never hand this to the browser. */
export function admin(): SupabaseClient {
  return createClient(URL_, SERVICE, { auth: { persistSession: false } });
}

export type Caller = { id: string; role: "student" | "instructor" | "admin"; status: string };

/**
 * Verifies the caller's JWT and loads their profile.
 * Throws ApiError on a missing/!invalid token or a suspended account.
 */
export async function requireUser(req: Request): Promise<Caller> {
  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) throw new ApiError("missing_token", 401);

  const asUser = createClient(URL_, ANON, {
    global: { headers: { Authorization: auth } },
    auth: { persistSession: false },
  });
  const { data, error } = await asUser.auth.getUser();
  if (error || !data?.user) throw new ApiError("invalid_token", 401);

  const { data: prof, error: pe } = await admin()
    .from("profiles").select("id, role, status").eq("id", data.user.id).single();
  if (pe || !prof) throw new ApiError("no_profile", 403);
  if (prof.status !== "active") throw new ApiError("account_suspended", 403);

  const token = auth.slice(7);
  let sessionId: string;
  try { sessionId = JSON.parse(atob(token.split('.')[1].replace(/-/g,'+').replace(/_/g,'/'))).session_id; }
  catch { throw new ApiError('invalid_token',401); }
  if (!sessionId) throw new ApiError('invalid_session',401);
  const { error: se } = await admin().rpc('portal_session', {p_user:prof.id,p_session:sessionId,p_agent:req.headers.get('user-agent')||''});
  if (se) throw new ApiError(se.message,403);
  return prof as Caller;
}

export async function requireStaff(req: Request): Promise<Caller> {
  const c = await requireUser(req);
  if (c.role !== "admin" && c.role !== "instructor") throw new ApiError("forbidden", 403);
  return c;
}

export async function requireAdmin(req: Request): Promise<Caller> {
  const c = await requireUser(req);
  if (c.role !== "admin") throw new ApiError("forbidden", 403);
  return c;
}

export class ApiError extends Error {
  status: number;
  extra: Record<string, unknown>;
  constructor(msg: string, status = 400, extra: Record<string, unknown> = {}) {
    super(msg);
    this.status = status;
    this.extra = extra;
  }
}

/** Maps the exceptions raised inside the SQL layer onto HTTP status codes. */
const SQL_STATUS: Record<string, number> = {
  exam_not_found: 404,
  attempt_not_found: 404,
  exam_not_published: 403,
  not_enrolled_in_track: 403,
  not_assigned_or_window_closed: 403,
  account_suspended: 403,
  attempt_limit_reached: 403,
  already_submitted: 409,
  attempt_still_live: 409,
};

/** Extracts the bare error tag from a Postgres error surfaced by PostgREST. */
export function sqlError(e: { message?: string } | null): ApiError {
  const raw = e?.message ?? "unknown_error";
  const tag = Object.keys(SQL_STATUS).find((k) => raw.includes(k));
  return tag ? new ApiError(tag, SQL_STATUS[tag]) : new ApiError(raw, 400);
}

/** Wraps a handler so every thrown ApiError becomes a clean JSON response. */
export function serve(handler: (req: Request) => Promise<Response>) {
  return async (req: Request): Promise<Response> => {
    const pf = preflight(req);
    if (pf) return pf;
    try {
      return await handler(req);
    } catch (err) {
      if (err instanceof ApiError) {
        return json({ error: err.message, ...err.extra }, err.status);
      }
      console.error("unhandled", err);
      return json({ error: "internal_error" }, 500);
    }
  };
}

/** Best-effort client IP, for the attempt audit trail. */
export function clientIp(req: Request): string | null {
  const h = req.headers.get("x-forwarded-for");
  return h ? h.split(",")[0].trim() : null;
}

// POST /admin-users   { username, password, full_name, role?, tracks: [] }  admin only
// Creates the auth user, the profile row, and the track enrollments in one call,
// so student onboarding never requires the Supabase dashboard.


const DOMAIN = Deno.env.get("STUDENT_EMAIL_DOMAIN") ?? "students.ghoneem-math.com";

Deno.serve(serve(async (req) => {
  if (req.method !== "POST") throw new ApiError("method_not_allowed", 405);
  const me = await requireAdmin(req);
  const b = await req.json().catch(() => ({}));

  const username = String(b.username ?? "").trim().toLowerCase();
  const explicitEmail = String(b.email ?? "").trim().toLowerCase();
  if (!explicitEmail && !/^[a-z0-9._-]{3,32}$/.test(username)) throw new ApiError("invalid_username", 400);
  if (!b.password || String(b.password).length < 8) throw new ApiError("weak_password", 400);

  const role = b.role ?? "student";
  if (!["student", "instructor", "admin"].includes(role)) throw new ApiError("invalid_role", 400);

  const db = admin();
  const email = explicitEmail || `${username}@${DOMAIN}`;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw new ApiError('invalid_email',400);
  const requestedTracks: string[] = Array.isArray(b.tracks) ? [...new Set(b.tracks)] : [];
  const {data: validTracks,error:te}=await db.from('tracks').select('id').in('id',requestedTracks).eq('is_active',true);
  if(te || (validTracks||[]).length!==requestedTracks.length) throw new ApiError('invalid_tracks',400);

  const { data: created, error: ce } = await db.auth.admin.createUser({
    email, password: String(b.password), email_confirm: true,
    user_metadata: { username, full_name: b.full_name ?? username },
  });
  if (ce) throw new ApiError(ce.message, 400);
  const uid = created.user.id;

  const { error: pe } = await db.from("profiles")
    .upsert({ id: uid, full_name: b.full_name ?? username, role, email, status: "active" });
  if (pe) {
    await db.auth.admin.deleteUser(uid);       // no orphan auth rows
    throw new ApiError(pe.message, 400);
  }

  // enrol_student() writes the enrollment AND the cohort membership in one
  // transaction. Writing enrollments directly would leave the student in no
  // cohort, which shows up as "no exams" and is painful to diagnose.
  const tracks: string[] = requestedTracks;
  for (const t of tracks) {
    const { error: ee } = await db.rpc("enrol_student",
      { p_user: uid, p_track: t, p_by: me.id });
    if (ee) { await db.auth.admin.deleteUser(uid); throw new ApiError(ee.message,400); }
  }

  await db.from("audit_log").insert({
    actor_id: me.id, action: "user.created", target_type: "user", target_id: uid,
    meta: { username, role, tracks },
  });

  return json({ user_id: uid, username, email, role, tracks }, 201);
}));
