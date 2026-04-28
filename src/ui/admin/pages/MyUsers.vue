<template>
  <section class="users">
    <header class="users__head">
      <h1>Usuarios</h1>
      <button class="users__new" @click="showForm = !showForm">
        {{ showForm ? "Cancelar" : "+ Nuevo usuario" }}
      </button>
    </header>

    <div v-if="expiringSoon.length || expiredBlocked.length" class="users__alerts">
      <div v-if="expiredBlocked.length" class="users__alert users__alert--red">
        {{ expiredBlocked.length }} cuenta(s) bloqueadas por vencimiento.
      </div>
      <div v-if="expiringSoon.length" class="users__alert users__alert--amber">
        {{ expiringSoon.length }} cuenta(s) expiran en 7 días o menos.
      </div>
    </div>

    <form v-if="showForm" class="users__form" @submit.prevent="handleCreate">
      <label>
        <span>Email</span>
        <input v-model.trim="newEmail" type="email" required :disabled="loading" />
      </label>
      <label>
        <span>Contraseña</span>
        <input v-model="newPassword" type="text" minlength="6" required :disabled="loading" />
      </label>
      <label>
        <span>Rol</span>
        <select v-model="newRole" :disabled="loading">
          <option value="user">Usuario</option>
          <option value="admin">Administrador</option>
        </select>
      </label>
      <p v-if="formError" class="users__error">{{ formError }}</p>
      <button type="submit" class="users__submit" :disabled="loading">
        {{ loading ? "Creando…" : "Crear usuario" }}
      </button>
    </form>

    <div v-if="error" class="users__error">{{ error }}</div>

    <table class="users__table">
      <thead>
        <tr>
          <th>Email</th>
          <th>Rol</th>
          <th>Estado</th>
          <th>Expira</th>
          <th></th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="u in users" :key="u.id">
          <td>{{ u.email }}</td>
          <td>
            <select
              :value="u.role"
              :disabled="u.id === currentUserId"
              @change="onRoleChange(u, ($event.target as HTMLSelectElement).value as 'user' | 'admin')"
            >
              <option value="user">user</option>
              <option value="admin">admin</option>
            </select>
          </td>
          <td>
            <select
              :value="u.status"
              :disabled="u.id === currentUserId"
              @change="onStatusChange(u, ($event.target as HTMLSelectElement).value as 'approved' | 'blocked')"
            >
              <option value="approved">approved</option>
              <option value="blocked">blocked</option>
            </select>
          </td>
          <td>
            <span v-if="u.role === 'admin'" class="users__muted">∞</span>
            <span v-else :class="expiryClass(u)">
              {{ formatExpiry(u) }}
            </span>
          </td>
          <td>
            <button
              v-if="u.role === 'user'"
              class="users__renew"
              :disabled="loading"
              @click="handleRenew(u.id)"
            >
              Renovar mes
            </button>
          </td>
        </tr>
        <tr v-if="!loading && users.length === 0">
          <td colspan="5" class="users__empty">Sin usuarios.</td>
        </tr>
      </tbody>
    </table>
  </section>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { useUsers, daysUntil } from "@/composables/useUsers";
import { useAuth } from "@/composables/useAuth";
import type { Profile } from "@/composables/useAuth";

const {
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
} = useUsers();
const { user } = useAuth();
const currentUserId = user.value?.id;

const showForm = ref(false);
const newEmail = ref("");
const newPassword = ref("");
const newRole = ref<"user" | "admin">("user");
const formError = ref<string | null>(null);

onMounted(fetchUsers);

async function handleCreate() {
  formError.value = null;
  if (!/^\S+@\S+\.\S+$/.test(newEmail.value)) {
    formError.value = "Email inválido.";
    return;
  }
  if (newPassword.value.length < 6) {
    formError.value = "La contraseña debe tener al menos 6 caracteres.";
    return;
  }
  const ok = await createUser(newEmail.value, newPassword.value, newRole.value);
  if (ok) {
    newEmail.value = "";
    newPassword.value = "";
    newRole.value = "user";
    showForm.value = false;
  } else {
    formError.value = error.value;
  }
}

