// supabase/functions/create-user/index.ts
import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Client using the caller's own JWT, just to find out who is calling
    const authHeader = req.headers.get("Authorization") ?? "";
    const callerClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user: caller } } = await callerClient.auth.getUser();
    if (!caller) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // Admin client with full service_role privileges (bypasses RLS)
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // Only admin/hr may create employees
    const { data: callerProfile } = await admin.from("profiles").select("role").eq("id", caller.id).single();
    if (!callerProfile || !["admin", "hr"].includes(callerProfile.role)) {
      return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { email, password, full_name, position_title, division, role } = await req.json();
    if (!email || !password || !full_name) {
      return new Response(JSON.stringify({ error: "email, password, full_name wajib diisi" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }
    if (password.length < 6) {
      return new Response(JSON.stringify({ error: "Password minimal 6 karakter" }), { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // 1. Create the auth user
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });
    if (createErr) throw createErr;

    // 2. Create the matching profile row
    const { error: profileErr } = await admin.from("profiles").insert({
      id: created.user.id,
      full_name,
      email,
      position_title: position_title ?? null,
      division: division ?? null,
      role: role ?? "employee",
      is_active: true,
    });
    if (profileErr) {
      // roll back the auth user if the profile insert fails
      await admin.auth.admin.deleteUser(created.user.id);
      throw profileErr;
    }

    // 3. Log the activity
    await admin.from("activity_logs").insert({
      actor_id: caller.id,
      action: "create_user",
      description: `Menambahkan karyawan baru: ${full_name}`,
    });

    return new Response(JSON.stringify({ user_id: created.user.id }), { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message ?? String(err) }), { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } });
  }
});
