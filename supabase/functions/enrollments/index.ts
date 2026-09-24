// POST   /enrollments  { user_id, track_id }   admin only — enrol
// DELETE /enrollments  { user_id, track_id }   admin only — un-enrol
import { serve, json, requireAdmin, admin, ApiError } from "../_shared/http.ts";

Deno.serve(serve(async (req) => {
  const me = await requireAdmin(req);
  const { user_id, track_id } = await req.json().catch(() => ({}));
  if (!user_id || !track_id) throw new ApiError("user_id_and_track_id_required", 400);
  const db = admin();

  if (req.method === "POST") {
    // enrolment + cohort membership + audit row, all inside the RPC
    const { error } = await db.rpc("enrol_student",
      { p_user: user_id, p_track: track_id, p_by: me.id });
    if (error) throw new ApiError(error.message, 400);
    return json({ user_id, track_id, status: "active" }, 201);
  }

  if (req.method === "DELETE") {
    // Suspend rather than delete: history stays attributable.
    const { error } = await db.from("enrollments")
      .update({ status: "paused" }).eq("user_id", user_id).eq("track_id", track_id);
    if (error) throw new ApiError(error.message, 400);
    await db.from("audit_log").insert({
      actor_id: me.id, action: "enrollment.paused", target_type: "user",
      target_id: user_id, meta: { track_id },
    });
    return json({ user_id, track_id, status: "paused" });
  }

  throw new ApiError("method_not_allowed", 405);
}));
