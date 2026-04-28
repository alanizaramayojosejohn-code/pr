import { supabase } from "@/supabase";
import { computed, ref } from "vue";
import type { User } from "@supabase/supabase-js";

export interface Profile {
  id: string;
  email: string | null;
  role: "user" | "admin";
  status: "approved" | "blocked";
  expires_at: string | null;
  created_at: string;
}

const user = ref<User | null>(null);
const profile = ref<Profile | null>(null);
const error = ref<string | null>(null);
const loading = ref(false);
const ready = ref(false);
const blockedMessage = ref<string | null>(null);

const isLoggedIn = computed(() => user.value !== null);
const isAdmin = computed(() => profile.value?.role === "admin");

async function loadProfile(userId: string): Promise<Profile | null> {
  const { data, error: err } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", userId)
    .single();
  if (err) {
    profile.value = null;
    return null;
  }
  profile.value = data as Profile;
  return profile.value;
}

async function enforceStatus(p: Profile | null) {
  if (!p) return;
  if (p.status === "blocked") {
    blockedMessage.value = "Tu cuenta está bloqueada. Contacta al administrador.";
    await supabase.auth.signOut();
    user.value = null;
    profile.value = null;
  }
}

async function initAuth() {
  const { data } = await supabase.auth.getSession();
  user.value = data.session?.user ?? null;
  if (user.value) {
    const p = await loadProfile(user.value.id);
    await enforceStatus(p);
  }
  ready.value = true;

  supabase.auth.onAuthStateChange(async (_event, session) => {
    user.value = session?.user ?? null;
    if (user.value) {
      const p = await loadProfile(user.value.id);
      await enforceStatus(p);
    } else {
      profile.value = null;
    }
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
    const p = await loadProfile(data.user.id);
    if (p?.status === "blocked") {
      await supabase.auth.signOut();
      user.value = null;
      profile.value = null;
      error.value = "Tu cuenta está bloqueada. Contacta al administrador.";
    }
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
