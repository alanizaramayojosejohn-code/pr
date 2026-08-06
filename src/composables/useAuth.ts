import { supabase } from "@/supabase";
import { computed, ref } from "vue";
import type { User } from "@supabase/supabase-js";

export type Role = "user" | "instructor" | "admin";

export interface Profile {
  id: string;
  email: string | null;
  role: Role;
  status: "approved" | "blocked";
  expires_at: string | null;
  created_at: string;
  /** Instructor a cargo. Solo lo llevan los clientes. */
  instructor_id: string | null;
}

const user = ref<User | null>(null);
const profile = ref<Profile | null>(null);
const error = ref<string | null>(null);
const loading = ref(false);
const ready = ref(false);
const blockedMessage = ref<string | null>(null);

const isLoggedIn = computed(() => user.value !== null);
const isAdmin = computed(() => profile.value?.role === "admin");

const ADMIN_ONLY_MESSAGE =
  "Este panel es solo para administradores. Usá la app de Android para entrenar.";

const INSTRUCTOR_MESSAGE =
  "Los instructores gestionan a sus clientes desde la app de Android.";

async function loadProfile(u: User): Promise<Profile | null> {
  const { data, error: err } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", u.id)
    .single();

  if (data) {
    profile.value = data as Profile;
    return profile.value;
  }

  // PGRST116 = fila no encontrada → usuario nuevo (ej. Google OAuth)
  if (err?.code === "PGRST116") {
    const { data: created } = await supabase
      .from("profiles")
      .insert({ id: u.id, email: u.email ?? null, role: "user", status: "approved" })
      .select()
      .single();
    profile.value = (created as Profile) ?? null;
    return profile.value;
  }

  // Error inesperado (red, RLS): se conserva el perfil ya cargado. Borrarlo
  // dejaría isAdmin en false y, como el guard ahora exige admin, un bache de
  // red al refrescar el token echaría al administrador al login.
  return null;
}

async function clearSession() {
  await supabase.auth.signOut();
  user.value = null;
  profile.value = null;
}

/**
 * Este sitio es únicamente el panel de administración; la app de Android es la
 * que usan los clientes. Cualquiera que llegue aquí sin rol admin —una sesión
 * vieja guardada en el navegador, o alguien que descubra /admin— se va fuera.
 */
async function enforceAccess(p: Profile | null) {
  if (!p) return;
  if (p.status === "blocked") {
    blockedMessage.value = "Tu cuenta está bloqueada. Contacta al administrador.";
    await clearSession();
    return;
  }
  if (p.role !== "admin") {
    blockedMessage.value =
      p.role === "instructor" ? INSTRUCTOR_MESSAGE : ADMIN_ONLY_MESSAGE;
    await clearSession();
  }
}

/**
 * Carga el perfil y aplica el filtro de acceso, deduplicando llamadas
 * simultáneas: al iniciar sesión esto se dispara dos veces —desde login() y
 * desde onAuthStateChange— y no hace falta ir dos veces a la base.
 */
let syncing: Promise<void> | null = null;
function syncProfile(u: User): Promise<void> {
  if (syncing) return syncing;
  syncing = (async () => {
    const p = await loadProfile(u);
    await enforceAccess(p);
  })().finally(() => {
    syncing = null;
  });
  return syncing;
}

async function initAuth() {
  const { data } = await supabase.auth.getSession();
  user.value = data.session?.user ?? null;
  if (user.value) {
    await syncProfile(user.value);
  }
  ready.value = true;

  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user ?? null;
    if (!user.value) {
      profile.value = null;
      return;
    }
    // Este callback se despacha con el lock interno de supabase-js tomado:
    // consultar la base o llamar a signOut() aquí dentro se autobloquea hasta
    // que el lock expira, y la app se queda colgada. setTimeout saca el trabajo
    // fuera del callback, que debe retornar de forma síncrona.
    const u = user.value;
    setTimeout(() => {
      void syncProfile(u);
    }, 0);
  });
}

const initPromise = initAuth();

async function login(email: string, password: string) {
  loading.value = true;
  error.value = null;
  blockedMessage.value = null;
  const { data, error: err } = await supabase.auth.signInWithPassword({
    email,
    password,
  });
  if (err) {
    error.value = traducirError(err.message);
    loading.value = false;
    return;
  }
  user.value = data.user;
  if (data.user) {
    // Cierra la sesión y deja el motivo en blockedMessage si no pasa el filtro.
    await syncProfile(data.user);
  }
  loading.value = false;
}

async function logout() {
  await supabase.auth.signOut();
  user.value = null;
  profile.value = null;
  blockedMessage.value = null;
}

async function changePassword(newPassword: string) {
  loading.value = true;
  error.value = null;
  const { error: err } = await supabase.auth.updateUser({ password: newPassword });
  loading.value = false;
  if (err) {
    error.value = traducirError(err.message);
    return false;
  }
  return true;
}

function traducirError(msg: string): string {
  const m = msg.toLowerCase();
  if (m.includes("invalid login credentials")) return "Email o contraseña incorrectos.";
  if (m.includes("email not confirmed")) return "Confirma tu email antes de entrar.";
  if (m.includes("rate limit")) return "Demasiados intentos. Espera un momento.";
  return msg;
}

export function useAuth() {
  return {
    user,
    profile,
    error,
    loading,
    ready,
    isLoggedIn,
    isAdmin,
    blockedMessage,
    initPromise,
    login,
    logout,
    changePassword,
  };
}