async function onRoleChange(u: Profile, role: "user" | "admin") {
  await updateRole(u.id, role);
}

async function onStatusChange(u: Profile, status: Profile["status"]) {
  await updateStatus(u.id, status);
}

async function handleRenew(id: string) {
  await renewUser(id);
}

function formatExpiry(u: Profile): string {
  const d = daysUntil(u.expires_at);
  if (d === null) return "—";
  if (d < 0) return `vencida hace ${-d} d`;
  if (d === 0) return "hoy";
  return `${d} d`;
}

function expiryClass(u: Profile): string {
  const d = daysUntil(u.expires_at);
  if (d === null) return "";
  if (d < 0) return "users__expiry users__expiry--red";
  if (d <= 7) return "users__expiry users__expiry--amber";
  return "users__expiry users__expiry--green";
}
</script>

<style scoped>
.users {
  max-width: 1000px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.users__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.users__head h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.users__new {
  padding: 8px 14px;
  border-radius: var(--radius-pill);
  border: none;
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 13px;
  cursor: pointer;
}
.users__alerts {
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.users__alert {
  padding: 10px 14px;
  border-radius: var(--radius-md);
  font-size: 13px;
}
.users__alert--red {
  background: var(--danger-glow);
  color: var(--danger);
  border: 1px solid #ef535066;
}
.users__alert--amber {
  background: var(--warning-glow);
  color: var(--warning);
  border: 1px solid #f59e0b66;
}
.users__form {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
  padding: 18px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
}
.users__form label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 11px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
  color: var(--text-tertiary);
}
.users__form input,
.users__form select {
  padding: 10px 12px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
  font-weight: var(--weight-regular);
  letter-spacing: normal;
  text-transform: none;
}
.users__form input:focus,
.users__form select:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.users__submit {
  grid-column: 1 / -1;
  justify-self: flex-start;
  padding: 10px 20px;
  border: none;
  border-radius: var(--radius-pill);
  background: var(--brand-500);
  color: var(--surface-0);
  font-family: inherit;
  font-weight: var(--weight-bold);
  font-size: 14px;
  cursor: pointer;
}
.users__submit:disabled {
  opacity: 0.5;
}
.users__error {
  grid-column: 1 / -1;
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.users__table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: var(--surface-1);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  overflow: hidden;
  font-size: 13px;
}
.users__table th,
.users__table td {
  padding: 10px 12px;
  text-align: left;
  border-bottom: 1px solid var(--border-subtle);
  vertical-align: middle;
}
.users__table th {
  background: var(--surface-2);
  color: var(--text-tertiary);
  font-size: 10px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.8px;
  text-transform: uppercase;
}
.users__table tr:last-child td {
  border-bottom: none;
}
.users__table td {
  color: var(--text-secondary);
}
.users__table select {
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  border: 1px solid var(--border-subtle);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 12px;
}
.users__expiry {
  display: inline-block;
  padding: 3px 10px;
  border-radius: var(--radius-pill);
  font-size: 11px;
  font-weight: var(--weight-bold);
}
.users__expiry--green {
  background: var(--brand-glow);
  color: var(--brand-300);
}
.users__expiry--amber {
  background: var(--warning-glow);
  color: var(--warning);
}
.users__expiry--red {
  background: var(--danger-glow);
  color: var(--danger);
}
.users__muted {
  color: var(--text-disabled);
}
.users__renew {
  padding: 6px 12px;
  border-radius: var(--radius-pill);
  border: 1px solid var(--border-subtle);
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  font-family: inherit;
  font-size: 11px;
  font-weight: var(--weight-semibold);
}
.users__renew:hover {
  color: var(--brand-300);
  border-color: var(--brand-500);
}
.users__empty {
  text-align: center;
  color: var(--text-tertiary);
  padding: 32px 16px !important;
}
</style>
