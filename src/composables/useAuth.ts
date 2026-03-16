import { supabase } from "@/supabase";
import { ref } from "vue";
import type { User } from "@supabase/supabase-js";

export function useAuth() {
  const user = ref<User | null>(null); // ← cambia null por User | null
  const error = ref<string | null>(null);
  const loading = ref(false);

  // ... resto del código igual
  // Registrar
  async function registrar(email: string, password: string) {
    loading.value = true;
    const { data, error: err } = await supabase.auth.signUp({
      email,
      password,
    });
    console.log("data:", data); // ← agrega esto
    console.log("error:", err); // ← agrega esto
    if (err) error.value = err.message;
    else user.value = data.user;
    loading.value = false;
  }

  // Iniciar sesión
  async function login(email: string, password: string) {
    loading.value = true;
    const { data, error: err } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (err) error.value = err.message;
    else user.value = data.user;
    loading.value = false;
  }

  // Cerrar sesión
  async function logout() {
    await supabase.auth.signOut();
    user.value = null;
  }

  // Obtener sesión activa
  async function obtenerSesion() {
    const { data } = await supabase.auth.getSession();
    user.value = data.session?.user ?? null;
  }

  return {
    user,
    error,
    loading,
    registrar,
    login,
    logout,
    obtenerSesion,
  };
}
