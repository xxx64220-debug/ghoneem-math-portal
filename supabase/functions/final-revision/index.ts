import { admin, ApiError, json, requireUser, serve, sqlError } from "../_shared/http.ts";

Deno.serve(serve(async (req) => {
  if (req.method !== "POST") throw new ApiError("method_not_allowed", 405);
  const me = await requireUser(req);
  if (me.role !== "student") throw new ApiError("student_account_required", 403);
  const body = await req.json().catch(() => null);
  if (!body || !["sat", "est"].includes(body.track)) throw new ApiError("invalid_track", 400);
  if (!["catalogue", "start", "answer", "state"].includes(body.action)) throw new ApiError("invalid_action", 400);
  const { data, error } = await admin().rpc("final_revision", {
    p_user: me.id, p_track: body.track, p_action: body.action,
    p_options: Object.fromEntries(["session", "question", "answer", "scope", "source", "difficulty", "lesson", "count", "retry"]
      .filter(key => body[key] !== undefined).map(key => [key, body[key]])),
  });
  if (error) throw sqlError(error);
  return json(data);
}));
