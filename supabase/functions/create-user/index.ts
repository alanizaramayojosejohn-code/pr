// ============================================================================
// create-user — alta de cuentas con service_role
// ============================================================================
// Solo admin. Crea user | instructor | admin, y puede asignarle instructor a un
// cliente.
//
// El instructor ya no da de alta a nadie: el alumno se registra solo y las dos
// partes se vinculan por solicitud (`send_link_request` /
// `respond_link_request`). Esta función queda para el panel de administración,
// que sigue necesitando service_role para escribir en `auth.users`.
//
// El rol se lee de la base, nunca del JWT ni del body.
// ============================================================================

import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_TRIAL_DAYS = 30;

type Role = "user" | "instructor" | "admin";

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });
}

function fail(message: string, status: number) {
  return json({ error: message }, status);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return fail("Método no permitido", 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  // ── Quién llama ───────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return fail("Falta el token", 401);

  const asCaller = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
  const { data: userData, error: userErr } = await asCaller.auth.getUser();
  if (userErr || !userData.user) return fail("Sesión inválida", 401);

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const { data: caller } = await admin
    .from("profiles")
    .select("id, role, status")
    .eq("id", userData.user.id)
    .single();

  if (!caller || caller.status !== "approved" || caller.role !== "admin") {
    return fail("Cuenta sin permisos para crear usuarios", 403);
  }

  // ── Qué pide ──────────────────────────────────────────────────────────────
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return fail("Body inválido", 400);
  }

  const email = String(body.email ?? "").trim().toLowerCase();
  const password = String(body.password ?? "");
  if (!/^\S+@\S+\.\S+$/.test(email)) return fail("Email inválido", 400);
  if (password.length < 6) {
    return fail("La contraseña debe tener al menos 6 caracteres", 400);
  }

  const requested = String(body.role ?? "user");
  if (!["user", "instructor", "admin"].includes(requested)) {
    return fail("Rol inválido", 400);
  }
  const role = requested as Role;
  const instructorId = body.instructor_id ? String(body.instructor_id) : null;

  if (instructorId && role !== "user") {
    return fail("Solo un cliente puede tener instructor asignado", 400);
  }
  if (instructorId) {
    const { data: instructor } = await admin
      .from("profiles")
      .select("id, role")
      .eq("id", instructorId)
      .single();
    if (!instructor || instructor.role !== "instructor") {
      return fail("El instructor indicado no existe", 400);
    }
  }

  const trialDays = Number(body.trial_days ?? DEFAULT_TRIAL_DAYS);
  const expiresAt = role === "user"
    ? new Date(Date.now() + trialDays * 24 * 60 * 60 * 1000).toISOString()
    : null;

  // ── Alta ──────────────────────────────────────────────────────────────────
  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });

  if (createErr || !created.user) {
    const msg = createErr?.message ?? "No se pudo crear el usuario";
    const alreadyExists = /already (been )?registered|already exists/i.test(msg);
    return fail(
      alreadyExists ? "Ya existe una cuenta con ese email" : msg,
      alreadyExists ? 409 : 400,
    );
  }

  // upsert y no insert: si el proyecto tuviera un trigger que ya creó la fila,
  // un insert chocaría con la PK y dejaría la cuenta a medio crear.
  const { error: profileErr } = await admin.from("profiles").upsert({
    id: created.user.id,
    email,
    role,
    status: "approved",
    expires_at: expiresAt,
    instructor_id: instructorId,
  });

  if (profileErr) {
    // Sin perfil la cuenta no sirve para nada y bloquearía el email: se revierte.
    await admin.auth.admin.deleteUser(created.user.id);
    return fail(`No se pudo crear el perfil: ${profileErr.message}`, 400);
  }

  return json({
    user: {
      id: created.user.id,
      email,
      role,
      status: "approved",
      expires_at: expiresAt,
      instructor_id: instructorId,
    },
  });
});
