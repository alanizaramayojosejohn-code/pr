<template>
  <section class="account">
    <h1 class="account__title">Mi cuenta</h1>

    <div class="account__info">
      <div class="account__row">
        <span>Email</span>
        <strong>{{ profile?.email }}</strong>
      </div>
      <div class="account__row">
        <span>Rol</span>
        <strong class="account__role">{{ profile?.role }}</strong>
      </div>
      <div class="account__row">
        <span>Estado</span>
        <strong>{{ profile?.status }}</strong>
      </div>
    </div>

    <form class="account__form" @submit.prevent="handleSubmit">
      <h2>Cambiar contraseña</h2>

      <label>
        <span>Nueva contraseña</span>
        <input v-model="newPassword" type="password" minlength="6" required :disabled="loading" />
      </label>

      <label>
        <span>Confirmar contraseña</span>
        <input v-model="confirmPassword" type="password" minlength="6" required :disabled="loading" />
      </label>

      <p v-if="localError || error" class="account__error">{{ localError || error }}</p>
      <p v-if="success" class="account__success">Contraseña actualizada.</p>

      <button type="submit" class="account__submit" :disabled="loading">
        {{ loading ? "Guardando…" : "Guardar" }}
      </button>
    </form>

    <button class="account__logout" @click="handleLogout">Cerrar sesión</button>
  </section>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { useRouter } from "vue-router";
import { useAuth } from "@/composables/useAuth";

const { profile, changePassword, logout, error, loading } = useAuth();
const router = useRouter();

const newPassword = ref("");
const confirmPassword = ref("");
const localError = ref<string | null>(null);
const success = ref(false);

async function handleSubmit() {
  localError.value = null;
  success.value = false;

  if (newPassword.value.length < 6) {
    localError.value = "La contraseña debe tener al menos 6 caracteres.";
    return;
  }
  if (newPassword.value !== confirmPassword.value) {
    localError.value = "Las contraseñas no coinciden.";
    return;
  }

  const ok = await changePassword(newPassword.value);
  if (ok) {
    success.value = true;
    newPassword.value = "";
    confirmPassword.value = "";
  }
}

async function handleLogout() {
  await logout();
  router.push({ name: "login" });
}
</script>

<style scoped>
.account {
  max-width: 520px;
  margin: 0 auto;
  padding: 4px 20px 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.account__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: var(--weight-bold);
  letter-spacing: -0.5px;
  color: var(--text-primary);
}
.account__info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 14px 16px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
}
.account__row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid var(--border-subtle);
}
.account__row:last-child {
  border-bottom: none;
}
.account__row span {
  color: var(--text-tertiary);
  font-size: 12px;
  font-weight: var(--weight-bold);
  letter-spacing: 0.5px;
  text-transform: uppercase;
}
.account__row strong {
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
  font-size: 14px;
}
.account__role {
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-size: 11px !important;
  padding: 3px 10px;
  border-radius: var(--radius-pill);
  background: var(--brand-glow);
  color: var(--brand-300) !important;
}
.account__form {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding: 18px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--surface-1);
}
.account__form h2 {
  margin: 0;
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: var(--weight-semibold);
  color: var(--text-primary);
}
.account__form label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  font-size: 12px;
  font-weight: var(--weight-semibold);
  color: var(--text-secondary);
}
.account__form input {
  padding: 10px 12px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-default);
  background: var(--surface-2);
  color: var(--text-primary);
  font-family: inherit;
  font-size: 14px;
}
.account__form input:focus {
  outline: none;
  border-color: var(--brand-500);
  box-shadow: 0 0 0 2px var(--brand-glow);
}
.account__submit {
  align-self: flex-start;
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
.account__submit:disabled {
  opacity: 0.5;
}
.account__error {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--danger-glow);
  color: var(--danger);
  font-size: 13px;
}
.account__success {
  margin: 0;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  background: var(--brand-glow);
  color: var(--brand-300);
  font-size: 13px;
}
.account__logout {
  align-self: center;
  margin-top: 8px;
  padding: 10px 20px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-pill);
  background: transparent;
  color: var(--text-tertiary);
  font-family: inherit;
  font-size: 13px;
  cursor: pointer;
}
.account__logout:hover {
  color: var(--danger);
  border-color: var(--danger);
}
</style>
