import { computed, ref } from "vue";
import { supabase } from "@/supabase";
import type { Profile } from "./useAuth";

export function daysUntil(iso: string | null): number | null {
  if (!iso) return null;
  const ms = new Date(iso).getTime() - Date.now();
  return Math.ceil(ms / (1000 * 60 * 60 * 24));
}

export function useUsers() {
  const users = ref<Profile[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  const expiringSoon = computed(() =>
    users.value.filter((u) => {
      if (u.role !== "user" || u.status !== "approved") return false;
      const d = daysUntil(u.expires_at);
      return d !== null && d >= 0 && d <= 7;
    })
  );

  const expiredBlocked = computed(() =>
    users.value.filter((u) => u.role === "user" && u.status === "blocked")
  );

  async function fetchUsers() {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: true });
    if (err) error.value = err.message;
    else users.value = data as Profile[];
    loading.value = false;
  }

  async function createUser(email: string, password: string, role: "user" | "admin") {
    loading.value = true;
    error.value = null;
    const { data, error: err } = await supabase.functions.invoke("admin-create-user", {
      body: { email, password, role },
    });
    loading.value = false;
    if (err) {
      const ctxMsg = (data as { error?: string } | null)?.error;
      error.value = ctxMsg ?? err.message;
      return false;
    }
    await fetchUsers();
    return true;
  }

  async function updateRole(id: string, role: "user" | "admin") {
    error.value = null;
    const { error: err } = await supabase
      .from("profiles")
      .update({ role })
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchUsers();
    return true;
  }

  async function updateStatus(id: string, status: Profile["status"]) {
    error.value = null;
    const { error: err } = await supabase
      .from("profiles")
      .update({ status })
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchUsers();
    return true;
  }

  async function renewUser(id: string) {
    error.value = null;
    const target = users.value.find((u) => u.id === id);
    if (!target) return false;

    const now = Date.now();
    const current = target.expires_at ? new Date(target.expires_at).getTime() : now;
    const base = current > now ? current : now;
    const nextExpiry = new Date(base + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { error: err } = await supabase
      .from("profiles")
      .update({ expires_at: nextExpiry, status: "approved" })
      .eq("id", id);
    if (err) {
      error.value = err.message;
      return false;
    }
    await fetchUsers();
    return true;
  }

  return {
    users,
    loading,
    error,
    expiringSoon,
    expiredBlocked,
    fetchUsers,
    createUser,
    updateRole,
    updateStatus,
    renewUser,
  };
}
