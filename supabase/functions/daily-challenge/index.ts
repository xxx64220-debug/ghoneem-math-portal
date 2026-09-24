import { admin, ApiError, json, requireUser, serve, sqlError } from "../_shared/http.ts";

// The SQL routines own the date, frozen daily question set, grading and points.
// Only a verified student JWT supplies the user ID; the browser never sees keys
// until its one submission for the Cairo calendar day has been recorded.
Deno.serve(serve(async (req) => {
  if (req.method !== "GET" && req.method !== "POST")
    throw new ApiError("method_not_allowed", 405);
  const me = await requireUser(req);
  if (me.role !== "student") throw new ApiError("student_account_required", 403);
  const payload = req.method === "POST" ? await req.json().catch(() => ({})) : null;
  const requestUrl = req.method === "GET" ? new URL(req.url) : null;
  const track = requestUrl ? requestUrl.searchParams.get("track") : payload?.track;
  if (!["sat", "est", "est2"].includes(track)) throw new ApiError("invalid_track", 400);

  const db = admin();
  let result;
  if (req.method === "GET" && requestUrl?.searchParams.get("view") === "mistakes") {
    result = await db.rpc("student_daily_quiz_mistakes", { p_user: me.id, p_track: track });
  } else if (req.method === "GET") {
    result = await db.rpc("daily_state", { p_user: me.id, p_track: track });
  } else if (payload?.action === "submit") {
    if (!payload.answers || typeof payload.answers !== "object" || Array.isArray(payload.answers))
      throw new ApiError("invalid_answers", 400);
    result = await db.rpc("daily_submit", {
      p_user: me.id, p_track: track, p_answers: payload.answers,
    });
  } else if (payload?.action === "mark" && ["focus", "review"].includes(payload.task)) {
    result = await db.rpc("daily_mark", {
      p_user: me.id, p_track: track, p_task: payload.task,
    });
  } else throw new ApiError("invalid_action", 400);
  if (result.error) throw sqlError(result.error);
  return json(result.data);
}));
