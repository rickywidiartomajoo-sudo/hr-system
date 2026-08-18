// supabase/functions/update-user/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization") ?? "";
    const callerClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller } } = await callerClient.auth.getUser();
    if (!caller) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: callerProfile } = await admin.from("profiles").select("role").eq("id", caller.id).single();
    if (!callerProfile || !["admin", "hr"].includes(callerProfile.role)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { user_id, full_name, email, position_title, division, is_active } = await req.json();
    if (!user_id) {
      return new Response(JSON.stringify({ error: "user_id wajib diisi" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const updates: Record<string, unknown> = {};
    if (full_name !== undefined) updates.full_name = full_name;
    if (email !== undefined) updates.email = email;
    if (position_title !== undefined) updates.position_title = position_title;
    if (division !== undefined) updates.division = division;
    if (is_active !== undefined) updates.is_active = is_active;

    if (Object.keys(updates).length > 0) {
      const { error: profileErr } = await admin.from("profiles").update(updates).eq("id", user_id);
      if (profileErr) throw profileErr;
    }

    // keep auth.users email in sync if it changed
    if (email !== undefined) {
      const { error: authErr } = await admin.auth.admin.updateUserById(user_id, { email });
      if (authErr) throw authErr;
    }

    await admin.from("activity_logs").insert({
      actor_id: caller.id,
      action: "update_user",
      description: `Memperbarui data karyawan (${user_id})`,
    });

    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message ?? String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
