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

// GET /me-tracks            -> tracks the caller is enrolled in, with progress
// GET /me-tracks?track=sat  -> exams available to the caller inside one track


Deno.serve(serve(async (req) => {
  const me = await requireUser(req);
  const track = new URL(req.url).searchParams.get("track");
  const db = admin();

  if (!track) {
    const { data, error } = await db.rpc("my_tracks", { p_user: me.id });
    if (error) throw sqlError(error);
    return json({ tracks: data ?? [], role: me.role });
  }

  // The track parameter is a FILTER. Eligibility is decided by my_exams,
  // which joins enrollments internally — never by trusting this value.
  const { data, error } = await db.rpc("my_exams", { p_user: me.id, p_track: track });
  if (error) throw sqlError(error);
  const {data: dashboard, error:de}=await db.rpc('student_dashboard',{p_user:me.id,p_track:track});
  if(de) throw sqlError(de);
  return json({ track, exams: data ?? [], dashboard });
}));
