// Supabase Edge Function: delete-account
//
// Deletes the *calling* user's auth account. All of their rows go with it via
// ON DELETE CASCADE (profiles, meals, meal_items, saved_foods, scan_feedback).
//
// Security:
// - The caller is identified from their own JWT (Authorization header) — a user
//   can only ever delete themselves.
// - The service-role key is read from this function's server environment
//   (Supabase injects SUPABASE_SERVICE_ROLE_KEY automatically). It never ships
//   in the Flutter app and must never be committed.
//
// Deploy:  supabase functions deploy delete-account
import { createClient } from "npm:@supabase/supabase-js@2";

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "Not signed in" }, 401);

  const url = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anonKey || !serviceRoleKey) {
    return json({ error: "Function is missing its Supabase environment" }, 500);
  }

  // Resolve the caller from their own token.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const { data, error } = await asCaller.auth.getUser();
  if (error || !data.user) return json({ error: "Not signed in" }, 401);

  // Privileged delete, server-side only.
  const admin = createClient(url, serviceRoleKey, { auth: { persistSession: false } });
  const { error: deleteError } = await admin.auth.admin.deleteUser(data.user.id);
  if (deleteError) return json({ error: deleteError.message }, 500);

  return json({ deleted: true }, 200);
});
