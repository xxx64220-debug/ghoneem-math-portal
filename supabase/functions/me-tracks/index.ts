// GET /me-tracks            -> tracks the caller is enrolled in, with progress
// GET /me-tracks?track=sat  -> exams available to the caller inside one track
import { serve, json, requireUser, admin, sqlError } from "../_shared/http.ts";

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
