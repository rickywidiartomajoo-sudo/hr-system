// supabase/functions/update-role/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const VALID_ROLES = ["admin", "hr", "employee"];

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
    if (!callerProfile || callerProfile.role !== "admin") {
      return new Response(JSON.stringify({ error: "Forbidden — hanya admin yang boleh mengubah role" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { user_id, new_role } = await req.json();
    if (!user_id || !VALID_ROLES.includes(new_role)) {
      return new Response(JSON.stringify({ error: "user_id dan new_role (admin/hr/employee) wajib diisi" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    if (user_id === caller.id) {
      return new Response(JSON.stringify({ error: "Tidak bisa mengubah role sendiri" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { error: updErr } = await admin.from("profiles").update({ role: new_role }).eq("id", user_id);
    if (updErr) throw updErr;

    await admin.from("activity_logs").insert({
      actor_id: caller.id,
      action: "update_role",
      description: `Mengubah role karyawan (${user_id}) menjadi ${new_role}`,
    });

    return new Response(JSON.stringify({ ok: true }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message ?? String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
