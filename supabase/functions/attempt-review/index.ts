// GET /attempt-review?attempt_id=...   the caller's own graded attempt.
// Read-only: it never transitions state, so opening an old result cannot
// re-grade it. Answer keys appear only once review is unlocked.
import { serve, json, requireUser, admin, sqlError, ApiError } from "../_shared/http.ts";

Deno.serve(serve(async (req) => {
  const me = await requireUser(req);
  const id = new URL(req.url).searchParams.get("attempt_id");
  if (!id) throw new ApiError("attempt_id_required", 400);

  const db = admin();
  const { data: mine, error: oe } = await db.rpc("attempt_is_mine", {
    p_attempt: id, p_user: me.id,
  });
  if (oe) throw sqlError(oe);
  if (!mine) throw new ApiError("attempt_not_found", 404);

  const { data, error } = await db.rpc("attempt_review", { p_attempt: id, p_user: me.id });
  if (error) throw sqlError(error);
  return json(data);
}));
