// POST /grant-retake  { user_id, exam_id, reason, expires_at? }   staff only
import { serve, json, requireStaff, admin, sqlError, ApiError } from "../_shared/http.ts";

Deno.serve(serve(async (req) => {
  if (req.method !== "POST") throw new ApiError("method_not_allowed", 405);
  const me = await requireStaff(req);
  const { user_id, exam_id, reason, expires_at } = await req.json().catch(() => ({}));
  if (!user_id || !exam_id) throw new ApiError("user_id_and_exam_id_required", 400);
  if (!reason || !String(reason).trim()) throw new ApiError("reason_required", 400);

  const db = admin();

  // An instructor may only act inside a track they own; admins are unrestricted.
  if (me.role === "instructor") {
    const { data: track } = await db.rpc("exam_track", { p_exam: exam_id });
    const { data: owns } = await db.from("instructor_tracks")
      .select("track_id").eq("user_id", me.id).eq("track_id", track).maybeSingle();
    if (!owns) throw new ApiError("forbidden_track", 403);
  }

  if (expires_at && new Date(expires_at).getTime()<=Date.now()) throw new ApiError('expiry_must_be_future',400);
  if (me.role==='instructor') {
    const {data:target}=await db.from('exams').select('track_id').eq('id',exam_id).single();
    const {data:groups}=await db.from('groups').select('id').eq('instructor_id',me.id).eq('track_id',target?.track_id);
    const {data:members}=await db.from('group_members').select('user_id').eq('user_id',user_id).in('group_id',(groups||[]).map(g=>g.id));
    if(!members?.length) throw new ApiError('student_outside_your_groups',403);
  }
  const { data, error } = await db.rpc("grant_retake", {
    p_user: user_id, p_exam: exam_id, p_by: me.id,
    p_reason: reason, p_expires: expires_at ?? null,
  });
  if (error) throw sqlError(error);
  return json({ grant: data }, 201);
}));
