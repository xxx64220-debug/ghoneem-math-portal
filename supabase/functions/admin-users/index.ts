// POST /admin-users   { username, password, full_name, role?, tracks: [] }  admin only
// Creates the auth user, the profile row, and the track enrollments in one call,
// so student onboarding never requires the Supabase dashboard.
import { serve, json, requireAdmin, admin, ApiError } from "../_shared/http.ts";

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
